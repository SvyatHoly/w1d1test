import Foundation
import AVFoundation
import Photos
import UIKit

struct CombinerData {
    var asset: AVAsset
    var style: VideoStyles
}

@objc(AssetCombiner)
class AssetCombiner: NSObject {
    
    let combineQueue = DispatchQueue.init(label: "com.W1D1.AssetCombiner.combineQueue")
    var data: JSON?
    var export: AVAssetExportSession?
    var videoWriterInput: AVAssetWriterInput?
    var videoWriter: AVAssetWriter?
    var assetReader: AVAssetReader?
    var startTime: CMTime?
    var endTime: CMTime?
    let bitrate:NSNumber = NSNumber(value:250000)
//    var size = CGSize(width: 1080, height: 1920)
    var size = CGSize(width: 414, height: 896)
    
    func parseJson(json: [String: Any]) {
        self.data = try? JSONDecoder().decode(JSON.self, from: JSONSerialization.data(withJSONObject: json))
    }
    
    func generateCombinerDataArray(videos: [Video]) -> [CombinerData] {
        var result: [CombinerData] = videos.map {
            let asset = AVAsset(url: Bundle.main.url(forResource: $0.local, withExtension: "mp4")!)
            let style = $0.styles
            return CombinerData(asset: asset, style: style)
        }
        result.sort { $0.asset.duration > $1.asset.duration }
        return result
    }

    
    private func setLayerTransform(layer: CALayer, styles: VideoStyles, scaleMultiplier: CGFloat) {
        var transform = layer.affineTransform()
        let string = styles.transform[1].rotate!
        let degrees = CGFloat(Float(string.dropLast(3))!)
        var top: Double = styles.top
        //top.negate()
        
        transform = transform.concatenating(CGAffineTransform(scaleX: scaleMultiplier, y: scaleMultiplier))
        transform = transform.concatenating(CGAffineTransform(
            translationX: layer.frame.width / scaleMultiplier,
            y: layer.frame.height / scaleMultiplier))
        
        transform = transform.concatenating(CGAffineTransform(
            rotationAngle: CGFloat( CGFloat.pi / 180 * degrees)))
        transform = transform.concatenating(CGAffineTransform(
            scaleX: CGFloat(styles.transform[0].scale!),
            y: CGFloat(styles.transform[0].scale!)))
        transform = transform.concatenating(CGAffineTransform(
            translationX: CGFloat(top),
            y: CGFloat(styles.stylesLeft)))
        
        layer.setAffineTransform(transform)
        layer.zPosition = CGFloat(styles.zIndex)
        
    }
    
    private func calcInstructionOffset(
        transform: inout CGAffineTransform,
        index: Int,
        squareDevider: Int,
        maxCapacity: Int,
        sWidth: CGFloat,
        sHeight: CGFloat) -> (CGAffineTransform, CGPoint) {
        let scale: CGFloat = CGFloat(1) / CGFloat(squareDevider)
        let modulo = Float(index / squareDevider)
        let positionX = CGFloat(index - (Int(modulo) * squareDevider)) * sWidth
        let positionY = CGFloat(modulo) * sHeight
        transform = transform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
        transform = transform.concatenating(CGAffineTransform(translationX: positionX, y: positionY))
        return (transform, CGPoint(x: positionX, y: positionY))
    }
    
    private func addImage(to layer: CALayer, videoSize: CGSize, content: UIImage?) {
        let image = UIImage(named: "exploding")!
        let imageLayer = CALayer()
        
        imageLayer.frame = CGRect(origin: .zero, size: videoSize)
        imageLayer.opacity = 0.7
        imageLayer.contents = image.cgImage
        layer.addSublayer(imageLayer)
    }
    
    private func renderImageFrom(text: String, styles: LabelStyles) -> UIImage? {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let nameLabel = UILabel(frame: frame)
        nameLabel.textAlignment = .center
        nameLabel.backgroundColor = .lightGray
        nameLabel.textColor = .white
        nameLabel.font = UIFont.boldSystemFont(ofSize: 40)
        nameLabel.text = text
        UIGraphicsBeginImageContext(frame.size)
        if let currentContext = UIGraphicsGetCurrentContext() {
            nameLabel.layer.render(in: currentContext)
            let nameImage = UIGraphicsGetImageFromCurrentImageContext()
            return nameImage
        }
        return nil
    }
    
