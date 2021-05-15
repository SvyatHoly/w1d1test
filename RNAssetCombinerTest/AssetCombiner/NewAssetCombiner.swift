////
////  NewAssetCombiner.swift
////  RNAssetCombinerTest
////
////  Created by Svyatoslav Ivanov on 07.10.2020.
////  Copyright © 2020 ARMA APP OU. All rights reserved.
////
//
//import Foundation
//import AVFoundation
//import Photos
//import UIKit
//
//class NewAssetCombiner: NSObject {
//    
//    var myurl: URL?
//    let combineQueue = DispatchQueue.init(label: "com.W1D1.AssetCombiner.combineQueue")
//    var data: JSON?
//    var export: AVAssetExportSession?
//    //  var size = CGSize(width: 590, height: 1280)
//    var size = CGSize(width: 590, height: 1280)
//    var screenSize = CGSize(width: 414, height: 896)
//    var squareDevider: Int = 1
//    
//    func combine(json: [String: Any],
//                 resolve: (() -> Void)? = nil,
//                 reject: (() -> Void)? = nil) -> Void {
//        combineQueue.sync {
//            self.parseJson(json: json)
//        }
//    }
//    
//    func parseJson(json: [String: Any]) {
//        do {
//            self.data = try JSONDecoder().decode(JSON.self, from: JSONSerialization.data(withJSONObject: json))
//        } catch {
//            print("Failed to decode JSON")
//        }
//        generateCombinerDataArray(data!.videos!)
//    }
//    
//    func generateCombinerDataArray(_ videos: [Asset]) {
//        let asset1 = AVAsset(url: Bundle.main.url(forResource: videos[0].local, withExtension: "MOV")!)
//        let asset2 = AVAsset(url: Bundle.main.url(forResource: videos[1].local, withExtension: "MOV")!)
//        makeVideo(video: asset1, withSecondVideo: asset2)
//    }
//    
//    func makeVideo(video firstAsset: AVAsset, withSecondVideo secondAsset: AVAsset) {
//        
//        // 1 - Create AVMutableComposition object. This object will hold your AVMutableCompositionTrack instances.
//        let mixComposition = AVMutableComposition()
//        
//        // 2 - Create two video tracks
//        guard let firstTrack = mixComposition.addMutableTrack(withMediaType: .video,
//                                                              preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else { return }
//        do {
//            try firstTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: firstAsset.duration),
//                                           of: firstAsset.tracks(withMediaType: .video)[0],
//                                           at: CMTime.zero)
//        } catch {
//            print("Failed to load first track")
//            return
//        }
//        
//        guard let secondTrack = mixComposition.addMutableTrack(withMediaType: .video,
//                                                               preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else { return }
//        do {
//            try secondTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: secondAsset.duration),
//                                            of: secondAsset.tracks(withMediaType: .video)[0],
//                                            at: CMTime.zero)
//        } catch {
//            print("Failed to load second track")
//            return
//        }
//        
//        // 2.1
//        let mainInstruction = AVMutableVideoCompositionInstruction()
//        mainInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: CMTimeAdd(firstAsset.duration, secondAsset.duration))
//        
//        // 2.2
//        let firstInstruction = videoCompositionInstruction(firstTrack, asset: firstAsset)
//        let scale = CGAffineTransform(scaleX: 1, y: 1)
//        let move = CGAffineTransform(translationX: 0, y: 0)
//        firstInstruction.setTransform(move, at: CMTime.zero)
//        let secondInstruction = videoCompositionInstruction(secondTrack, asset: secondAsset)
//        secondInstruction.setTransform(scale.concatenating(move), at: CMTime.zero)
//        // 2.3
//        mainInstruction.layerInstructions = [secondInstruction, firstInstruction]
//        let mainComposition = AVMutableVideoComposition()
//        mainComposition.instructions = [mainInstruction]
//        mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
//        
////        let width = max(firstTrack.naturalSize.width, secondTrack.naturalSize.width)
////        let height = max(firstTrack.naturalSize.height, secondTrack.naturalSize.height)
//        
//        mainComposition.renderSize = CGSize(width: 1080, height: 1920)
//        
//        mainInstruction.backgroundColor = UIColor.clear.cgColor
//        
//        
//        // 4 - Get path
//        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateStyle = .long
//        dateFormatter.timeStyle = .short
//        let date = dateFormatter.string(from: Date())
//        let url = documentDirectory.appendingPathComponent("mergeVideo-\(date).mov")
//        
//        // Check exists and remove old file
//        FileManager.default.removeItemIfExisted(url as URL)
//        
//        // 5 - Create Exporter
//        guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else { return }
//        exporter.outputURL = url
//        exporter.outputFileType = AVFileType.mov
//        exporter.shouldOptimizeForNetworkUse = true
//        exporter.videoComposition = mainComposition
//        
//        
//        // 6 - Perform the Export
//        exporter.exportAsynchronously() {
//            DispatchQueue.main.async {
//                
//                print("Movie complete")
//                
//                self.myurl = url as URL
//                
//                PHPhotoLibrary.shared().performChanges({
//                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url as URL)
//                }) { saved, error in
//                    if saved {
//                        print("Saved")
//                    }
//                }
//            }
//        }
//    }
//    
//    func videoCompositionInstruction(_ track: AVCompositionTrack, asset: AVAsset) -> AVMutableVideoCompositionLayerInstruction {
//        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
////        let assetTrack = asset.tracks(withMediaType: AVMediaType.video)[0]
////
////        let transform = assetTrack.preferredTransform
////        let assetInfo = orientationFromTransform(transform)
////
////        var scaleToFitRatio = UIScreen.main.bounds.width / assetTrack.naturalSize.width
////        if assetInfo.isPortrait {
////            scaleToFitRatio = UIScreen.main.bounds.width / assetTrack.naturalSize.height
////            let scaleFactor = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
////            instruction.setTransform(assetTrack.preferredTransform.concatenating(scaleFactor), at: CMTime.zero)
////        } else {
////            let scaleFactor = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
////            var concat = assetTrack.preferredTransform.concatenating(scaleFactor)
////                .concatenating(CGAffineTransform(translationX: 0, y: UIScreen.main.bounds.width / 2))
////            if assetInfo.orientation == .down {
////                let fixUpsideDown = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
////                let windowBounds = UIScreen.main.bounds
////                let yFix = assetTrack.naturalSize.height + windowBounds.height
////                let centerFix = CGAffineTransform(translationX: assetTrack.naturalSize.width, y: yFix)
////                concat = fixUpsideDown.concatenating(centerFix).concatenating(scaleFactor)
////            }
////            instruction.setTransform(concat, at: CMTime.zero)
////        }
//        
//        return instruction
//    }
//    
//    func orientationFromTransform(_ transform: CGAffineTransform) -> (orientation: UIImage.Orientation, isPortrait: Bool) {
//        var assetOrientation = UIImage.Orientation.up
//        var isPortrait = false
//        if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
//            assetOrientation = .right
//            isPortrait = true
//        } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
//            assetOrientation = .left
//            isPortrait = true
//        } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
//            assetOrientation = .up
//        } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
//            assetOrientation = .down
//        }
//        return (assetOrientation, isPortrait)
//    }
//    
//    
//}
//
//
//extension FileManager {
//    func removeItemIfExisted(_ url:URL) -> Void {
//        if FileManager.default.fileExists(atPath: url.path) {
//            do {
//                try FileManager.default.removeItem(atPath: url.path)
//            }
//            catch {
//                print("Failed to delete file")
//            }
//        }
//    }
//}
