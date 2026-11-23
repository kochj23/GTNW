//
//  EnginePlatform.swift
//  Global Thermal Nuclear War
//
//  The two platform services the engine needs from its host, shared by the app and the GTNWCore package
//  (Documentation/WASM-PORT.md):
//  - `GameResources`: the bundled data files (nation cabinets and characters, map outlines, war base rates). The app
//    reads them from the main bundle as before; a GTNWCore host (the WebAssembly bridge, the golden CLI) hands them in.
//  - `GameScheduler`: work the engine defers ("retaliation in a second", "end the turn after a beat"). The app runs it
//    on the main queue as before; GTNWCore has no Dispatch (WebAssembly), so the work waits in `CoreRunLoop` until the
//    host drains it — in order, at once, which keeps a game reproducible.
//

import Foundation

enum GameResources {
    /// Where the data comes from when set (GTNWCore hosts, tests); nil = the main bundle.
    nonisolated(unsafe) static var provider: ((_ name: String, _ ext: String) -> Data?)?

    /// The bundled file `name.ext`, or nil when it is missing.
    static func data(_ name: String, _ ext: String = "json") -> Data? {
        if let provider { return provider(name, ext) }
        #if GTNW_CORE
        return nil   // no app bundle: the host hands the files in (provider)
        #else
        return Bundle.main.url(forResource: name, withExtension: ext).flatMap { try? Data(contentsOf: $0) }
        #endif
    }
}

enum GameScheduler {
    /// Run `work` on the main thread after `seconds` (0 = the next turn of the run loop).
    static func after(_ seconds: Double, execute work: @escaping () -> Void) {
        #if GTNW_CORE
        CoreRunLoop.schedule(after: seconds, work)
        #else
        if seconds > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
        } else {
            DispatchQueue.main.async(execute: work)
        }
        #endif
    }
}
