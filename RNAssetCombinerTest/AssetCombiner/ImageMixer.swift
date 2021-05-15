//
//  ImageMixer.swift
//  RNAssetCombinerTest
//
//  Created by Svyatoslav Ivanov on 03.02.2021.
//  Copyright © 2021 ARMA APP OU. All rights reserved.
//

import AVFoundation
import UIKit
import Photos

final class ImageMixer: PhotoMixerProtocol {
    
    private var size: CGSize
    
    init(size: CGSize) {
        self.size = size
    }
    
    func compose(assets: [Asset], complete: @escaping (MixerThrowsCallback) -> Void) {
        var image: UIImage?
        do {
            let cacher = ImageCacher()
            let cachedAssets = try cacher.cache(assets: assets)
            
            for element in cachedAssets {
                UIGraphicsBeginImageContext(size)
                if let currentContext = UIGraphicsGetCurrentContext() {
                    image?.draw(at: CGPoint(x: 0, y: 0))
                    let transformer = AffineTransformer()
                    let transform = transformer.createTransform(
                        size: size,
                        width: CGFloat(element.asset.localWidth),
                        height: CGFloat(element.asset.localHeight),
                        styles: element.asset.styles,
                        orientation: element.asset.videoOrientation)
                    
                    currentContext.concatenate(_: transform)
                    
                    element.image.draw(at: CGPoint(x: 0, y: 0))
                    
                    image = UIGraphicsGetImageFromCurrentImageContext()!
                } else {
                    complete({ throw CombinerError.graphicContextError })
                }
            }
            
            let url = saveImage(image: image!)
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
            }) { (succes, error) in
                if succes {
                    print("saved")
                } else {
                    print(error)
                }
            }
            complete({return url})
        } catch {
            complete({ throw CombinerError.graphicContextError })
        }
    }
    
    private func saveImage(image: UIImage) -> URL {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { fatalError() }
        
        let fileURL = documentsDirectory.appendingPathComponent("imageExported")
        guard let data = image.jpegData(compressionQuality: 1) else { fatalError() }
        
        //Checks if file exists, removes it if so.
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(atPath: fileURL.path)
                print("Removed old image")
            } catch let removeError {
                print("couldn't remove file at path", removeError)
            }
        }
        
        do {
            try data.write(to: fileURL)
        } catch let error {
            print("error saving file with error", error)
        }
        return fileURL
    }
}
