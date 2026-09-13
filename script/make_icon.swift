import AppKit
let destination = CommandLine.arguments[1]
let base = NSImage(size: NSSize(width: 1024, height: 1024))
base.lockFocus()
let rect = NSRect(x: 96, y: 96, width: 832, height: 832)
let shape = NSBezierPath(roundedRect: rect, xRadius: 182, yRadius: 182)
NSGradient(colors: [NSColor(calibratedRed: 0.23, green: 0.26, blue: 0.34, alpha: 1), NSColor(calibratedRed: 0.055, green: 0.06, blue: 0.095, alpha: 1)])!.draw(in: shape, angle: 270)
NSColor.white.withAlphaComponent(0.18).setStroke(); shape.lineWidth = 2; shape.stroke()
let panel = NSBezierPath()
panel.move(to: NSPoint(x: 285, y: 300)); panel.line(to: NSPoint(x: 265, y: 720)); panel.curve(to: NSPoint(x: 304, y: 756), controlPoint1: NSPoint(x: 264, y: 745), controlPoint2: NSPoint(x: 278, y: 758)); panel.line(to: NSPoint(x: 761, y: 635)); panel.curve(to: NSPoint(x: 782, y: 606), controlPoint1: NSPoint(x: 776, y: 631), controlPoint2: NSPoint(x: 784, y: 620)); panel.line(to: NSPoint(x: 726, y: 307)); panel.close()
NSGradient(colors: [NSColor(calibratedRed: 0.23, green: 0.3, blue: 0.78, alpha: 1), NSColor(calibratedRed: 0.65, green: 0.63, blue: 1, alpha: 1), NSColor(calibratedRed: 1, green: 0.55, blue: 0.28, alpha: 1)])!.draw(in: panel, angle: 30)
NSColor.white.withAlphaComponent(0.65).setStroke(); panel.lineWidth = 4; panel.stroke()
let lower = NSBezierPath()
lower.move(to: NSPoint(x: 285, y: 300)); lower.line(to: NSPoint(x: 726, y: 307)); lower.line(to: NSPoint(x: 810, y: 245)); lower.curve(to: NSPoint(x: 790, y: 220), controlPoint1: NSPoint(x: 820, y: 228), controlPoint2: NSPoint(x: 805, y: 220)); lower.line(to: NSPoint(x: 210, y: 220)); lower.curve(to: NSPoint(x: 195, y: 247), controlPoint1: NSPoint(x: 192, y: 220), controlPoint2: NSPoint(x: 183, y: 236)); lower.close()
NSGradient(colors: [.white.withAlphaComponent(0.85), NSColor(calibratedWhite: 0.35, alpha: 1)])!.draw(in: lower, angle: 270)
let ribbon = NSBezierPath(); ribbon.move(to: NSPoint(x: 275, y: 505)); ribbon.curve(to: NSPoint(x: 754, y: 395), controlPoint1: NSPoint(x: 490, y: 275), controlPoint2: NSPoint(x: 430, y: 680)); ribbon.lineWidth = 35
NSGraphicsContext.saveGraphicsState(); panel.addClip(); NSColor.white.withAlphaComponent(0.22).setStroke(); ribbon.stroke(); NSGraphicsContext.restoreGraphicsState()
base.unlockFocus()
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for size in [16,32,128,256,512] {
 for factor in [1,2] {
  let pixels = size * factor
  let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  base.draw(in: NSRect(x: 0,y: 0,width: pixels,height: pixels)); NSGraphicsContext.restoreGraphicsState()
  let name = "icon_\(size)x\(size)" + (factor == 2 ? "@2x" : "") + ".png"
  try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination).appendingPathComponent(name))
 }
}
