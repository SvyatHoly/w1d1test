//
//  MixerProtocol.swift
//  RNAssetCombinerTest
//
//  Created by Svyatoslav Ivanov on 03.02.2021.
//  Copyright © 2021 ARMA APP OU. All rights reserved.
//

import Foundation

protocol VideoMixerProtocol {
    func compose(data: [CombinerData], complete: @escaping (MixerThrowsCallback) -> Void)
}

protocol PhotoMixerProtocol {
    func compose(assets: [Asset], complete: @escaping (MixerThrowsCallback) -> Void)
}
