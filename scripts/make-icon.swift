import AppKit
import Foundation

// Package the approved raster assets without redrawing the selected logo.
func loadTrimmed(_ path: String) throws -> CGImage {
    guard let image = NSImage(contentsOfFile: path),
          let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw NSError(domain: "BrandAssets", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing image: \(path)"])
    }
    let width = cg.width, height = cg.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    var minX = width, minY = height, maxX = -1, maxY = -1
    bytes.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    for y in 0..<height {
        for x in 0..<width where bytes[(y * width + x) * 4 + 3] > 32 {
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    guard maxX >= minX, maxY >= minY,
          let trimmed = cg.cropping(to: CGRect(x: minX, y: minY, width: maxX-minX+1, height: maxY-minY+1)) else {
        throw NSError(domain: "BrandAssets", code: 2, userInfo: [NSLocalizedDescriptionKey: "Empty image: \(path)"])
    }
    print("\(path): \(width)×\(height), artwork \(trimmed.width)×\(trimmed.height)")
    return trimmed
}

func render(_ image: CGImage, width: Int, height: Int, inset: CGFloat = 0) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let graphics = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.interpolationQuality = .high
    let available = CGRect(x: inset, y: inset, width: CGFloat(width)-2*inset, height: CGFloat(height)-2*inset)
    let scale = min(available.width/CGFloat(image.width), available.height/CGFloat(image.height))
    let size = CGSize(width: CGFloat(image.width)*scale, height: CGFloat(image.height)*scale)
    context.draw(image, in: CGRect(x: (CGFloat(width)-size.width)/2, y: (CGFloat(height)-size.height)/2, width: size.width, height: size.height))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ rep: NSBitmapImageRep, to path: String) throws {
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let icon = try loadTrimmed("Resources/Brand/AppIcon-Source.png")
let mark = try loadTrimmed("Resources/Brand/LogoMark-Source.png")
let output = URL(fileURLWithPath: "Resources/HazeFocus.iconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = render(icon, width: pixels, height: pixels, inset: CGFloat(pixels)*0.055)
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try save(rep, to: output.appendingPathComponent(name).path)
    }
}
try save(render(icon, width: 1024, height: 1024, inset: 56), to: "Resources/Brand/AppIcon.png")
let markWidth = 512
let markHeight = Int((CGFloat(markWidth)*CGFloat(mark.height)/CGFloat(mark.width)).rounded())
try save(render(mark, width: markWidth, height: markHeight), to: "Resources/Brand/LogoMark.png")
try save(render(mark, width: 18, height: 14), to: "Resources/Brand/MenuBarTemplate.png")
try save(render(mark, width: 36, height: 28), to: "Resources/Brand/MenuBarTemplate@2x.png")
let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", output.path, "-o", "Resources/AppIcon.icns"]
try process.run(); process.waitUntilExit()
if process.terminationStatus != 0 { exit(1) }
try FileManager.default.removeItem(at: output)
