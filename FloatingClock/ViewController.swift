//
//  ViewController.swift
//  FloatingClock
//
//  Created by wl on 2020/12/16.
//

import UIKit
import AVFoundation
import AVKit
import Alamofire



class ViewController: UIViewController {
    var asset: AVAsset!
    var item: AVPlayerItem!
    var player: AVPlayer!
    var observation: NSKeyValueObservation!
    var pipController: AVPictureInPictureController!
    var videoComposition: AVMutableVideoComposition!
    var playerLayer: AVPlayerLayer!
    var timeInstruction: TimeVideoCompositionInstruction!
    var haveTrafficLight: Bool = false
    var haveICWWarning: Bool = false

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
        pipController?.startPictureInPicture()
    }
    
    func createDisplayLink() {
        let displaylink = CADisplayLink(target: self,
                                        selector: #selector(refresh))
        // 每秒渲染两帧
        displaylink.preferredFramesPerSecond = 2
        displaylink.add(to: .current,
                        forMode: .default)
    }

    @objc func refresh(displaylink: CADisplayLink) {
        reloadTime()
        item?.videoComposition = videoComposition
    }
    func reloadTime() {
        haveTrafficLight = true
        haveICWWarning = false
        self.timeInstruction.haveTrafficLight = haveTrafficLight
        self.timeInstruction.ICW = haveICWWarning
        
        AF.request("http://172.20.10.3:5001/v2x", method: .get)
            .responseJSON { response in
                switch response.result {
                    case .success(let value as [String: Any]):
                        self.timeInstruction.over = value["over"] as! Bool
                        self.timeInstruction.currentSpeed = value["current_speed"] as! Double
                        self.timeInstruction.glosa = value["glosa"] as! String
                        self.timeInstruction.decelRedBreak = false
                        self.timeInstruction.lightTime = value["light_time"] as! Double
                        self.timeInstruction.lightStatus = value["light_status"] as! String
                        self.timeInstruction.recFloorSpeed = value["floor_speed"] as! Double
                        self.timeInstruction.recUpperSpeed = value["upper_speed"] as! Double
                    case .failure(let error):
                        debugPrint("Failure: \(error)")
                    default: fatalError("Fatal error.")
                }
            }
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
        playerLayer.backgroundColor = UIColor.cyan.cgColor
        view.layer.addSublayer(playerLayer)
        if !AVPictureInPictureController.isPictureInPictureSupported() {
            pipButton.setTitle("not support PIP, please use real device", for: .normal)
            pipButton.isEnabled = false
        }
    }
}
