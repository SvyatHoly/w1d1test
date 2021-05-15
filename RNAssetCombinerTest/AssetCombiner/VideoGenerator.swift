//
//  ImageAnimator.swift
//  RNAssetCombinerTest
//
//  Created by Svyatoslav Ivanov on 07.10.2020.
//  Copyright © 2020 ARMA APP OU. All rights reserved.
//

import Foundation
import UIKit
import Photos


typealias GeneratorThrowsCallback = () throws -> (id: Int, url: URL)

class VideoGenerator {
    
    private let imageQueue = DispatchQueue(label: "com.W1D1.AssetCombiner.VideoGeneratorQueue")
    private let concurrentQueue = DispatchQueue(label: "com.W1D1.AssetCombiner.VideoGeneratorConcurrentQueue", qos: .userInteractive, attributes: .init(), autoreleaseFrequency: .workItem, target: nil)
    private let settings: RenderSettings
    private var videoWriter: VideoWriter?
    private var images: [UIImage]!
    private let semaphore = DispatchSemaphore(value: 0)
    private var completionCounter = 0
    private var videoGeneratorData = [CachedAsset]()
    private var completion: ((GeneratorThrowsCallback) -> Void)?
    private var wasError = false
    init(renderSettings: RenderSettings) {
        settings = renderSettings
    }
    
    func render(assets: [Asset], completion: @escaping (CombinerThrowsCallback) -> Void) {
        imageQueue.sync {
            self.completion = { [self] (result: GeneratorThrowsCallback) -> Void in
                do {
                    print("result")
                    let tuple = try result()
                    let index = videoGeneratorData.firstIndex { $0.id == tuple.id}
                    videoGeneratorData[index!].avAssetUrl = tuple.url
                    completionCounter += 1
                    if completionCounter == videoGeneratorData.count {
                        returnAssetsWithUrl(finalComletion: completion)
                    } else {
                        startRender(at: self.completionCounter)
                    }
                } catch {
                    if !wasError {
                        wasError = true
                        completion({ throw error })
                    }
                    return
                }
            }
            imageQueue.async { [self] in
                do {
                    let cacher = ImageCacher()
                    videoGeneratorData = try cacher.cache(assets: assets)
                } catch {
                    if !wasError {
                        wasError = true
                        completion({ throw error })
                    }
                    return
                }
                startRender(at: self.completionCounter)
            }
        }
    }
    
    private func startRender(at index: Int) {
            concurrentQueue.async {
                let videoWriter = VideoWriter(
                    videoGeneratorData: self.videoGeneratorData[index],
                    renderSettings: self.settings,
                    completion: self.completion!)
                videoWriter.start()
            }
    }
    
    private func returnAssetsWithUrl(finalComletion: (CombinerThrowsCallback) -> Void) {
        let result = self.videoGeneratorData.map { (element: CachedAsset) -> Asset in
            var asset = element.asset
            asset.local = element.avAssetUrl!.absoluteString
            saveToLibrary(videoURL: element.avAssetUrl!)
            asset.videoOrientation = "internal"
            return asset
        }
        finalComletion({ return result })
    }

    
    
    private func resizeImage(image: UIImage) -> UIImage {
      let width = image.size.width
      let height = image.size.height
      let sumCurrent = width + height
      var multiplier: CGFloat
      
      switch sumCurrent {
      case 7056 ... 14112: multiplier = 0.5
        break
      case 14112 ... 100000: multiplier = 0.25
        break
      default: multiplier = 1
      }
      
      if (multiplier == 1) {
        return image
      }

      let targetSize = CGSize(width: image.size.width * multiplier, height: image.size.height * multiplier)
      let size = image.size

       let widthRatio  = targetSize.width  / size.width
       let heightRatio = targetSize.height / size.height

       // Figure out what our orientation is, and use that to form the rectangle
       var newSize: CGSize
       if(widthRatio > heightRatio) {
           newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
       } else {
           newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
       }
      print("newSize \(newSize.width) \(newSize.height)")
       // This is the rect that we've calculated out and this is what is actually used below
       let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

       // Actually do the resizing to the rect using the ImageContext stuff
       UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
       image.draw(in: rect)
       let newImage = UIGraphicsGetImageFromCurrentImageContext()
       UIGraphicsEndImageContext()

       return newImage!
   }

    
    private func saveToLibrary(videoURL: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else { return }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL as URL)
            }) { success, error in
                if !success {
                    print("Could not save video to photo library:", error as Any)
                } else {
                    print("saved to library")
                }
            }
        }
    }
}
