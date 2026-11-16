// Renders the GitHub social preview (1280×640) for MacPulse.
// Usage: swiftc -O Tools/MakeSocialPreview.swift -o /tmp/make-social && /tmp/make-social <out.png>
import AppKit
import Foundation

let width: CGFloat = 1280
let height: CGFloat = 640
let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "social-preview.png"

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(width),
    pixelsHigh: Int(height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else { fatalError("Could not create bitmap") }
rep.size = NSSize(width: width, height: height)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

let teal = color(41, 189, 173)
let blue = color(77, 140, 245)
let ink = color(8, 15, 26)

// Background gradient.
NSGradient(colors: [ink, color(10, 27, 43), color(12, 38, 56)])?
    .draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -38)

// Soft glows.
color(41, 189, 173, 0.10).setFill()
NSBezierPath(ovalIn: NSRect(x: 880, y: 330, width: 520, height: 520)).fill()
color(77, 140, 245, 0.08).setFill()
NSBezierPath(ovalIn: NSRect(x: -160, y: -220, width: 520, height: 520)).fill()

// Dot grid.
color(255, 255, 255, 0.045).setFill()
var gx: CGFloat = 48
while gx < width {
    var gy: CGFloat = 48
    while gy < height {
        NSBezierPath(ovalIn: NSRect(x: gx, y: gy, width: 2.4, height: 2.4)).fill()
        gy += 48
    }
    gx += 48
}

func draw(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight,
          tint: NSColor, tracking: CGFloat = 0) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: tint,
        .kern: tracking
    ]
    NSAttributedString(string: text, attributes: attrs).draw(at: NSPoint(x: x, y: y))
}

// Wordmark with accent dot.
draw("Mac", x: 88, y: 470, size: 86, weight: .bold, tint: .white, tracking: -2)
draw("Pulse", x: 278, y: 470, size: 86, weight: .bold, tint: teal, tracking: -2)
color(41, 189, 173, 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 590, y: 548, width: 14, height: 14)).fill()

draw("Your Mac, healthy.", x: 90, y: 408, size: 40, weight: .medium,
     tint: color(226, 236, 248), tracking: -0.5)
draw("A native, private health dashboard with one-click fixes.",
     x: 90, y: 360, size: 25, weight: .regular, tint: color(150, 176, 200))

// Badge pills.
func drawPill(_ text: String, x: CGFloat, y: CGFloat) -> CGFloat {
    let font = NSFont.systemFont(ofSize: 20, weight: .semibold)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color(196, 214, 232)]
    let size = NSAttributedString(string: text, attributes: attrs).size()
    let pad: CGFloat = 18
    let rect = NSRect(x: x, y: y, width: size.width + pad * 2, height: 42)
    let path = NSBezierPath(roundedRect: rect, xRadius: 21, yRadius: 21)
    color(255, 255, 255, 0.07).setFill()
    path.fill()
    color(255, 255, 255, 0.13).setStroke()
    path.lineWidth = 1
    path.stroke()
    NSAttributedString(string: text, attributes: attrs)
        .draw(at: NSPoint(x: x + pad, y: y + 11))
    return rect.maxX + 14
}

var pillX: CGFloat = 90
pillX = drawPill("macOS 13+", x: pillX, y: 268)
pillX = drawPill("Apple Silicon + Intel", x: pillX, y: 268)
pillX = drawPill("No telemetry", x: pillX, y: 268)
_ = drawPill("MIT", x: pillX, y: 268)

// Heartbeat line with a soft glow.
func pulsePath() -> NSBezierPath {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: 90, y: 150))
    p.line(to: NSPoint(x: 360, y: 150))
    p.line(to: NSPoint(x: 392, y: 150))
    p.line(to: NSPoint(x: 408, y: 176))
    p.line(to: NSPoint(x: 424, y: 150))
    p.line(to: NSPoint(x: 560, y: 150))
    p.line(to: NSPoint(x: 592, y: 150))
    p.line(to: NSPoint(x: 616, y: 226))
    p.line(to: NSPoint(x: 646, y: 58))
    p.line(to: NSPoint(x: 674, y: 196))
    p.line(to: NSPoint(x: 694, y: 150))
    p.line(to: NSPoint(x: 820, y: 150))
    p.line(to: NSPoint(x: 1190, y: 150))
    return p
}

let glow = pulsePath()
glow.lineWidth = 18
glow.lineCapStyle = .round
glow.lineJoinStyle = .round
color(41, 189, 173, 0.16).setStroke()
glow.stroke()

let line = pulsePath()
line.lineWidth = 6
line.lineCapStyle = .round
line.lineJoinStyle = .round
teal.setStroke()
line.stroke()

// Score ring.
let center = NSPoint(x: 1056, y: 372)
let radius: CGFloat = 132
let ringRect = NSRect(x: center.x - radius, y: center.y - radius,
                      width: radius * 2, height: radius * 2)
let track = NSBezierPath(ovalIn: ringRect)
track.lineWidth = 22
color(255, 255, 255, 0.08).setStroke()
track.stroke()

let progress = NSBezierPath()
progress.appendArc(withCenter: center, radius: radius,
                   startAngle: 90, endAngle: -238, clockwise: true)
progress.lineWidth = 22
progress.lineCapStyle = .round
teal.setStroke()
progress.stroke()

let scoreAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 82, weight: .bold),
    .foregroundColor: NSColor.white
]
let scoreSize = NSAttributedString(string: "92", attributes: scoreAttrs).size()
NSAttributedString(string: "92", attributes: scoreAttrs).draw(
    at: NSPoint(x: center.x - scoreSize.width / 2, y: center.y - 24)
)
draw("SCORE", x: center.x - 31, y: center.y - 66, size: 15, weight: .bold,
     tint: color(150, 176, 200), tracking: 3)

// Footer.
draw("github.com/ShishirShekhar/macpulse", x: 90, y: 52, size: 20,
     weight: .medium, tint: color(120, 148, 174))

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}
try data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath) — \(Int(width))×\(Int(height)), \(data.count) bytes")
