//
//  ImageCacher.swift
//  RNAssetCombinerTest
//
//  Created by Svyatoslav Ivanov on 19.02.2021.
//  Copyright © 2021 ARMA APP OU. All rights reserved.
//

import Foundation
import UIKit

struct CachedAsset {
    var id: Int
    var asset: Asset
    var image: UIImage
    var avAssetUrl: URL?
}

struct ImageCacher {
    private let semaphore = DispatchSemaphore(value: 0)
    
    func cache(assets: [Asset]) throws -> [CachedAsset] {
        do {
            let result = try assets.enumerated().map { (index, asset) -> CachedAsset in
                var image: UIImage?
                if asset.local.prefix(1) == "a" {
                    image = getLibraryAsset(url: asset.local) as? UIImage
                } else {
                    if asset.id == 0 {
                        image = UIImage(contentsOfFile: asset.local)
                    } else {
                        image = UIImage(contentsOfFile: Bundle.main.url(forResource: asset.local, withExtension: "HEIC")!.path)
                        //                        image = UIImage(contentsOfFile: asset.local)
                    }
                }
                guard let _image = image else {
                    throw CombinerError.generatorFailedGetImageFromAsset
                }
                
                return CachedAsset(id: index, asset: asset, image: _image)
            }
            return result
        } catch {
            throw error
        }
    }
    
    private func getLibraryAsset(url: String) -> Any {
        var asset: Any? = nil
        let completion = { (assetReturning: Any) in
            asset = assetReturning
            self.semaphore.signal()
        }
        Utils.loadAssetFromLibrary(url: url, completion: completion)
        self.semaphore.wait()
        return asset!
    }
}