    private func createVideo() {
        if data!.videos.count == 0 { return }
        
        let combinerDataArray = generateCombinerDataArray(videos: data!.videos)
        let videoTrackArray = combinerDataArray.map { $0.asset.tracks(withMediaType: .video).first }
        if videoTrackArray.count != combinerDataArray.count { return }
        
        let mixComposition = AVMutableComposition()
        let compositionTrackArray: [AVMutableCompositionTrack] = combinerDataArray.map {
            let track = mixComposition.addMutableTrack(withMediaType: .video,
                                                       preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
            do {
                try track!.insertTimeRange(CMTimeRangeMake(
                    start: CMTime.zero,
                    duration: $0.asset.duration),
                                           of: $0.asset.tracks(withMediaType: .video)[0],
                                           at: CMTime.zero)
            } catch {
                print("Failed to load track")
            }
            if $0.asset != combinerDataArray[0].asset {
                let finalDuration = combinerDataArray[0].asset.duration
                var curDuration = CMTime.zero
                while finalDuration != curDuration {
                    let durationToAdd = $0.asset.duration < CMTimeSubtract(finalDuration, curDuration)
                        ? $0.asset.duration
                        : CMTimeSubtract(finalDuration, curDuration)
                    do {
                        try track!.insertTimeRange(CMTimeRangeMake(
                            start: CMTime.zero,
                            duration: durationToAdd),
                                                   of: $0.asset.tracks(withMediaType: .video)[0],
                                                   at: curDuration)
                    } catch {
                        print("Failed to load track")
                    }
                    curDuration = CMTimeAdd(curDuration, durationToAdd)
                }
            }
            return track!
        }
        
        
        var squareDevider = 1, maxCapacity = 0, state = true
        while state {
            let videoWidth = size.width / CGFloat(squareDevider)
            let videoHeight = size.height / CGFloat(squareDevider)
            let maxS = size.height * size.width
            let videoS = videoHeight * videoWidth
            if maxS - (videoS * CGFloat(combinerDataArray.count)) >= 0 {
                maxCapacity = Int(maxS / videoS)
                state = false
            } else {
                squareDevider += 1
            }
        }
        let squareWidth = size.width / CGFloat(squareDevider)
        let squareHeight = size.height / CGFloat(squareDevider)
        
        let bglayer = CALayer()
        bglayer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        bglayer.backgroundColor = UIColor.blue.cgColor
        
        let parentlayer = CALayer()
        parentlayer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        parentlayer.addSublayer(bglayer)
        
        var layerInstructionsArray: [AVMutableVideoCompositionLayerInstruction] = []
        var videoLayerArray: [CALayer] = []
        
        for (index, track) in videoTrackArray.enumerated() {
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(
                assetTrack: compositionTrackArray[index])
            var transform = track!.preferredTransform
            let tuple = calcInstructionOffset(transform: &transform,
                                              index: index,
                                              squareDevider: squareDevider,
                                              maxCapacity: maxCapacity,
                                              sWidth: squareWidth,
                                              sHeight: squareHeight)
            layerInstruction.setTransform(tuple.0, at: CMTime.zero)
            layerInstructionsArray.append(layerInstruction)
            
            let box = CALayer()

            box.frame = CGRect(x: 0, y: 0, width: squareWidth, height: squareHeight)
            box.backgroundColor = UIColor.red.cgColor
            box.masksToBounds = true
            setLayerTransform(layer: box, styles: combinerDataArray[index].style, scaleMultiplier: CGFloat(squareDevider))
            parentlayer.addSublayer(box)
            
            let videolayer = CALayer()
            let newH = tuple.1.y == 0 ? size.height - (size.height / CGFloat(squareDevider)) : 0
            videolayer.frame = CGRect(x: -tuple.1.x, y: -newH, width: size.width, height: size.height)
            videolayer.backgroundColor = UIColor.clear.cgColor
            videoLayerArray.append(videolayer)
            box.addSublayer(videolayer)
        }
        
        //addImage(to: parentlayer, videoSize: outVideoSize, content: nil)
        
        let layercomposition = AVMutableVideoComposition()
        layercomposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        layercomposition.renderSize = CGSize(width: size.width, height: size.height)
        layercomposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayers: videoLayerArray, in: parentlayer)
        
        let mainInstruction = AVMutableVideoCompositionInstruction()
        var timeSum = CMTime.zero
        combinerDataArray.forEach { timeSum = CMTimeAdd(timeSum, $0.asset.duration)}
        mainInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: timeSum)
        
