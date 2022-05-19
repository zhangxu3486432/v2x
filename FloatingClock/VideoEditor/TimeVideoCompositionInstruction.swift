//
//  VideoCompositionInstruction.swift
//  FloatingClock
//
//  Created by wl on 2020/12/17.
//

import UIKit
import AVFoundation
import SwiftDraw
import AVFoundation
import AVKit


class TimeVideoCompositionInstruction:NSObject, AVVideoCompositionInstructionProtocol {
    // Protocol Property
    var timeRange: CMTimeRange
    var enablePostProcessing = false
    var containsTweening = true
    var requiredSourceTrackIDs: [NSValue]?
    var passthroughTrackID = kCMPersistentTrackID_Invalid
    var layerInstructions:[AVVideoCompositionLayerInstruction]?
    var haveTrafficLight: Bool = false
    
    let greenSVG = UIImage(svgNamed: "green.svg")
    let yellowSVG = UIImage(svgNamed: "yellow.svg")
    let redSVG = UIImage(svgNamed: "red.svg")
    let loadingSVG = UIImage(svgNamed: "loading.svg")
    let warningSVG = UIImage(svgNamed: "warning.svg")
    let accelerateSVG = UIImage(svgNamed: "accelerate.svg")
    let decelerateSVG = UIImage(svgNamed: "decelerate.svg")
    let icwSVG = UIImage(svgNamed: "icw.svg")
    
    var currentSpeed: Double?
    var latitude: Double?
    var longitude: Double?
    
    // render string
    var lightTime: Double = 0
    var lightStatus: String = ""
    
    var recUpperSpeed: Double?
    var recFloorSpeed: Double?
    var glosa: String?
    var ICW: Bool?
    var decelRedBreak: Bool?
    var count = 0
    
//    var fontSize: CGFloat = 46
//    let fontName = "San Francisco" as CFString
    var font46 = CTFontCreateWithName("San Francisco" as CFString, 46, nil)
    var font64 = CTFontCreateWithName("San Francisco" as CFString, 64, nil)
    
    
    init(_ requiredSourceTrackIDs: [NSValue]?, timeRange: CMTimeRange) {
        self.requiredSourceTrackIDs = requiredSourceTrackIDs
        self.timeRange = timeRange
    }

