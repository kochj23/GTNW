//
//  main.swift
//  GTNWWasm
//
//  The WebAssembly reactor: GTNWCore's JSON bridge behind a small C ABI, for a browser or Node (Wasm/js/gtnw.mjs).
//  Built with `-mexec-model=reactor` (Wasm/build.sh): the host calls `_initialize` once, then these exports.
//
//    gtnw_alloc(n) -> ptr          a buffer for one request (the host writes UTF-8 or raw bytes into it)
//    gtnw_free(ptr)                give it back
//    gtnw_call(op, ptr, n) -> len  run one bridge call; the reply (UTF-8 JSON) is at gtnw_reply_ptr(), len bytes
//    gtnw_reply_ptr() -> ptr
//
//  ops: 1 newGame(json)  2 act(json)  3 endTurn  4 snapshot  5 save  6 load(json)
//       7 setResource("<name>\n" + bytes)  8 golden({"year":..,"seed":"hex","turns":..})  9 goldenVectors
//
//  Built natively (swift build) this is an empty program; the exports exist only for WASI.
//

#if os(WASI)
import Foundation
import GTNWCore

nonisolated(unsafe) var reply: [UInt8] = []

@_expose(wasm, "gtnw_alloc")
@_cdecl("gtnw_alloc")
func gtnwAlloc(_ count: Int32) -> UnsafeMutableRawPointer {
    UnsafeMutableRawPointer.allocate(byteCount: max(1, Int(count)), alignment: 16)
}

@_expose(wasm, "gtnw_free")
@_cdecl("gtnw_free")
func gtnwFree(_ pointer: UnsafeMutableRawPointer) {
    pointer.deallocate()
}

@_expose(wasm, "gtnw_reply_ptr")
@_cdecl("gtnw_reply_ptr")
func gtnwReplyPointer() -> UnsafeRawPointer {
    reply.withUnsafeBytes { UnsafeRawPointer($0.baseAddress!) }
}

struct GoldenRequest: Decodable {
    var year: Int
    var seed: String
    var turns: Int
}

@_expose(wasm, "gtnw_call")
@_cdecl("gtnw_call")
func gtnwCall(_ op: Int32, _ pointer: UnsafeRawPointer?, _ count: Int32) -> Int32 {
    let bytes = pointer.map { Data(bytes: $0, count: Int(max(0, count))) } ?? Data()
    let text = String(decoding: bytes, as: UTF8.self)
    let out: String
    switch op {
    case 1: out = GTNWBridge.newGame(text)
    case 2: out = GTNWBridge.act(text)
    case 3: out = GTNWBridge.endTurn()
    case 4: out = GTNWBridge.snapshot()
    case 5: out = GTNWBridge.save()
    case 6: out = GTNWBridge.load(text)
    case 7:
        guard let newline = bytes.firstIndex(of: 0x0A) else { out = #"{"ok":false,"error":"setResource: <name>\\n<bytes>"}"#; break }
        GTNWBridge.setResource(String(decoding: bytes[..<newline], as: UTF8.self), Data(bytes[(newline + 1)...]))
        out = #"{"ok":true,"events":[]}"#
    case 8:
        if let r = try? JSONDecoder().decode(GoldenRequest.self, from: bytes), let seed = UInt64(r.seed, radix: 16),
           (0...600).contains(r.turns) {
            out = GTNWBridge.golden(year: r.year, seed: seed, turns: r.turns)
        } else {
            out = #"{"ok":false,"error":"golden: {\"year\":Int,\"seed\":\"hex\",\"turns\":Int}"}"#
        }
    case 9: out = GTNWBridge.goldenVectors()
    default: out = #"{"ok":false,"error":"unknown op"}"#
    }
    reply = Array(out.utf8) + [0]
    return Int32(reply.count - 1)
}
#endif