        mainInstruction.layerInstructions = layerInstructionsArray
        layercomposition.instructions = [mainInstruction]
        layercomposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        
        mainInstruction.backgroundColor = UIColor.clear.cgColor
        
        let videoName = UUID().uuidString
        let exportURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(videoName)
            .appendingPathExtension("MOV")
        
//        let exporter = NextLevelSessionExporter(withAsset: mixComposition)
//        exporter.outputFileType = AVFileType.mov
//        exporter.outputURL = exportURL
//        exporter.videoComposition = layercomposition
//
//        let compressionDict: [String: Any] = [
//            AVVideoAverageBitRateKey: self.bitrate,
//            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel as String,
//        ]
//        exporter.videoOutputConfiguration = [
//            AVVideoCodecKey: AVVideoCodecType.h264,
//            AVVideoWidthKey: size.width,
//            AVVideoHeightKey: size.height,
//            AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
//            AVVideoCompressionPropertiesKey: compressionDict
//        ]
//
//        exporter.export(progressHandler: { (progress) in
//            print(progress)
//        }, completionHandler: { result in
//            switch result {
//            case .success(let status):
//                switch status {
//                case .completed:
//                    print("NextLevelSessionExporter, export completed")
//                    self.completion(url: exporter.outputURL!)
//                    break
//                default:
//                    print("NextLevelSessionExporter, did not complete")
//                    break
//                }
//                break
//            case .failure(let error):
//                print("NextLevelSessionExporter, failed to export \(error)")
//                break
//            }
//        })
        //TODO: Set your desired video size here!

        //setupWriter()
        //create asset reader
//        do{
//            assetReader = try AVAssetReader(asset: mixComposition)
//        } catch{
//            assetReader = nil
//        }
//        guard let reader = assetReader else{
//            fatalError("Could not initalize asset reader probably failed its try catch")
//        }
//        let videoReaderSettings: [String:Any] =  [kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32ARGB ]
//        // ADJUST BIT RATE OF VIDEO HERE
//        let videoSettings:[String:Any] = [
//            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey:self.bitrate],
//            AVVideoCodecKey: AVVideoCodecType.h264,
//            AVVideoHeightKey: 414,
//            AVVideoWidthKey: 896
//        ]
        
//        let settings: [String : Any] = [
//            AVVideoCodecKey: AVVideoCodecType.hevc,
//            AVVideoWidthKey: size.width,
//            AVVideoHeightKey: size.height,
//            AVVideoColorPropertiesKey : [
//                AVVideoColorPrimariesKey : AVVideoColorPrimaries_ITU_R_709_2,
//                AVVideoTransferFunctionKey :
//                AVVideoTransferFunction_ITU_R_709_2,
//                AVVideoYCbCrMatrixKey : AVVideoYCbCrMatrix_ITU_R_709_2
//            ],
//            AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill
//        ]
//
//        let assetReaderVideoOutputArr = mixComposition.tracks.map {
//            AVAssetReaderTrackOutput(track: $0, outputSettings: videoReaderSettings)}
//        assetReaderVideoOutputArr.forEach {
//            if reader.canAdd($0){
//                reader.add($0)
//            }else{
//                fatalError("Couldn't add video output reader")
//            }
//        }
//
//        let videoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: settings)
////         videoInput.transform = CGAffineTransform(rotationAngle: .pi/2)
//
//        let videoInputQueue = DispatchQueue(label: "videoQueue")
//        let audioInputQueue = DispatchQueue(label: "audioQueue")
//        do{
//            let outputFileLocation = videoFileLocation()
//            videoWriter = try AVAssetWriter(url: outputFileLocation, fileType: AVFileType.mov)
//        }catch{
//            videoWriter = nil
//        }
//        guard let writer = videoWriter else{
//            fatalError("assetWriter was nil")
//        }
//        writer.shouldOptimizeForNetworkUse = true
//        writer.add(videoInput)
//        writer.startWriting()
//        reader.startReading()
//        writer.startSession(atSourceTime: CMTime.zero)
//
//        var videoFinished = false
//

//
//        let closeWriter:()->Void = {
//            if videoFinished {
//                self.videoWriter?.finishWriting(completionHandler: {
//                    completion(url: (self.videoWriter?.outputURL)!)
//                })
//                self.assetReader?.cancelReading()
//            }
//        }
//        videoInput.requestMediaDataWhenReady(on: videoInputQueue) {
//            //request data here
//            while(videoInput.isReadyForMoreMediaData){
//                let sample = assetReaderVideoOutputArr[0].copyNextSampleBuffer()
//                sample.append(sample!)
//                if (sample != nil){
//                    videoInput.append(sample!)
//                }else{
//                    videoInput.markAsFinished()
//                    DispatchQueue.main.async {
//                        videoFinished = true
//                        closeWriter()
//                    }
//                    break;
//                }
//            }
//        }
        
