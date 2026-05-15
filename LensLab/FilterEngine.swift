import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

// MARK: - Photo Filter Model
struct PhotoFilter: Identifiable, Equatable {
    let id: Int
    let name: String
    let apply: (CIImage) -> CIImage

    static func == (lhs: PhotoFilter, rhs: PhotoFilter) -> Bool { lhs.id == rhs.id }
}

// MARK: - Adjustment Slider Model
struct AdjustmentSlider: Identifiable {
    let id: String
    let label: String
    let min: Float
    let max: Float
    var value: Float
}

// MARK: - Adjustment Section
struct AdjustmentSection: Identifiable {
    let id: String
    let title: String
    var sliders: [AdjustmentSlider]
}

// MARK: - Filter Engine
enum FilterEngine {
    static let context = CIContext()

    // Predefined filters
    static let filters: [PhotoFilter] = [
        PhotoFilter(id: 0, name: "Original") { img in img },

        PhotoFilter(id: 1, name: "Kodak 400") { img in
            let warm = applyTemperature(img, temp: 6800)
            let faded = applyExposure(warm, ev: 0.15)
            return applyVibrance(faded, amount: -0.2)
        },

        PhotoFilter(id: 2, name: "Fuji Velvia") { img in
            let vivid = applySaturation(img, amount: 1.6)
            return applyContrast(vivid, amount: 1.3)
        },

        PhotoFilter(id: 3, name: "Ilford HP5") { img in
            applyMonochrome(img, color: CIColor(red: 0.5, green: 0.45, blue: 0.4), intensity: 1.0)
        },

        PhotoFilter(id: 4, name: "Faded Milk") { img in
            let cool = applyTemperature(img, temp: 5200)
            let faded = applyExposure(cool, ev: 0.3)
            return applySaturation(faded, amount: 0.7)
        },

        PhotoFilter(id: 5, name: "Golden Hour") { img in
            let warm = applyTemperature(img, temp: 7500)
            return applyVibrance(warm, amount: 0.4)
        },

        PhotoFilter(id: 6, name: "Noir") { img in
            let bw = applyMonochrome(img, color: CIColor(red: 0.3, green: 0.3, blue: 0.3), intensity: 1.0)
            return applyContrast(bw, amount: 1.5)
        },

        PhotoFilter(id: 7, name: "Mist") { img in
            let cool = applyTemperature(img, temp: 5000)
            let bright = applyExposure(cool, ev: 0.25)
            return applySaturation(bright, amount: 0.6)
        },
    ]

    // MARK: - Core Image Helpers
    static func applyTemperature(_ img: CIImage, temp: Float) -> CIImage {
        let f = CIFilter.temperatureAndTint()
        f.inputImage = img
        f.neutral = CIVector(x: CGFloat(temp), y: 0)
        f.targetNeutral = CIVector(x: 6500, y: 0)
        return f.outputImage ?? img
    }

    static func applyExposure(_ img: CIImage, ev: Float) -> CIImage {
        let f = CIFilter.exposureAdjust()
        f.inputImage = img
        f.ev = ev
        return f.outputImage ?? img
    }

    static func applyContrast(_ img: CIImage, amount: Float) -> CIImage {
        let f = CIFilter.colorControls()
        f.inputImage = img
        f.contrast = amount
        f.saturation = 1.0
        f.brightness = 0
        return f.outputImage ?? img
    }

    static func applySaturation(_ img: CIImage, amount: Float) -> CIImage {
        let f = CIFilter.colorControls()
        f.inputImage = img
        f.saturation = amount
        f.contrast = 1.0
        f.brightness = 0
        return f.outputImage ?? img
    }

    static func applyVibrance(_ img: CIImage, amount: Float) -> CIImage {
        let f = CIFilter.vibrance()
        f.inputImage = img
        f.amount = amount
        return f.outputImage ?? img
    }

    static func applyMonochrome(_ img: CIImage, color: CIColor, intensity: Float) -> CIImage {
        let f = CIFilter.photoEffectMono()
        f.inputImage = img
        return f.outputImage ?? img
    }

    // MARK: - Apply adjustments from sliders
    static func applyAdjustments(_ img: CIImage, sections: [AdjustmentSection]) -> CIImage {
        var result = img
        var vals: [String: Float] = [:]
        for s in sections { for sl in s.sliders { vals[sl.id] = sl.value } }

        // Exposure
        if let ev = vals["exposure"] {
            let f = CIFilter.exposureAdjust()
            f.inputImage = result; f.ev = ev / 50
            result = f.outputImage ?? result
        }
        // Color controls
        let contrast  = 1.0 + (vals["contrast"]  ?? 0) / 100
        let sat       = 1.0 + (vals["saturation"] ?? 0) / 100
        let bright    = (vals["brightness"] ?? 0) / 200
        let f2 = CIFilter.colorControls()
        f2.inputImage = result
        f2.contrast = contrast; f2.saturation = sat; f2.brightness = bright
        result = f2.outputImage ?? result

        // Temperature
        if let temp = vals["temp"] {
            let base: Float = 6500
            let target = base + temp * 20
            result = applyTemperature(result, temp: target)
        }
        // Vibrance
        if let vib = vals["vibrance"] {
            result = applyVibrance(result, amount: vib / 100)
        }
        // Sharpness
        if let sharp = vals["sharpness"], sharp > 0 {
            let f = CIFilter.sharpenLuminance()
            f.inputImage = result; f.sharpness = sharp / 100
            result = f.outputImage ?? result
        }
        // Vignette
        if let vig = vals["vignette"] {
            let f = CIFilter.vignette()
            f.inputImage = result
            f.intensity = vig / 50
            f.radius = 1.5
            result = f.outputImage ?? result
        }
        // Noise reduction
        if let noise = vals["noise"], noise > 0 {
            let f = CIFilter.noiseReduction()
            f.inputImage = result
            f.noiseLevel = noise / 500
            f.sharpness = 0.4
            result = f.outputImage ?? result
        }

        return result
    }

