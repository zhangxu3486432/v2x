//
//  TCP_Communicator.swift
//  app
//
//  Created by 张旭 on 2022/3/31.
//

import Foundation

class TCP_Communicator: NSObject, StreamDelegate {
    var lightStatus: String = ""
    var lightTime: Float = 0
    var readStream: Unmanaged<CFReadStream>?
    var writeStream: Unmanaged<CFWriteStream>?
    var inputStream: InputStream?
    var outputStream: OutputStream?
    var responseFramePool: [UInt8] = []
    private var url: URL;
    private var port: UInt32;
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        //        print("stream event \(eventCode)")
        switch eventCode {
        case .openCompleted:
            print("Stream opened")
        case .hasBytesAvailable:
            //            print("hasBytesAvailable")
            if aStream === inputStream {
                readAvailableBytes()
            }
        case .hasSpaceAvailable:
            print("hasSpaceAvailable")
        case .errorOccurred:
            self.disconnect()
            print("errorOccurred")
        case .endEncountered:
            self.disconnect()
            print("endEncountered")
        default:
            print("Unknown event")
        }
    }
    
    func sendData(buff: [UInt8]) {
        outputStream?.write(buff, maxLength: buff.count)
    }
    
    func send(buff: [UInt8]){
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.sendData(buff: buff)
        }
    }
    
    func readAvailableBytes() {
        var dataBuffer = Array<UInt8>(repeating: 0, count: 1024)
        while inputStream!.hasBytesAvailable {
            inputStream?.read(&dataBuffer, maxLength: 1024)
            let results:[(Data, String)] = dealWithResponse(response: dataBuffer)
            for result in results {
                switch result.1 {
                case "0002":
                    let _ = try? NebulalinkProMessage_RegisterFrame(serializedData: result.0)
                case "000A":
                    do {
                        let trafficLightResult = try NebulalinkProMessage_TrafficLight(serializedData: result.0)
                        let info = trafficLightResult.trafficLightInformationValue.first ?? nil
                        let straight = info?.trafficLightPhaseValue.first ?? nil
                        if straight?.phaseID != 1 {
                            continue
                        }
                        for direction in straight!.phaseStatusValue {
                            if direction.startTime.isEqual(to: 0) {
                                switch direction.lightStatus {
                                    case 6:
                                        lightStatus = "Green"
                                    case 7:
                                        lightStatus = "Yellow"
                                    case 3:
                                        lightStatus = "Red"
                                    default:
                                        lightStatus = ""
                                }
                                lightTime = direction.endTime
                            }
                        }
                    }
                    catch {
                        print("parse error")
                    }
                default:
                    continue
                }
            }
        }
    }
    
    func dealWithResponse(response:[UInt8]) -> [(Data, String)] {
        responseFramePool = responseFramePool + response
        var dataValue:String = responseFramePool.map{String(format:"%02X", $0)}.joined(separator: "")
        var dataSet: [(Data, String)] = []
        var startRange:Range<String.Index>?
        var endRange:Range<String.Index>?
        var startIndex:Int?
        var endIndex:Int?
        var currentResponseFrame:[UInt8]
        var dataType:String
        var dataLength:Int
        var dataSerialization:Data
        
        while true {
            startRange = dataValue.range(of: "FAFBFCFD")
            endRange = dataValue.range(of: "EAEBECED")
            // Frame Header Index
            startIndex = startRange?.upperBound.utf16Offset(in: dataValue)
            // Frame Tail Index
            endIndex = endRange?.lowerBound.utf16Offset(in: dataValue)
            if startIndex == nil || endIndex == nil {
                break
            }
            
            if startIndex! >= endIndex! {
                responseFramePool = []
                dataValue = responseFramePool.map{String(format:"%02X", $0)}.joined(separator: "")
                continue
            }
            
            currentResponseFrame = Array(responseFramePool[((startIndex!-8)/2)...endIndex!/2 + 3])
            let currentResponseFrameValue = currentResponseFrame.map{String(format:"%02X", $0)}.joined(separator: "")
            responseFramePool = Array(responseFramePool[(endIndex!/2+4)...])
            dataValue = responseFramePool.map{String(format:"%02X", $0)}.joined(separator: "")
            
            dataType = currentResponseFrame[4...5].map{String(format:"%02X", $0)}.joined(separator: "")
            dataLength = Int(currentResponseFrame[6])<<8 + Int(currentResponseFrame[7])
            
            let startIndex1 = startRange?.upperBound.utf16Offset(in: currentResponseFrameValue)
            let startIndex2 = startRange?.lowerBound.utf16Offset(in: currentResponseFrameValue)
            
            if (startIndex1!-8) != startIndex2! {
                continue
            }
            
            if (currentResponseFrame.count - 1) < dataLength+7 {
                continue
            }

//            guard let boo = foo[safe: index] else {
//              return
//            }

            dataSerialization = Data(currentResponseFrame[8...dataLength+7])
            dataSet.append((dataSerialization, dataType))
        }
        
        return dataSet
    }
    
    init(url: URL, port: UInt32) {
        self.url = url;
        self.port = port;
    }
    
    func connect() {
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (url.absoluteString as CFString), port, &readStream, &writeStream);
        print("Opening streams.")
        outputStream = writeStream?.takeRetainedValue()
        inputStream = readStream?.takeRetainedValue()
        outputStream?.delegate = self;
        inputStream?.delegate = self;
        outputStream?.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default);
        inputStream?.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default);
        outputStream?.open();
        inputStream?.open();
    }
    
    
    func disconnect(){
        print("Closing streams.");
        inputStream?.close();
        outputStream?.close();
        inputStream?.remove(from: RunLoop.current, forMode: RunLoop.Mode.default);
        outputStream?.remove(from: RunLoop.current, forMode: RunLoop.Mode.default);
        inputStream?.delegate = nil;
        outputStream?.delegate = nil;
        inputStream = nil;
        outputStream = nil;
    }
    
}