    func getPixelBuffer(_ renderContext: AVVideoCompositionRenderContext) -> CVPixelBuffer? {
        let width = Int(renderContext.size.width)
        let height = Int(renderContext.size.height)
        
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue as Any ,
             kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue as Any,
                      kCVPixelBufferIOSurfacePropertiesKey: NSDictionary()
        ] as CFDictionary
        
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let cgContext = CGContext(data: pixelData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        guard let context = cgContext else {
            return nil
        }
        
        context.setFillColor(UIColor(red: 0, green: 0, blue: 0, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.saveGState()
        
        // Parameters
        var color: CGColor?
        var timeColor: CGColor?
        
        if latitude==39.9998570 && longitude==116.3466815 {
            context.fillPath(using: .evenOdd)
            context.restoreGState()
            CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
            return pixelBuffer
        }
        
        if ICW == true {
            var rect = CGRect(x: (width - 320)/2, y: (height - 320)/2, width: 320, height: 320)
            context.addRect(rect)
            context.draw((icwSVG?.cgImage)!, in: rect)
            var path = CGPath(
                roundedRect: rect,
                cornerWidth: 0.0,
                cornerHeight: 0.0,
                transform: nil
            )
            context.addPath(path)
        } else if haveTrafficLight {
            var rect = CGRect(x: 420, y: 120, width: 200, height: 200)
            context.addRect(rect)
            
            switch lightStatus {
            case "green":
                context.draw((greenSVG?.cgImage)!, in: rect)
                timeColor = CGColor.init(red: 0, green: 0.5, blue: 0, alpha: 1)
            case "red":
                context.draw((redSVG?.cgImage)!, in: rect)
                timeColor = CGColor.init(red: 1, green: 0, blue: 0, alpha: 1)
            case "yellow":
                context.draw((yellowSVG?.cgImage)!, in: rect)
                timeColor = CGColor.init(red: 1, green: 1, blue: 0, alpha: 1)
            default:
                context.draw((loadingSVG?.cgImage)!, in: rect)
                timeColor = CGColor.init(red: 0, green: 0, blue: 0, alpha: 1)
            }
            
            var path = CGPath(
                roundedRect: rect,
                cornerWidth: 0.0,
                cornerHeight: 0.0,
                transform: nil
            )
            context.addPath(path)

            // --------------------
            var title: String = ""
            var attributes: [NSAttributedString.Key: Any] = [:]
            var attributedString = NSAttributedString(string: title, attributes: attributes)
            var titleText = CTLineCreateWithAttributedString(attributedString)
            
            if decelRedBreak == true {
                title = "Warning:"
                color = CGColor.init(red: 1, green: 1, blue: 0, alpha: 1)
                attributes = [NSAttributedString.Key.font: font64, NSAttributedString.Key.foregroundColor: color!, NSAttributedString.Key.strokeWidth: NSNumber(-6)]
                attributedString = NSAttributedString(string: title, attributes: attributes)
                titleText = CTLineCreateWithAttributedString(attributedString)
                context.textPosition = CGPoint(x: 100, y: 240)
                CTLineDraw(titleText, context)
                
                title = "Red Light"
                color = CGColor.init(red: 1, green: 1, blue: 0, alpha: 1)
                attributes = [NSAttributedString.Key.font: font64, NSAttributedString.Key.foregroundColor: color!, NSAttributedString.Key.strokeWidth: NSNumber(-6)]
                attributedString = NSAttributedString(string: title, attributes: attributes)
                titleText = CTLineCreateWithAttributedString(attributedString)
                context.textPosition = CGPoint(x: 20, y: 160)
                CTLineDraw(titleText, context)
                
                title = "Violation"
                attributes = [NSAttributedString.Key.font: font64, NSAttributedString.Key.foregroundColor: color!, NSAttributedString.Key.strokeWidth: NSNumber(-6)]
                attributedString = NSAttributedString(string: title, attributes: attributes)
                titleText = CTLineCreateWithAttributedString(attributedString)
                context.textPosition = CGPoint(x: 20, y: 80)
                CTLineDraw(titleText, context)
                
                rect = CGRect(x: 20, y: 240, width: 60, height: 60)
                context.addRect(rect)
                context.draw((warningSVG?.cgImage)!, in: rect)
                path = CGPath(
                    roundedRect: rect,
                    cornerWidth: 0.0,
                    cornerHeight: 0.0,
                    transform: nil
                )
                context.addPath(path)
            } else {
                title = "Green Light Speed"
                color = CGColor.init(red: 1, green: 1, blue: 1, alpha: 1)
                context.textPosition = CGPoint(x: 20, y: 240)
                attributes = [NSAttributedString.Key.font: font46, NSAttributedString.Key.foregroundColor: color!, NSAttributedString.Key.strokeWidth: NSNumber(-6)]
                attributedString = NSAttributedString(string: title, attributes: attributes)
                titleText = CTLineCreateWithAttributedString(attributedString)
                CTLineDraw(titleText, context)

                // 建议车速
                if recFloorSpeed != nil && recUpperSpeed != nil {
                    attributes = [NSAttributedString.Key.font: font64, NSAttributedString.Key.foregroundColor: timeColor!, NSAttributedString.Key.strokeWidth: NSNumber(-6)]
                    attributedString = NSAttributedString(string: String(format:"%d-%d km/h", arguments: [Int(ceilf(Float(recFloorSpeed!)*3.6)), Int(ceilf(Float(recUpperSpeed!)*3.6))]),
                                                          attributes: attributes)
                    titleText = CTLineCreateWithAttributedString(attributedString)
                    context.textPosition = CGPoint(x: 90, y: 120)
                    CTLineDraw(titleText, context)
                }
                
                rect = CGRect(x: 20, y: 110, width: 60, height: 60)
                context.addRect(rect)
                // 加减速 icon
                switch glosa {
                case "keep":
                    print("keep")
                case "accelerate":
                    context.draw((accelerateSVG?.cgImage)!, in: rect)
                case "decelerate":
                    context.draw((decelerateSVG?.cgImage)!, in: rect)
                default:
                    print("unknow")
                }
                path = CGPath(
                    roundedRect: rect,
                    cornerWidth: 0.0,
                    cornerHeight: 0.0,
                    transform: nil
                )
                context.addPath(path)
            }
            // --------------------

            attributes = [NSAttributedString.Key.font: font64, NSAttributedString.Key.foregroundColor: timeColor!, NSAttributedString.Key.strokeWidth: NSNumber(-6)]
            attributedString = NSAttributedString(string: String(format:"%02d S", arguments: [Int(ceilf(Float(lightTime)))]), attributes: attributes)
            titleText = CTLineCreateWithAttributedString(attributedString)
            context.textPosition = CGPoint(x: 460, y: 60)
            CTLineDraw(titleText, context)
        } else {
            
        }

        // 时间

        context.fillPath(using: .evenOdd)
        context.restoreGState()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        return pixelBuffer
    }
}


extension UIImage {
    static func svgSimple() -> UIImage {
        let f = UIGraphicsImageRendererFormat.default()
        f.opaque = false
        f.preferredRange = .standard
        return UIGraphicsImageRenderer(size: CGSize(width: 160.0, height: 160.0), format: f).image {
            drawSVG(in: $0.cgContext)
        }
    }
    
    static func drawSVG(in ctx: CGContext) {
        let rgb = CGColorSpaceCreateDeviceRGB()
        let color1 = CGColor(colorSpace: rgb, components: [1.0, 0.5, 0.5, 1.0])!
        ctx.setFillColor(color1)
        let path = CGPath(
            roundedRect: CGRect(x: 0.0, y: 0.0, width: 160.0, height: 160.0),
            cornerWidth: 1.0,
            cornerHeight: 1.0,
            transform: nil
        )
        ctx.addPath(path)
        ctx.fillPath(using: .evenOdd)
        let color2 = CGColor(colorSpace: rgb, components: [0.0, 0.0, 0.0, 1.0])!
        ctx.setFillColor(color2)
        let path1 = CGMutablePath()
        path1.move(to: CGPoint(x: 80.0, y: 20.0))
        path1.addCurve(to: CGPoint(x: 30.0, y: 69.99999),
                       control1: CGPoint(x: 52.38576, y: 20.0),
                       control2: CGPoint(x: 30.000004, y: 42.385757))
        path1.addCurve(to: CGPoint(x: 79.99998, y: 120.0),
                       control1: CGPoint(x: 29.999992, y: 97.61423),
                       control2: CGPoint(x: 52.385742, y: 119.999985))
        path1.addCurve(to: CGPoint(x: 130.0, y: 70.00004),
                       control1: CGPoint(x: 107.61421, y: 120.000015),
                       control2: CGPoint(x: 129.99998, y: 97.61427))
        path1.addLine(to: CGPoint(x: 80.0, y: 70.00004))
        path1.closeSubpath()
        ctx.addPath(path1)
        ctx.fillPath(using: .evenOdd)
        ctx.setLineCap(.butt)
        ctx.setLineJoin(.miter)
        ctx.setLineWidth(2.0)
        ctx.setMiterLimit(4.0)
        let color3 = CGColor(colorSpace: rgb, components: [0.5, 0.5, 0.5, 1.0])!
        ctx.setStrokeColor(color3)
        ctx.addPath(path1)
        ctx.strokePath()
    }
}
