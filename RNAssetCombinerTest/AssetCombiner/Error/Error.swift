//
//  Error.swift
//  RNAssetCombinerTest
//
//  Created by Svyatoslav Ivanov on 19.02.2021.
//  Copyright © 2021 ARMA APP OU. All rights reserved.
//

import Foundation

enum CombinerError: Error {
    case jsonDecoderError
    case renderSettingsIsNil
    case combinerDataIsEmpty
    case writerFailedToGetOutputUrl
    case writerRenderBeforeInit
    case writerCVPixelBufferPoolCreatePixelBuffer
    case writerAVAssetWriterFailed
    case writerCanAddInputReturnedFalse
    case writerCanNotApplyOutputSettings
    case writerStartWritingFailed
    case pixelBufferPoolNil
    case generatorFailedGetImageFromAsset
    case mixerFailedToLoadTrack
    case mixerEmptyTrackArray
    case graphicContextError
}
