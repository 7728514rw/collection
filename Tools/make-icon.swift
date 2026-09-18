// Renders the app icon (1024x1024 PNG). Usage: swift make-icon.swift games|music out.png
import AppKit

let kind = CommandLine.arguments[1], out = CommandLine.arguments[2]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let plate = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 186, yRadius: 186)

if kind == "music" {
    // warm ground, a vinyl record with a label
    NSGradient(colors: [NSColor(calibratedRed: 0.93, green: 0.55, blue: 0.25, alpha: 1),
                        NSColor(calibratedRed: 0.62, green: 0.20, blue: 0.16, alpha: 1)])!.draw(in: plate, angle: -70)
    let c = NSPoint(x: 512, y: 512)
    let disc = NSBezierPath(ovalIn: NSRect(x: c.x - 330, y: c.y - 330, width: 660, height: 660))
    let shadow = NSShadow(); shadow.shadowBlurRadius = 30; shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
    NSGraphicsContext.saveGraphicsState(); shadow.set()
    NSColor(calibratedWhite: 0.10, alpha: 1).setFill(); disc.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor(calibratedWhite: 0.18, alpha: 1).setStroke()
    for r in stride(from: 150, through: 310, by: 16) {
        let p = NSBezierPath(ovalIn: NSRect(x: c.x - CGFloat(r), y: c.y - CGFloat(r), width: CGFloat(r * 2), height: CGFloat(r * 2)))
        p.lineWidth = 3; p.stroke()
    }
    NSColor(calibratedRed: 0.96, green: 0.85, blue: 0.45, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: c.x - 120, y: c.y - 120, width: 240, height: 240)).fill()
    NSColor(calibratedWhite: 0.10, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: c.x - 14, y: c.y - 14, width: 28, height: 28)).fill()
} else {
    // cool ground, a row of game cases on a shelf
    NSGradient(colors: [NSColor(calibratedRed: 0.20, green: 0.62, blue: 0.58, alpha: 1),
                        NSColor(calibratedRed: 0.07, green: 0.28, blue: 0.36, alpha: 1)])!.draw(in: plate, angle: -70)
    let shadow = NSShadow(); shadow.shadowBlurRadius = 24; shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
    let cases: [(CGFloat, CGFloat, NSColor)] = [           // width, height, colour
        (110, 470, NSColor(calibratedRed: 0.13, green: 0.35, blue: 0.80, alpha: 1)),
        (110, 500, NSColor(calibratedRed: 0.88, green: 0.24, blue: 0.22, alpha: 1)),
        (110, 440, NSColor(calibratedRed: 0.16, green: 0.62, blue: 0.34, alpha: 1)),
        (110, 500, NSColor(calibratedRed: 0.97, green: 0.75, blue: 0.16, alpha: 1)),
        (110, 460, NSColor(calibratedWhite: 0.92, alpha: 1)),
    ]
    var x: CGFloat = 512 - (110 * 5 + 18 * 4) / 2
    NSGraphicsContext.saveGraphicsState(); shadow.set()
    for (w, h, colour) in cases {
        colour.setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: 260, width: w, height: h), xRadius: 14, yRadius: 14).fill()
        x += w + 18
    }
    NSGraphicsContext.restoreGraphicsState()
    x = 512 - (110 * 5 + 18 * 4) / 2
    for (w, h, _) in cases {                                // spine label strip
        NSColor.black.withAlphaComponent(0.22).setFill()
        NSBezierPath(roundedRect: NSRect(x: x + 22, y: 300, width: w - 44, height: h - 80), xRadius: 8, yRadius: 8).fill()
        x += w + 18
    }
    NSColor(calibratedWhite: 0.95, alpha: 0.9).setFill()    // shelf
    NSBezierPath(roundedRect: NSRect(x: 190, y: 224, width: 644, height: 30), xRadius: 8, yRadius: 8).fill()
}
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
