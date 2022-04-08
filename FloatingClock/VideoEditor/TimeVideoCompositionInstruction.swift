//
//  VideoCompositionInstruction.swift
//  FloatingClock
//
//  Created by wl on 2020/12/17.
//

import UIKit
import AVFoundation

class TimeVideoCompositionInstruction:NSObject, AVVideoCompositionInstructionProtocol {
    
    // Protocol Property
    var timeRange: CMTimeRange
    var enablePostProcessing = false
    var containsTweening = true
    var requiredSourceTrackIDs: [NSValue]?
    var passthroughTrackID = kCMPersistentTrackID_Invalid
    var layerInstructions:[AVVideoCompositionLayerInstruction]?
    

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
//            print(attributedString)
            let line = CTLineCreateWithAttributedString(attributedString)
            let stringRect = CTLineGetImageBounds(line, context)
            
            context.textPosition = CGPoint(x: (CGFloat(width) - stringRect.width) / 2,
                                           y: (CGFloat(height) - stringRect.height) / 2)
            
            CTLineDraw(line, context)
            context.restoreGState()
        } catch {
            
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        return pixelBuffer
    }
}

