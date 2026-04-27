import AppKit
import CoreGraphics
import Foundation

struct IconSpec {
    let idiom: String
    let size: String
    let scale: String
    let pixels: Int
    let filename: String
}

let specs: [IconSpec] = [
    .init(idiom: "mac", size: "16x16", scale: "1x", pixels: 16, filename: "icon_16x16.png"),
    .init(idiom: "mac", size: "16x16", scale: "2x", pixels: 32, filename: "icon_16x16@2x.png"),
    .init(idiom: "mac", size: "32x32", scale: "1x", pixels: 32, filename: "icon_32x32.png"),
    .init(idiom: "mac", size: "32x32", scale: "2x", pixels: 64, filename: "icon_32x32@2x.png"),
    .init(idiom: "mac", size: "128x128", scale: "1x", pixels: 128, filename: "icon_128x128.png"),
    .init(idiom: "mac", size: "128x128", scale: "2x", pixels: 256, filename: "icon_128x128@2x.png"),
    .init(idiom: "mac", size: "256x256", scale: "1x", pixels: 256, filename: "icon_256x256.png"),
    .init(idiom: "mac", size: "256x256", scale: "2x", pixels: 512, filename: "icon_256x256@2x.png"),
    .init(idiom: "mac", size: "512x512", scale: "1x", pixels: 512, filename: "icon_512x512.png"),
    .init(idiom: "mac", size: "512x512", scale: "2x", pixels: 1024, filename: "icon_512x512@2x.png"),
]

let fileManager = FileManager.default
let projectRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let appIconSetURL = projectRoot
    .appendingPathComponent("MemoryToastToolApp")
    .appendingPathComponent("Assets.xcassets")
    .appendingPathComponent("AppIcon.appiconset")

try fileManager.createDirectory(at: appIconSetURL, withIntermediateDirectories: true)

for spec in specs {
    let image = drawIcon(size: spec.pixels)
    let imageRep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    imageRep.size = NSSize(width: spec.pixels, height: spec.pixels)
    guard let pngData = imageRep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "generate_app_icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG for \(spec.filename)"])
    }
    try pngData.write(to: appIconSetURL.appendingPathComponent(spec.filename))
}

let contents = [
    "images": specs.map { spec in
        [
            "idiom": spec.idiom,
            "size": spec.size,
            "scale": spec.scale,
            "filename": spec.filename
        ]
    },
    "info": [
        "version": 1,
        "author": "xcode"
    ]
] as [String: Any]

let contentsData = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try contentsData.write(to: appIconSetURL.appendingPathComponent("Contents.json"))

