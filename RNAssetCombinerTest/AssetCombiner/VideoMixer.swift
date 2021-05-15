//
//  VideoMixer.swift
//  RNAssetCombinerTest
//
//  Created by Svyatoslav Ivanov on 09.10.2020.
//  Copyright © 2020 ARMA APP OU. All rights reserved.
//

import Foundation
import AVFoundation
import Photos
import UIKit

class VideoMixer: VideoMixerProtocol {
    
    private let videoMixerQueue = DispatchQueue.init(label: "com.W1D1.AssetCombiner.videoMixerQueue")
    private var export: AVAssetExportSession?
    private var size: CGSize
    
    init(size: CGSize) {
        self.size = size
    }
    
    func compose(data: [CombinerData], complete: @escaping (MixerThrowsCallback) -> Void) {
        
        let mixComposition = AVMutableComposition()
        
        do {
            let tracks: [AVMutableCompositionTrack] =  try data.map { element in
                
                let track = mixComposition.addMutableTrack(withMediaType: .video,
                                                           preferredTrackID: Int32(kCMPersistentTrackID_Invalid))!
                guard !element.asset.tracks(withMediaType: .video).isEmpty else {
                    throw CombinerError.mixerEmptyTrackArray
                }
                do {
                    try track.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: element.asset.duration),
                                              of: element.asset.tracks(withMediaType: .video)[0],
                                              at: CMTime.zero)
                } catch {
                    throw CombinerError.mixerFailedToLoadTrack
                }
                return track
            }
            
            // 2.1
            let mainInstruction = AVMutableVideoCompositionInstruction()
            var timeRange = CMTime.zero
            data.forEach { timeRange = CMTimeAdd(timeRange, $0.asset.duration)}
            mainInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: timeRange)
            
            // 2.2
            let instructions: [AVMutableVideoCompositionLayerInstruction] = tracks.enumerated().map { (index, track) in
                let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
                let transformer = AffineTransformer()
                let transform = transformer.createTransform(
                    size: size,
                    width: track.naturalSize.width,
                    height: track.naturalSize.height,
                    styles: data[index].style,
                    orientation: data[index].orientation)
                instruction.setTransform(transform, at: CMTime.zero)
                return instruction
            }
            
            // 2.3
            mainInstruction.layerInstructions = instructions
            let mainComposition = AVMutableVideoComposition()
            mainComposition.instructions = [mainInstruction]
            mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
            mainComposition.renderSize = size
            mainInstruction.backgroundColor = UIColor.clear.cgColor
            
            let videoName = UUID().uuidString
            let url = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(videoName)
                .appendingPathExtension("MOV")
            
            try? FileManager.default.removeItem(at: url)
            
            guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else { return }
            exporter.outputURL = url
            exporter.outputFileType = .mov
            exporter.shouldOptimizeForNetworkUse = true
            exporter.videoComposition = mainComposition
            exporter.fileLengthLimit =  2 * 100000 * 10 // 2MB
            
            exporter.exportAsynchronously() {
                DispatchQueue.main.async { [self] in
                    if data.contains(where: {$0.type == .video}) {
                        complete({ return url })
                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                        }) { (done, error) in
                            if (error != nil) {
                                print(error)
                            } else {
                                print("saved")}
                        }
                    } else {
                        let thumbUrl = generateThumbnail(videoUrl: url)
                        if let _thumbUrl = thumbUrl {
                            PHPhotoLibrary.shared().performChanges({
                                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: _thumbUrl)
                            }) { (succes, error) in
                                if succes {
                                    print("saved")
                                } else {
                                    print(error)
                                }
                            }
                            complete({ return _thumbUrl })
                        }
                    }
                }
            }
        } catch {
            complete({ throw error })
        }
    }
    
    private func generateThumbnail(videoUrl: URL) -> URL? {
        let asset = AVURLAsset(url: videoUrl, options: nil)
        let imgGenerator = AVAssetImageGenerator(asset: asset)
        let cgImage = try? imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("thumbnail")
            .appendingPathExtension("jpg")
        if let cgImage = cgImage {
            
            let uiImage = UIImage(cgImage: cgImage)
            do {
                try uiImage.jpegData(compressionQuality: 1.0)!.write(to: url, options: .atomic)
                return url
            } catch {
                print("file cant not be save at path \(url), with error : \(error)");
                return nil
            }
        }
        return nil
    }
    
}
