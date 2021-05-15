//
//  AssetWriter.swift
//  RNAssetCombinerTest
//
//  Created by Svyatoslav Ivanov on 07.10.2020.
//  Copyright © 2020 ARMA APP OU. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

class VideoWriter {
    
    var videoGeneratorData: CachedAsset
    let renderSettings: RenderSettings
    var completion: (GeneratorThrowsCallback) -> Void
    var videoWriter: AVAssetWriter!
    var videoWriterInput: AVAssetWriterInput!
    var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    var isReadyForData: Bool {
        return videoWriterInput?.isReadyForMoreMediaData ?? false
    }
    
    var renderWidth: Int
    var renderHeight: Int
    
    init(videoGeneratorData: CachedAsset,
         renderSettings: RenderSettings,
         completion: @escaping (GeneratorThrowsCallback) -> Void) {
        self.videoGeneratorData = videoGeneratorData
        self.renderSettings = renderSettings
        self.completion = completion
        
        let width = videoGeneratorData.image.size.width
        let height = videoGeneratorData.image.size.height
        let sumCurrent = width + height
        var multiplier: CGFloat
        
        switch sumCurrent {
        case 7056 ... 14112: multiplier = 0.5
          break
        case 14112 ... 100000: multiplier = 0.25
          break
        default: multiplier = 1
        }
        
        self.renderWidth = Int(videoGeneratorData.image.size.height * CGFloat(multiplier))
        self.renderHeight = Int(videoGeneratorData.image.size.width * CGFloat(multiplier))
        if videoGeneratorData.asset.videoOrientation == "internalText" {
          self.renderWidth = Int(CGFloat(videoGeneratorData.asset.localHeight) * 4)
          self.renderHeight = Int(CGFloat(videoGeneratorData.asset.localWidth) * 4)
        }
        print("renderWidth: \(renderWidth) ||| renderHeight: \(renderHeight)")
    }
    
    func start() {
        
        var outputURL: URL? {
            let fileManager = FileManager.default
            if let tmpDirURL = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
                return tmpDirURL.appendingPathComponent("render\(videoGeneratorData.id)").appendingPathExtension("MOV")
            }
            return nil
        }
        guard let _outputURL = outputURL else {
            self.completion ({ throw CombinerError.writerFailedToGetOutputUrl })
            return
        }
        videoGeneratorData.avAssetUrl = _outputURL
        
        removeFileAtURL(fileURL: _outputURL)
        
        var codecKey: AVVideoCodecType
        if AVAssetExportSession.allExportPresets().contains(AVAssetExportPresetHEVCHighestQuality) {
            codecKey = AVVideoCodecType.hevcWithAlpha
        } else {
            codecKey = AVVideoCodecType.h264
        }
        
        #if targetEnvironment(simulator)
        codecKey = AVVideoCodecType.h264
        #endif
        
        let avOutputSettings: [String: Any] = [
            AVVideoCodecKey: codecKey,
            AVVideoWidthKey: NSNumber(value: Float(self.renderWidth)),
            AVVideoHeightKey: NSNumber(value: Float(self.renderHeight))
        ]
        
        func createPixelBufferAdaptor() {
            let sourcePixelBufferAttributesDictionary = [
                kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: NSNumber(value: Float(self.renderWidth)),
                kCVPixelBufferHeightKey as String: NSNumber(value: Float(self.renderHeight))
            ]
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput,
                                                                      sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
        }
        
        func createAssetWriter(outputURL: URL) throws -> AVAssetWriter {
            guard let assetWriter = try? AVAssetWriter(outputURL: outputURL as URL, fileType: AVFileType.mov) else {
                throw CombinerError.writerAVAssetWriterFailed
            }
            
            guard assetWriter.canApply(outputSettings: avOutputSettings, forMediaType: AVMediaType.video) else {
                throw CombinerError.writerCanNotApplyOutputSettings
            }
            
            return assetWriter
        }
        do {
            videoWriter = try createAssetWriter(outputURL: _outputURL)
            videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: avOutputSettings)
            
