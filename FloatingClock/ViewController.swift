//
//  ViewController.swift
//  FloatingClock
//
//  Created by wl on 2020/12/16.
//

import UIKit
import AVFoundation
import AVKit

let urlStr: String = "17.87.18.129"
let port: Int = 6000
//let urlStr: String = "192.168.10.224"
//let port: Int = 5050

var count: Int = 0
var now: Date?
var timeInterval: TimeInterval?
var timeStamp: Int?

let url = URL(string: urlStr)!

var socketConnector:TCP_Communicator = TCP_Communicator(url: url, port: UInt32(port))


class ViewController: UIViewController {
    var asset: AVAsset!
    var item: AVPlayerItem!
    var player: AVPlayer!
    var observation: NSKeyValueObservation!
    var pipController: AVPictureInPictureController!
    var videoComposition: AVMutableVideoComposition!
    var playerLayer: AVPlayerLayer!
    var timeInstruction: TimeVideoCompositionInstruction!
    var preRedLightWarning: Bool = false
    var redLightWarning: Bool = false

    @IBOutlet weak var pipButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupVideo()
    }
    
    func destroy() {
        self.player = nil
        self.asset = nil
        self.item = nil
        self.observation = nil
        self.pipController = nil
        self.videoComposition = nil
        self.playerLayer = nil
    }

    @IBAction func startPIP(_ sender: UIButton) {
        socketConnector.connect()
        let registerData:[UInt8] = [250, 251, 252, 253, 0, 1, 0, 175, 8, 1, 18, 11, 97, 112, 112, 108, 101, 95, 115, 119, 105, 102, 116, 26, 8, 8, 1, 16, 1, 24, 160, 141, 6, 26, 8, 8, 2, 16, 1, 24, 160, 141, 6, 26, 8, 8, 3, 16, 1, 24, 160, 141, 6, 26, 8, 8, 4, 16, 1, 24, 160, 141, 6, 26, 8, 8, 5, 16, 1, 24, 160, 141, 6, 26, 8, 8, 6, 16, 1, 24, 160, 141, 6, 26, 8, 8, 7, 16, 1, 24, 160, 141, 6, 26, 8, 8, 8, 16, 1, 24, 160, 141, 6, 26, 8, 8, 9, 16, 1, 24, 160, 141, 6, 26, 8, 8, 10, 16, 1, 24, 160, 141, 6, 26, 8, 8, 11, 16, 1, 24, 160, 141, 6, 26, 8, 8, 12, 16, 1, 24, 160, 141, 6, 26, 8, 8, 13, 16, 1, 24, 160, 141, 6, 26, 8, 8, 14, 16, 1, 24, 160, 141, 6, 26, 8, 8, 15, 16, 1, 24, 160, 141, 6, 26, 8, 8, 16, 16, 1, 24, 160, 141, 6, 234, 235, 236, 237]
        socketConnector.send(buff: registerData)
//        pipController?.startPictureInPicture()
    }
    
    @IBAction func V2XConnect(_ sender: UIButton) {
        print("Socket Connect")
        socketConnector.connect()
    }
    func createDisplayLink() {
        let displaylink = CADisplayLink(target: self,
                                        selector: #selector(refresh))
        displaylink.preferredFramesPerSecond = 10
        displaylink.add(to: .current,
                        forMode: .default)
    }

    @objc func refresh(displaylink: CADisplayLink) {
        reloadTime()
        item?.videoComposition = videoComposition
    }
    func reloadTime() {
        now = Date()
        timeInterval = now!.timeIntervalSince1970
        timeStamp = Int(CLongLong(round(timeInterval!*1000)))
        if timeStamp! - (socketConnector.timeStamp ?? 0)! > 1000 {
            redLightWarning = false
        } else {
            redLightWarning = true
        }
        
        if redLightWarning == true && preRedLightWarning != redLightWarning {
            print("start")
            pipController?.startPictureInPicture()
        } else if redLightWarning == false && preRedLightWarning != redLightWarning {
            print("stop")
            pipController?.stopPictureInPicture()
        }
        
        preRedLightWarning = self.timeInstruction.redLightWarning

        self.timeInstruction.redLightWarning = redLightWarning
        self.timeInstruction.lightTime = Double(socketConnector.lightTime)
        self.timeInstruction.lightStatus = socketConnector.lightStatus
        self.timeInstruction.recFloorSpeed = socketConnector.recFloorSpeed
        self.timeInstruction.recUpperSpeed = socketConnector.recUpperSpeed
    }
}

extension ViewController: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("pip will start")
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("pip did start")
    }
}

extension ViewController {
    func setupVideo() {
        guard let url = Bundle.main.url(forResource: "temp", withExtension: "mov") else {
            return
        }
        asset = AVAsset(url: url)
        item = AVPlayerItem(asset: asset!)
        player = AVPlayer(playerItem: item)

        playerLayer.player = player
        pipController = AVPictureInPictureController(playerLayer: playerLayer)
        pipController.requiresLinearPlayback = true
        pipController?.delegate = self
        
        observation = player?.observe(\.status, options: .new, changeHandler: {[weak self] (player, _) in
            guard let self = self else { return }
            switch player.status {
            case .readyToPlay:
                print("readyToPlay")
                self.loadAssetProperty()
            case .failed:
                print("failed")
            case .unknown:
                print("unknown")
            @unknown default:break
            }
        })
    }
    
    func loadAssetProperty() {
        self.asset.loadValuesAsynchronously(forKeys: ["duration", "tracks"]) { [weak self] in
            guard let self = self else { return }
            var error: NSError?
            let durationStatus = self.asset.statusOfValue(forKey: "duration", error: &error)
            let tracksStatus = self.asset.statusOfValue(forKey: "tracks", error: &error)
            switch (durationStatus, tracksStatus){
            case (.loaded, .loaded):
                DispatchQueue.main.async {
                    self.setupComposition()
                    self.createDisplayLink()
                }
            default:
                print("load failed")
            }
        }
    }
    
    func setupComposition()  {
        // For best performance, ensure that the duration and tracks properties of the asset are already loaded before invoking this method.
        videoComposition = AVMutableVideoComposition(propertiesOf: asset!)
        let instructions = videoComposition.instructions as! [AVVideoCompositionInstruction]
        var newInstructions: [AVVideoCompositionInstructionProtocol] = []
        
        guard let instruction = instructions.first else {
            return
        }
        let layerInstructions = instruction.layerInstructions
        // TrackIDs
        var trackIDs: [CMPersistentTrackID] = []
        for layerInstruction in layerInstructions {
            trackIDs.append(layerInstruction.trackID)
        }
        timeInstruction = TimeVideoCompositionInstruction(trackIDs as [NSValue], timeRange: instruction.timeRange)
        timeInstruction.layerInstructions = layerInstructions
        newInstructions.append(timeInstruction)
        videoComposition.instructions = newInstructions
        
        self.videoComposition?.customVideoCompositorClass = TimeVideoComposition.self
        item?.videoComposition = videoComposition
    }

    func setupUI() {
        playerLayer = AVPlayerLayer()
        playerLayer.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        playerLayer.position = view.center
//        playerLayer.backgroundColor = UIColor.cyan.cgColor
        playerLayer.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0).cgColor
        view.layer.addSublayer(playerLayer)
        if !AVPictureInPictureController.isPictureInPictureSupported() {
            pipButton.setTitle("not support PIP, please use real device", for: .normal)
            pipButton.isEnabled = false
        }
    }
}
