//
//  ViewController.swift
//  RNAssetCombinerTest
//
//  Created by Svyatoslav Ivanov on 18.08.2020.
//  Copyright © 2020 ARMA APP OU. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class ViewController: UIViewController {

    var assetCombiner = AssetCombiner()

    override func viewDidLoad() {
        super.viewDidLoad()
        let jsonUrl = Bundle.main.url(forResource: "test", withExtension: "json")

        guard let jsonData = try? NSData(contentsOf: jsonUrl!, options: NSData.ReadingOptions.uncached) as Data
        else { print("bad jsonData"); return }

        do {
            let JSON = try JSONSerialization.jsonObject(with: jsonData, options: [])
            guard let jsonArray = JSON as? [String: Any] else { print("bad jsonArray"); return }
            assetCombiner.combine(jsonArray as NSDictionary)
        } catch {
            print("try failed")
            return
        }
    }
}