            if videoWriter.canAdd(videoWriterInput) {
                videoWriter.add(videoWriterInput)
            }
            else {
                throw CombinerError.writerCanAddInputReturnedFalse
            }
            
            // The pixel buffer adaptor must be created before we start writing.
            createPixelBufferAdaptor()
            
            if videoWriter.startWriting() == false {
                print(videoWriter.error)
                throw CombinerError.writerStartWritingFailed
            }
            
            videoWriter.startSession(atSourceTime: CMTime.zero)
            
            if pixelBufferAdaptor.pixelBufferPool == nil {
                throw CombinerError.pixelBufferPoolNil
            }
            
            render()
        } catch {
            self.completion({ throw error })
        }
    }
    
    private func render() {
        
        if videoWriter == nil {
            self.completion({ throw CombinerError.writerRenderBeforeInit })
            return
        }
        
        let queue = DispatchQueue(__label: "mediaInputQueue", attr: nil)
        videoWriterInput.requestMediaDataWhenReady(on: queue) {
            do {
                let isFinished = try self.appendPixelBuffers()
                if isFinished {
                    self.videoWriterInput.markAsFinished()
                    self.videoWriter.finishWriting() {
                        DispatchQueue.main.async { [self] in
                            self.videoWriter = nil
                            self.videoWriterInput = nil
                            self.completion({ return (id: videoGeneratorData.id, url: videoGeneratorData.avAssetUrl!) })
                        }
                    }
                }
                else {
                    // Fall through. The closure will be called again when the writer is ready.
                }
            } catch {
                self.completion({ throw error })
            }
        }
    }
    
    private func pixelBufferFromImage(image: UIImage, pixelBufferPool: CVPixelBufferPool, size: CGSize) throws -> CVPixelBuffer {
        
        var pixelBufferOut: CVPixelBuffer?
        
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBufferOut)
        if status != kCVReturnSuccess {
            throw CombinerError.writerCVPixelBufferPoolCreatePixelBuffer
        }
        
        let pixelBuffer = pixelBufferOut!
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let data = CVPixelBufferGetBaseAddress(pixelBuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: data, width: Int(size.width), height: Int(size.height),
                                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        
        context!.clear(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        let horizontalRatio = size.width / image.size.width
        let verticalRatio = size.height / image.size.height
        let aspectRatio = min(horizontalRatio, verticalRatio) // ScaleAspectFit
        
        let newSize = CGSize(width: image.size.width * aspectRatio, height: image.size.height * aspectRatio)
        
        let x = newSize.width < size.width ? (size.width - newSize.width) / 2 : 0
        let y = newSize.height < size.height ? (size.height - newSize.height) / 2 : 0
        
        context?.draw(image.cgImage!, in: CGRect(x: x, y: y, width: newSize.width, height: newSize.height))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
    
    private func addImage(image: UIImage, withPresentationTime presentationTime: CMTime) throws -> Bool {
        if pixelBufferAdaptor == nil {
            throw CombinerError.writerRenderBeforeInit
        }
        do {
            let pixelBuffer = try pixelBufferFromImage(image: image, pixelBufferPool: pixelBufferAdaptor.pixelBufferPool!, size: CGSize(width: self.renderWidth, height: self.renderHeight))
            return pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        } catch {
            throw error
        }
    }
    
    private func removeFileAtURL(fileURL: URL) {
        try? FileManager.default.removeItem(atPath: fileURL.path)
    }
    
    // This is the callback function for render()
    private func appendPixelBuffers() throws -> Bool {
        
        let frameDuration = CMTimeMake(value: Int64(0), timescale: renderSettings.kTimescale)
        
        if self.isReadyForData == false {
            // Inform writer we have more buffers to write.
            return false
        }
        
        let rotatedImg = videoGeneratorData.image.rotate(radians: .pi / 180 * -90)
        do {
            _ = try addImage(image: rotatedImg!, withPresentationTime: frameDuration)
            // Inform writer all buffers have been written.
            return true
        } catch {
            throw error
        }
    }
}
