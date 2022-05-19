//
//  TCP_Communicator.swift
//  app
//
//  Created by 张旭 on 2022/3/31.
//

import Foundation


var headStraight:[Int32] = [1, 6, 11, 16, 21, 26, 31, 36]
var preTime: Float?
var preLightSatus: String?

class TCP_Communicator: NSObject, StreamDelegate {
    var lightStatus: String = ""
    var lightTime: Float = 0
    var count: Float = 0
    
    var now: Date?
    var timeInterval: TimeInterval?
    var lighTimeStamp: Int?
    var icwTimeStamp: Int?

    // current gps speed
    var currentSpeed: Double?
    var latitude: Double?
    var longitude: Double?
    
    var readStream: Unmanaged<CFReadStream>?
    var writeStream: Unmanaged<CFWriteStream>?
    var inputStream: InputStream?
    var outputStream: OutputStream?
    var responseFramePool: [UInt8] = []
    var glosa: String = ""
    var recUpperSpeed: Double?
    var recFloorSpeed: Double?
    var decelRedBreak: Bool?
    
    private var url: URL;
    private var port: UInt32;
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        //        print("stream event \(eventCode)")
        switch eventCode {
        case .openCompleted:
            print("Stream opened")
        case .hasBytesAvailable:
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
        self.sendData(buff: buff)
    }
    
    func readAvailableBytes() {
        var dataBuffer = Array<UInt8>(repeating: 0, count: 1024)
        while inputStream!.hasBytesAvailable {
            inputStream?.read(&dataBuffer, maxLength: 1024)
            let results:[(Data, String)] = dealWithResponse(response: dataBuffer)
            for result in results {
                switch result.1 {
                case "0002":
                    do {
                        let hostInfo = try NebulalinkProMessage_HostInfo(serializedData: result.0)
                        if hostInfo.hostObuValue.first?.speed != nil {
                            currentSpeed = Double(hostInfo.hostObuValue.first!.speed)
                            latitude = hostInfo.latitude
                            longitude = hostInfo.longitude
                        }
                    } catch {
                        print("NebulalinkProMessage_HostInfo parse error")
                    }
                case "000B":
                    do {
                        let icw = try NebulalinkProMessage_WarningTarget(serializedData: result.0)
//                        [V2X.NebulalinkProMessage_WarningTarget.WarningResult:
//                        warning_event_type: 6
//                        target_type: 1
//                        target_angle: -0.7009804541190825
//                        target_distance: 22.255772634019486
//                        target_vehicle_type: 10
//                        ttc: 1.4501512137911565
//                        longitude: 121.2330684
//                        latitude: 31.327113299999997
//                        altitude: 8.1
//                        speed: 8.12
//                        heading: 189.4125
//                        time: 1652421381
//                        local_id: 27528
//                        ]
                        for warningResultItem in icw.warningResultValue {
                            if warningResultItem.warningEventType == 6 {
                                now = Date()
                                timeInterval = now!.timeIntervalSince1970
                                icwTimeStamp = Int(CLongLong(round(timeInterval!*1000)))
                            }
                        }
                    } catch {
                        print("icw error")
                    }
                case "000F":
                    do {
                        let trafficLightResult = try NebulalinkProMessage_TrafficLightResult(serializedData: result.0)
                        
                        for trafficLightResultItem in trafficLightResult.trafficLightResultInformationValue {
                            let phaseID = trafficLightResultItem.phaseID
                            
                            if !headStraight.contains(phaseID) {
                                continue
                            } else {
                                now = Date()
                                timeInterval = now!.timeIntervalSince1970
                                lighTimeStamp = Int(CLongLong(round(timeInterval!*1000)))
                            }
                            
                            let lightState = trafficLightResultItem.lightState
                            let timeRemaining = trafficLightResultItem.timeRemaining
                            recUpperSpeed = trafficLightResultItem.recUpperSpeed
                            recFloorSpeed = trafficLightResultItem.recFloorSpeed
                            
                            if trafficLightResultItem.decelRedBreak > 0.8 {
                                decelRedBreak = true
                            } else {
                                decelRedBreak = false
                            }
                            switch lightState {
                            case 6:
                                lightStatus = "green"
                            case 7:
                                lightStatus = "yellow"
                            case 3:
                                lightStatus = "red"
                            default:
                                lightStatus = ""
                            }
                            
                            if preTime == nil || preLightSatus == nil || preLightSatus != lightStatus || preTime! >= Float(timeRemaining) {
                                lightTime = Float(timeRemaining)
                            }
                            
                            preTime = Float(timeRemaining)
                            preLightSatus = lightStatus
                            
                            if currentSpeed == nil {
                                break
                            }
                            
                            if currentSpeed! > recUpperSpeed! {
                                glosa = "decelerate"
                            } else if currentSpeed! < recFloorSpeed! {
                                glosa = "accelerate"
                            } else {
                                glosa = "keep"
                            }
                            break
                        }
                    }
                    catch {
                        print("NebulalinkProMessage_TrafficLightResult parse error")
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