func drawIcon(size: Int) -> NSImage {
    let canvasSize = NSSize(width: size, height: size)
    let image = NSImage(size: canvasSize)

    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
    let scale = CGFloat(size) / 1024.0

    let outerRadius = 230.0 * scale
    let outerRect = rect.insetBy(dx: 36.0 * scale, dy: 36.0 * scale)
    let outerPath = CGPath(roundedRect: outerRect, cornerWidth: outerRadius, cornerHeight: outerRadius, transform: nil)

    context.addPath(outerPath)
    context.saveGState()
    context.clip()

    let backgroundColors = [
        NSColor(calibratedRed: 0.03, green: 0.07, blue: 0.13, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.12, green: 0.25, blue: 0.69, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.49, green: 0.83, blue: 0.99, alpha: 1.0).cgColor
    ] as CFArray
    let backgroundLocations: [CGFloat] = [0.0, 0.58, 1.0]
    let background = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: backgroundColors, locations: backgroundLocations)!
    context.drawLinearGradient(
        background,
        start: CGPoint(x: 120.0 * scale, y: 924.0 * scale),
        end: CGPoint(x: 904.0 * scale, y: 84.0 * scale),
        options: []
    )

    let glowColor = NSColor(calibratedRed: 0.93, green: 0.27, blue: 0.27, alpha: 0.24).cgColor
    let glowColors = [glowColor, NSColor.clear.cgColor] as CFArray
    let glowGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0.0, 1.0])!
    context.drawRadialGradient(
        glowGradient,
        startCenter: CGPoint(x: 720.0 * scale, y: 340.0 * scale),
        startRadius: 0,
        endCenter: CGPoint(x: 720.0 * scale, y: 340.0 * scale),
        endRadius: 360.0 * scale,
        options: []
    )

    context.restoreGState()

    context.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: 0.16).cgColor)
    context.setLineWidth(8.0 * scale)
    let innerFrame = outerRect.insetBy(dx: 28.0 * scale, dy: 28.0 * scale)
    let innerFramePath = CGPath(roundedRect: innerFrame, cornerWidth: 190.0 * scale, cornerHeight: 190.0 * scale, transform: nil)
    context.addPath(innerFramePath)
    context.strokePath()

    let chipRect = CGRect(
        x: 322.0 * scale,
        y: 322.0 * scale,
        width: 380.0 * scale,
        height: 380.0 * scale
    )
    let chipPath = CGPath(roundedRect: chipRect, cornerWidth: 92.0 * scale, cornerHeight: 92.0 * scale, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -18.0 * scale), blur: 40.0 * scale, color: NSColor(calibratedWhite: 0.0, alpha: 0.24).cgColor)
    context.addPath(chipPath)
    context.setFillColor(NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(chipPath)
    context.clip()
    let chipGloss = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(calibratedWhite: 1.0, alpha: 0.18).cgColor,
            NSColor(calibratedWhite: 1.0, alpha: 0.04).cgColor
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    context.drawLinearGradient(
        chipGloss,
        start: CGPoint(x: chipRect.minX, y: chipRect.maxY),
        end: CGPoint(x: chipRect.maxX, y: chipRect.minY),
        options: []
    )
    context.restoreGState()

    let coreRect = chipRect.insetBy(dx: 92.0 * scale, dy: 92.0 * scale)
    let corePath = CGPath(roundedRect: coreRect, cornerWidth: 40.0 * scale, cornerHeight: 40.0 * scale, transform: nil)
    context.setStrokeColor(NSColor(calibratedWhite: 0.98, alpha: 0.98).cgColor)
    context.setLineWidth(28.0 * scale)
    context.addPath(corePath)
    context.strokePath()

    let alertBarRect = CGRect(
        x: coreRect.minX + 10.0 * scale,
        y: coreRect.minY + 26.0 * scale,
        width: coreRect.width - 20.0 * scale,
        height: 76.0 * scale
    )
    let alertBarPath = CGPath(roundedRect: alertBarRect, cornerWidth: 38.0 * scale, cornerHeight: 38.0 * scale, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -6.0 * scale), blur: 20.0 * scale, color: NSColor(calibratedRed: 0.50, green: 0.10, blue: 0.10, alpha: 0.25).cgColor)
    context.addPath(alertBarPath)
    context.clip()
    let alertGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(calibratedRed: 0.99, green: 0.42, blue: 0.28, alpha: 1.0).cgColor,
            NSColor(calibratedRed: 0.92, green: 0.20, blue: 0.24, alpha: 1.0).cgColor
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    context.drawLinearGradient(
        alertGradient,
        start: CGPoint(x: alertBarRect.midX, y: alertBarRect.maxY),
        end: CGPoint(x: alertBarRect.midX, y: alertBarRect.minY),
        options: []
    )
    context.restoreGState()

    let stemRect = CGRect(
        x: rect.midX - (54.0 * scale),
        y: chipRect.minY + 104.0 * scale,
        width: 108.0 * scale,
        height: 178.0 * scale
    )
    let stemPath = CGPath(roundedRect: stemRect, cornerWidth: 28.0 * scale, cornerHeight: 28.0 * scale, transform: nil)
    context.setFillColor(NSColor(calibratedWhite: 0.98, alpha: 0.98).cgColor)
    context.addPath(stemPath)
    context.fillPath()

    context.setFillColor(NSColor(calibratedWhite: 0.94, alpha: 0.9).cgColor)
    let pins: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (264, 410, 26, 70), (264, 544, 26, 70),
        (734, 410, 26, 70), (734, 544, 26, 70),
        (410, 734, 70, 26), (544, 734, 70, 26)
    ]
    for pin in pins {
        let pinRect = CGRect(
            x: pin.0 * scale,
            y: pin.1 * scale,
            width: pin.2 * scale,
            height: pin.3 * scale
        )
        let pinPath = CGPath(roundedRect: pinRect, cornerWidth: 13.0 * scale, cornerHeight: 13.0 * scale, transform: nil)
        context.addPath(pinPath)
        context.fillPath()
    }

    image.unlockFocus()
    return image
}
