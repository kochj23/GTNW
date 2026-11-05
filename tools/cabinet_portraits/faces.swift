import Vision
import AppKit
import Foundation
import CoreImage
// usage: faces <img>... -> "path\tx\ty\tw\th" (largest face, normalized, top-left origin) or "path\tNONE";
// also writes <img>.mask.png (person/foreground mask, white = subject) when Vision can segment it.
let ctx = CIContext()
for p in CommandLine.arguments.dropFirst() {
    guard let img = NSImage(contentsOfFile: p), let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print("\(p)\tNONE"); continue }
    let handler = VNImageRequestHandler(cgImage: cg)
    let face = VNDetectFaceRectanglesRequest()
    let seg = VNGenerateForegroundInstanceMaskRequest()
    try? handler.perform([face, seg])
    if let obs = seg.results?.first,
       let buf = try? obs.generateScaledMaskForImage(forInstances: obs.allInstances, from: handler) {
        let ci = CIImage(cvPixelBuffer: buf)
        if let out = ctx.createCGImage(ci, from: ci.extent) {
            let rep = NSBitmapImageRep(cgImage: out)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: p + ".mask.png"))
        }
    }
    if let f = (face.results ?? []).max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) {
        let b = f.boundingBox; print("\(p)\t\(b.minX)\t\(1 - b.maxY)\t\(b.width)\t\(b.height)")
    } else { print("\(p)\tNONE") }
}
