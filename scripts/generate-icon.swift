import AppKit

// Source-drawn icon: two doorposts and a multiplication sign, matching the gate's actual job.
let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
    bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
NSColor(srgbRed: 0.18, green: 0.35, blue: 0.76, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
NSColor.white.withAlphaComponent(0.08).setStroke()
for position in stride(from: 64, to: 1024, by: 128) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: position, y: 0))
    path.line(to: NSPoint(x: position, y: 1024))
    path.move(to: NSPoint(x: 0, y: position))
    path.line(to: NSPoint(x: 1024, y: position))
    path.lineWidth = 2
    path.stroke()
}
NSColor.white.withAlphaComponent(0.95).setStroke()
for points: [NSPoint] in [
    [NSPoint(x: 298, y: 248), NSPoint(x: 224, y: 248), NSPoint(x: 224, y: 776), NSPoint(x: 298, y: 776)],
    [NSPoint(x: 726, y: 248), NSPoint(x: 800, y: 248), NSPoint(x: 800, y: 776), NSPoint(x: 726, y: 776)],
    [NSPoint(x: 414, y: 414), NSPoint(x: 610, y: 610)],
    [NSPoint(x: 414, y: 610), NSPoint(x: 610, y: 414)]
] {
    let path = NSBezierPath()
    path.move(to: points[0])
    points.dropFirst().forEach { path.line(to: $0) }
    path.lineWidth = 64
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}
NSGraphicsContext.restoreGraphicsState()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
let directory = URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("AppIcon.png"))
let manifest = """
{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
"""
try manifest.write(to: directory.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
try "{\"info\":{\"author\":\"xcode\",\"version\":1}}".write(to: directory.deletingLastPathComponent().appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("Generated App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
