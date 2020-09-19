////
////  copy.swift
////  RNAssetCombinerTest
////
////  Created by Svyatoslav Ivanov on 19.08.2020.
////  Copyright © 2020 ARMA APP OU. All rights reserved.
////
//
//import Foundation
//import AVFoundation
//import UIKit
//
//class Test {
//
//func newMerge(_ sender: Any) {
//
//    print("making vid")
//
//    let path = Bundle.main.path(forResource: "sample_video", ofType:"mp4")
//    let fileURL = NSURL(fileURLWithPath: path!)
//
//    let vid = AVURLAsset(url: fileURL as URL)
//
//    let path2 = Bundle.main.path(forResource: "example2", ofType:"mp4")
//    let fileURL2 = NSURL(fileURLWithPath: path2!)
//
//    let vid2 = AVURLAsset(url: fileURL2 as URL)
//
//    newoverlay(video: vid, withSecondVideo: vid2)
//
//}
//
//
//func newoverlay(video firstAsset: AVURLAsset, withSecondVideo secondAsset: AVURLAsset) {
//
//
//    // 1 - Create AVMutableComposition object. This object will hold your AVMutableCompositionTrack instances.
//    let mixComposition = AVMutableComposition()
//
//    // 2 - Create two video tracks
//    guard let firstTrack = mixComposition.addMutableTrack(withMediaType: .video,
//                                                          preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else { return }
//    do {
//        try firstTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: firstAsset.duration),
//                                       of: firstAsset.tracks(withMediaType: .video)[0],
//                                       at: CMTime.zero)
//    } catch {
//        print("Failed to load first track")
//        return
//    }
//
//    guard let secondTrack = mixComposition.addMutableTrack(withMediaType: .video,
//                                                           preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else { return }
//    do {
//        try secondTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: secondAsset.duration),
//                                        of: secondAsset.tracks(withMediaType: .video)[0],
//                                        at: CMTime.zero)
//    } catch {
//        print("Failed to load second track")
//        return
//    }
//
//
//
//
//    // Watermark Effect
//    let width: CGFloat = firstTrack.naturalSize.width + secondTrack.naturalSize.width
//    let height: CGFloat = CGFloat.maximum(firstTrack.naturalSize.height, secondTrack.naturalSize.height)
//
//
//    //bg layer
//    let bglayer = CALayer()
//    bglayer.frame = CGRect(x: 0, y: 0, width: width, height: height)
//    bglayer.backgroundColor = UIColor.blue.cgColor
//
//    let box1 = CALayer()
//    box1.frame = CGRect(x: 0, y: 0, width: firstTrack.naturalSize.width, height: firstTrack.naturalSize.height - 1)
//    box1.backgroundColor = UIColor.red.cgColor
//    box1.masksToBounds = true
//
//    let timeInterval: CFTimeInterval = 1
//    let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
//    scaleAnimation.fromValue = 1.0
//    scaleAnimation.toValue = 1.1
//    scaleAnimation.autoreverses = true
//    scaleAnimation.isRemovedOnCompletion = false
//    scaleAnimation.duration = timeInterval
//    scaleAnimation.repeatCount=Float.infinity
//    scaleAnimation.beginTime = AVCoreAnimationBeginTimeAtZero
//    box1.add(scaleAnimation, forKey: nil)
//
//    let box2 = CALayer()
//    box2.frame = CGRect(x: firstTrack.naturalSize.width + 100, y: 0, width: secondTrack.naturalSize.width, height: secondTrack.naturalSize.height)
//    box2.backgroundColor = UIColor.green.cgColor
//    box2.masksToBounds = true
//
//    let videolayer = CALayer()
//    videolayer.frame = CGRect(x: 0, y: -(height - firstTrack.naturalSize.height), width: width + 2, height: height + 2)
//    videolayer.backgroundColor = UIColor.clear.cgColor
//
//    let videolayer2 = CALayer()
//    videolayer2.frame = CGRect(x: -firstTrack.naturalSize.width, y: 0, width: width, height: height)
//    videolayer2.backgroundColor = UIColor.clear.cgColor
//
//    let parentlayer = CALayer()
//    parentlayer.frame = CGRect(x: 0, y: 0, width: width, height: height)
//    parentlayer.addSublayer(bglayer)
//    parentlayer.addSublayer(box1)
//    parentlayer.addSublayer(box2)
//    box1.addSublayer(videolayer)
//    box2.addSublayer(videolayer2)
//
//    let layercomposition = AVMutableVideoComposition()
//    layercomposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
//    layercomposition.renderSize = CGSize(width: width, height: height)
//    layercomposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayers: [videolayer, videolayer2], in: parentlayer)
//
//    // 2.1
//    let mainInstruction = AVMutableVideoCompositionInstruction()
//    mainInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: CMTimeAdd(firstAsset.duration, secondAsset.duration))
//
//    // 2.2 - this is where the 2 videos get combined into one large one.
//    let firstInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: firstTrack)
//    let move = CGAffineTransform(translationX: 0, y: 0)
//    firstInstruction.setTransform(move, at: CMTime.zero)
//
//    let secondInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: secondTrack)
//    let move2 = CGAffineTransform(translationX: firstTrack.naturalSize.width, y: 0)
//    secondInstruction.setTransform(move2, at: CMTime.zero)
//
//    // 2.3
//    mainInstruction.layerInstructions = [firstInstruction, secondInstruction]
//    //let mainComposition = AVMutableVideoComposition()
//    layercomposition.instructions = [mainInstruction]
//    layercomposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
//
//
//    layercomposition.renderSize = CGSize(width: width, height: height)
//    mainInstruction.backgroundColor = UIColor.clear.cgColor
//
//
//    //  create new file to receive data
//    let dirPaths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
//    let docsDir = dirPaths[0] as NSString
//    let movieFilePath = docsDir.appendingPathComponent("result.mov")
//    let movieDestinationUrl = NSURL(fileURLWithPath: movieFilePath)
//
//    // use AVAssetExportSession to export video
//    let assetExport = AVAssetExportSession(asset: mixComposition, presetName:AVAssetExportPresetHighestQuality)
//    assetExport?.outputFileType = AVFileType.mov
//    assetExport?.videoComposition = layercomposition
//
//    // Check exist and remove old file
//    FileManager.default.removeItemIfExisted(movieDestinationUrl as URL)
//
//    assetExport?.outputURL = movieDestinationUrl as URL
//    assetExport?.exportAsynchronously(completionHandler: {
//        switch assetExport!.status {
//        case AVAssetExportSession.Status.failed:
//            print("failed")
//            print(assetExport?.error ?? "unknown error")
//        case AVAssetExportSession.Status.cancelled:
//            print("cancelled")
//            print(assetExport?.error ?? "unknown error")
//        default:
//            print("Movie complete")
//
//            self.myurl = movieDestinationUrl as URL
//
//            PHPhotoLibrary.shared().performChanges({
//                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: movieDestinationUrl as URL)
//            }) { saved, error in
//                if saved {
//                    print("Saved")
//                }
//            }
//
//            self.playVideo()
//
//        }
//    })
//}
//
//
//
//func playVideo() {
//    let player = AVPlayer(url: myurl!)
//    let playerLayer = AVPlayerLayer(player: player)
//    playerLayer.frame = self.view.bounds
//    self.view.layer.addSublayer(playerLayer)
//    player.play()
//    print("playing...")
//}
//
//
//
//}
//
//
//extension FileManager {
//func removeItemIfExisted(_ url:URL) -> Void {
//    if FileManager.default.fileExists(atPath: url.path) {
//        do {
//            try FileManager.default.removeItem(atPath: url.path)
//        }
//        catch {
//            print("Failed to delete file")
//        }
//    }
//}
//}
