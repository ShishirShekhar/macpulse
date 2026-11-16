import AppKit
import Foundation

// Renders a 1024x1024 app icon: teal→blue squircle with a pulse line.

let size = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Could not create bitmap")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Background canvas is transparent; draw the squircle inset like macOS icons.
let content = NSRect(x: 92, y: 92, width: 840, height: 840)
let radius: CGFloat = 188
let squircle = NSBezierPath(roundedRect: content, xRadius: radius, yRadius: radius)

// Soft drop shadow under the icon body.
ctx.saveGState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
shadow.shadowBlurRadius = 28
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.set()
NSColor.black.setFill()
squircle.fill()
ctx.restoreGState()

// Gradient body.
ctx.saveGState()
squircle.addClip()
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.20, green: 0.84, blue: 0.74, alpha: 1),
    NSColor(srgbRed: 0.22, green: 0.60, blue: 0.95, alpha: 1),
    NSColor(srgbRed: 0.20, green: 0.38, blue: 0.90, alpha: 1)
])!
gradient.draw(in: content, angle: -55)

// Glow in the upper-left.
let glow = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.40),
    NSColor.white.withAlphaComponent(0.0)
])!
glow.draw(in: NSBezierPath(ovalIn: NSRect(x: 40, y: 470, width: 640, height: 640)), relativeCenterPosition: NSPoint(x: -0.2, y: 0.25))

// Inner stroke.
let stroke = NSBezierPath(
    roundedRect: content.insetBy(dx: 7, dy: 7),
    xRadius: radius - 6,
    yRadius: radius - 6
)
stroke.lineWidth = 4
NSColor.white.withAlphaComponent(0.22).setStroke()
stroke.stroke()
ctx.restoreGState()

// Pulse line.
let pulse = NSBezierPath()
pulse.lineWidth = 56
pulse.lineCapStyle = .round
pulse.lineJoinStyle = .round
pulse.move(to: NSPoint(x: 236, y: 512))
pulse.line(to: NSPoint(x: 372, y: 512))
pulse.line(to: NSPoint(x: 430, y: 660))
pulse.line(to: NSPoint(x: 496, y: 336))
pulse.line(to: NSPoint(x: 552, y: 596))
pulse.line(to: NSPoint(x: 600, y: 512))
pulse.line(to: NSPoint(x: 662, y: 512))
pulse.line(to: NSPoint(x: 700, y: 566))
pulse.line(to: NSPoint(x: 738, y: 512))
pulse.line(to: NSPoint(x: 788, y: 512))

ctx.saveGState()
let pulseShadow = NSShadow()
pulseShadow.shadowColor = NSColor(srgbRed: 0.02, green: 0.15, blue: 0.35, alpha: 0.35)
pulseShadow.shadowBlurRadius = 16
pulseShadow.shadowOffset = NSSize(width: 0, height: -6)
pulseShadow.set()
NSColor.white.withAlphaComponent(0.97).setStroke()
pulse.stroke()
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}
try png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