        self.export = AVAssetExportSession(
            asset: mixComposition,
            presetName: AVAssetExportPresetHighestQuality)

        self.export!.videoComposition = layercomposition
        self.export!.outputFileType = .mov
        self.export!.outputURL = exportURL

        try? FileManager.default.removeItem(at: URL(fileURLWithPath: exportURL.path))
        self.export!.exportAsynchronously {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL:
                    self.export!.outputURL!)
            }) {
                success, error in
                if success {
                    print("success")
                    try? FileManager.default.removeItem(at: URL(fileURLWithPath: exportURL.path))
                } else {
                    print(error.debugDescription)
                    try? FileManager.default.removeItem(at: URL(fileURLWithPath: exportURL.path))
                }
            }
        }
    }
    
    private func completion(url: URL) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) {
            success, error in
            if success {
                try? FileManager.default.removeItem(at: self.videoFileLocation())
            } else {
                print(error.debugDescription)
                try? FileManager.default.removeItem(at: self.videoFileLocation())
            }
        }
    }
    
    private func setupWriter() {
        
        startTime = CMTime.zero
        endTime = CMTime.zero
        
        do {
            let outputFileLocation = videoFileLocation()
            videoWriter = try AVAssetWriter(url: outputFileLocation, fileType: AVFileType.mov)
            
            
//            let settings: [String : Any] = [
//                AVVideoCodecKey: AVVideoCodecType.hevc,
//                AVVideoWidthKey: size.width,
//                AVVideoHeightKey: size.height,
//                AVVideoColorPropertiesKey : [
//                    AVVideoColorPrimariesKey : AVVideoColorPrimaries_ITU_R_709_2,
//                    AVVideoTransferFunctionKey :
//                    AVVideoTransferFunction_ITU_R_709_2,
//                    AVVideoYCbCrMatrixKey : AVVideoYCbCrMatrix_ITU_R_709_2
//                ],
//                AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill
//            ]
//
//            //Add video input
//            videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: settings)
            //            videoWriterInput.expectsMediaDataInRealTime = true //Make sure we are exporting data at realtime
            //videoWriterInput.transform = CGAffineTransform(rotationAngle: .pi/2)
            
            //            videoWriterInputPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: [
            //                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            //                kCVPixelBufferWidthKey as String: width!,
            //                kCVPixelBufferHeightKey as String: height!,
            //                kCVPixelFormatOpenGLESCompatibility as String: true,
            //            ])
            if videoWriter!.canAdd(videoWriterInput!) {
                videoWriter!.add(videoWriterInput!)
            }
            
            
            //  videoWriter.startWriting() //Means ready to write down the file
            
        } catch let error {
            debugPrint(error.localizedDescription)
        }
    }
    
    private func videoFileLocation() -> URL {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let videoOutputUrl = URL(fileURLWithPath: documentsPath.appendingPathComponent("videoFile")).appendingPathExtension("mov")
        do {
            if FileManager.default.fileExists(atPath: videoOutputUrl.path) {
                try FileManager.default.removeItem(at: videoOutputUrl)
            }
        } catch {
            print(error)
        }
        
        return videoOutputUrl
    }
}

extension AssetCombiner {
    
    func combine(json: [String: Any],
                 resolve: (() -> Void)? = nil,
                 reject: (() -> Void)? = nil) -> Void {
        combineQueue.sync {
            self.parseJson(json: json)
            self.createVideo()
        }
    }
    //    @objc(json:withResolver:withRejecter:)
    //    func combine(json: [String: Any],
    //                 resolve:RCTPromiseResolveBlock,
    //                 reject:RCTPromiseRejectBlock) -> Void {
    //        combineQueue.async {
    //            self.parseJson(json: json)
    //            self.createVideo()
    //        }
    //    }
}