    // MARK: - Render UIImage
    static func render(_ ciImage: CIImage, size: CGSize) -> UIImage? {
        let scale = min(size.width / ciImage.extent.width,
                        size.height / ciImage.extent.height)
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImg)
    }

    // MARK: - Generate synthetic placeholder images
    static func generatePlaceholder(seed: Int, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let palettes: [[UIColor]] = [
                [.init(hex:"#1a0e2e"), .init(hex:"#3d1f5e"), .init(hex:"#c97d4e"), .init(hex:"#f2c98a")],
                [.init(hex:"#0d1b2a"), .init(hex:"#1b4332"), .init(hex:"#40916c"), .init(hex:"#b7e4c7")],
                [.init(hex:"#2d1b00"), .init(hex:"#6b3a00"), .init(hex:"#c78900"), .init(hex:"#f5c842")],
                [.init(hex:"#0a0a14"), .init(hex:"#1a1a3e"), .init(hex:"#2e4a8a"), .init(hex:"#89b4e8")],
                [.init(hex:"#1a0a0a"), .init(hex:"#5c1a1a"), .init(hex:"#a63d3d"), .init(hex:"#e8a0a0")],
                [.init(hex:"#0d0d14"), .init(hex:"#1e3a2f"), .init(hex:"#2d6b50"), .init(hex:"#7ec8a0")],
            ]
            let pal = palettes[seed % palettes.count]
            // gradient bg
            let colors = [pal[0].cgColor, pal[1].cgColor, pal[2].cgColor] as CFArray
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors, locations: [0, 0.5, 1])!
            c.drawLinearGradient(grad,
                                 start: .zero,
                                 end: CGPoint(x: size.width * 0.4, y: size.height),
                                 options: [])
            // horizon glow
            let horizonY = size.height * 0.55
            let hColors = [pal[3].withAlphaComponent(0.35).cgColor,
                           UIColor.clear.cgColor] as CFArray
            let hGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: hColors, locations: [0, 1])!
            c.drawLinearGradient(hGrad,
                                 start: CGPoint(x: 0, y: horizonY - 30),
                                 end: CGPoint(x: 0, y: horizonY + 50), options: [])
            // bokeh circles
            for i in 0..<8 {
                let x = CGFloat((seed * 37 + i * 73) % Int(size.width))
                let y = CGFloat((seed * 53 + i * 97) % Int(size.height))
                let r = CGFloat(20 + (seed + i * 11) % 60)
                let bColors = [pal[3].withAlphaComponent(0.22).cgColor,
                               UIColor.clear.cgColor] as CFArray
                let bGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: bColors, locations: [0, 1])!
                c.drawRadialGradient(bGrad,
                                     startCenter: CGPoint(x:x,y:y), startRadius: 0,
                                     endCenter: CGPoint(x:x,y:y), endRadius: r, options: [])
            }
        }
    }
}

// MARK: - UIColor hex
extension UIColor {
    convenience init(hex: String) {
        var h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        if h.count == 6 { h += "FF" }
        let v = UInt64((try? UInt64(h, radix: 16)) ?? 0)
        self.init(
            red:   CGFloat((v >> 24) & 0xFF) / 255,
            green: CGFloat((v >> 16) & 0xFF) / 255,
            blue:  CGFloat((v >>  8) & 0xFF) / 255,
            alpha: CGFloat(v & 0xFF) / 255
        )
    }
}

// MARK: - Default adjustment sections
extension AdjustmentSection {
    static var defaults: [AdjustmentSection] { [
        AdjustmentSection(id: "light", title: "Light", sliders: [
            AdjustmentSlider(id: "exposure",   label: "Exposure",   min: -100, max: 100, value: 0),
            AdjustmentSlider(id: "contrast",   label: "Contrast",   min: -100, max: 100, value: 0),
            AdjustmentSlider(id: "brightness", label: "Brightness", min: -100, max: 100, value: 0),
            AdjustmentSlider(id: "highlights", label: "Highlights", min: -100, max: 100, value: 0),
            AdjustmentSlider(id: "shadows",    label: "Shadows",    min: -100, max: 100, value: 0),
        ]),
        AdjustmentSection(id: "color", title: "Color", sliders: [
            AdjustmentSlider(id: "temp",       label: "Temp",       min: -100, max: 100, value: 0),
            AdjustmentSlider(id: "saturation", label: "Saturation", min: -100, max: 100, value: 0),
            AdjustmentSlider(id: "vibrance",   label: "Vibrance",   min: -100, max: 100, value: 0),
        ]),
        AdjustmentSection(id: "detail", title: "Detail", sliders: [
            AdjustmentSlider(id: "sharpness",  label: "Sharpness",  min: 0, max: 100, value: 40),
            AdjustmentSlider(id: "noise",      label: "Noise Red.", min: 0, max: 100, value: 0),
            AdjustmentSlider(id: "vignette",   label: "Vignette",   min: -100, max: 100, value: 0),
        ]),
    ]}
}
