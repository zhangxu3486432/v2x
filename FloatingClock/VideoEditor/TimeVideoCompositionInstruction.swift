//
//  VideoCompositionInstruction.swift
//  FloatingClock
//
//  Created by wl on 2020/12/17.
//

import UIKit
import AVFoundation
import SwiftDraw


class TimeVideoCompositionInstruction:NSObject, AVVideoCompositionInstructionProtocol {
    
    // Protocol Property
    var timeRange: CMTimeRange
    var enablePostProcessing = false
    var containsTweening = true
    var requiredSourceTrackIDs: [NSValue]?
    var passthroughTrackID = kCMPersistentTrackID_Invalid
    var layerInstructions:[AVVideoCompositionLayerInstruction]?
    var lightSVG = UIImage(svgNamed: "test.svg")
    

    var htmlRaw = """
    <style type="text/css">
    #Green {
      color: #00c853;
    }
    #Yellow {
      color: #ffd600;
    }
    #Red {
      color: #d50000;
    }
    </style>
    <span style="font-size: 64; font-weight: Bold;" id="%@">%@: %.2f</span>
    """
    
    var lightLoading = """
    <span style="font-size: 64; font-weight: Bold;">Loading</span>
    """
    
    // render string
    var timeString: Float = 0
    var lightStatus: String = ""
    
    
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
        
        context.setFillColor(UIColor(red: 1, green: 1, blue: 1, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: Int(renderContext.size.width), height: Int(renderContext.size.height)))
        
        context.saveGState()
        // Parameters
        let color = CGColor.init(red: 0, green: 0, blue: 0, alpha: 1)
        let fontSize: CGFloat = 80
        // You can use the Font Book app to find the name
        let fontName = "San Francisco" as CFString
        let font = CTFontCreateWithName(fontName, fontSize, nil)
        
        let _: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: font,
                                                NSAttributedString.Key.foregroundColor: color]
        // Text
        var html: String = ""
        if lightStatus == "" {
            html = String(format:lightLoading)
        } else {
            html = String(format:htmlRaw, arguments:[lightStatus, lightStatus, timeString])
        }
        
        
        let data = Data(html.utf8)
        do {
            let attributedString = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil)
            // Render
            let line = CTLineCreateWithAttributedString(attributedString)
            let stringRect = CTLineGetImageBounds(line, context)
            
//            context.textPosition = CGPoint(x: (CGFloat(width) - stringRect.width) / 2,
            context.textPosition = CGPoint(x: 240,
                                           y: (CGFloat(height) - stringRect.height) / 2)
            
            CTLineDraw(line, context)
            
            let rect = CGRect(x: 20, y: 75, width: 200, height: 200)
            context.addRect(rect)
            context.draw((lightSVG?.cgImage)!, in: rect)
            
            let path = CGPath(
              roundedRect: rect,
              cornerWidth: 0.0,
              cornerHeight: 0.0,
              transform: nil
            )
            context.addPath(path)
            
            context.fillPath(using: .evenOdd)
            context.restoreGState()
        } catch {
            
        }
        
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
