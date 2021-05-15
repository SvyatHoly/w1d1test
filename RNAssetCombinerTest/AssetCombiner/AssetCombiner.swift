import Foundation
import AVFoundation
import Photos
import UIKit



enum AssetType {
    case photo
    case video
}

struct CombinerData {
    var asset: AVAsset
    var style: Styles
    var type: AssetType
    var orientation: String
}


typealias MixerThrowsCallback = () throws -> URL
typealias CombinerThrowsCallback = () throws -> [Asset]

@objc(AssetCombiner)
class AssetCombiner: NSObject {
    
    static func moduleName() -> String! {
        return "AssetCombiner"
    }
    
    static func requiresMainQueueSetup() -> Bool {
        return false
    }
    
    private let assetCombinerQueue = DispatchQueue.init(label: "com.W1D1.AssetCombiner.AssetCombinerQueue")
    private var videoMixer: VideoMixerProtocol?
    private var imageMixer: PhotoMixerProtocol?
    private var videoGenerator: VideoGenerator?
    private var renderSettings: RenderSettings?
    private let semaphore = DispatchSemaphore(value: 0)
    private var wasError = false
    
    private func parseJson(json: [String: Any]) throws -> JSON {
        do {
            return try JSONDecoder().decode(JSON.self, from: JSONSerialization.data(withJSONObject: json))
        } catch {
            throw CombinerError.jsonDecoderError
        }
    }
    
    private func getImageAssets(from json: JSON) -> [Asset] {
        var imageAssets = [Asset]()
        let bg = genearateBackgroundAsset(hex: json.background.value)
        let labels = generateAssetsFrom(labels: json.labels)
        let stickers = generateAssetsFrom(stickers: json.stickers)
        imageAssets.append(bg)
        imageAssets.append(contentsOf: json.photos)
        imageAssets.append(contentsOf: labels)
        imageAssets.append(contentsOf: stickers)
        return imageAssets
    }
    
    private func generateCombinerDataArray(json: JSON) throws -> [CombinerData] {
        var assets = [Asset]()
        var photosCombinerData = [CombinerData]()
        var combinerData = [CombinerData]()
        
        let completion = { [weak self] (result: CombinerThrowsCallback) -> Void in
            guard let self = self else { return }
            self.semaphore.signal()
            do {
                let generatedPhotoAssets = try result()
                assets.append(contentsOf: generatedPhotoAssets)
            } catch {
                if !self.wasError {
                    self.wasError = true
                    print(error)
                }
            }
        }

        self.generateVideoAssetsFromImages(photos: getImageAssets(from: json), completion: completion)
        self.semaphore.wait()
        
        json.videos.forEach {
            if $0.active {
                var asset: AVAsset
                let orientation = $0.videoOrientation
                if $0.local.prefix(1) == "a" {
                    asset = getLibraryAsset(url: $0.local) as! AVAsset
                } else {
                    //          asset = AVAsset(url: URL(fileURLWithPath: $0.local))
                    asset = AVAsset(url: Bundle.main.url(forResource: $0.local, withExtension: "mp4")!)
                }
                let style = $0.styles
                combinerData.append(CombinerData(asset: asset, style: style, type: .video, orientation: orientation))
            }
        }
        
        assets.forEach {
            if $0.active {
                let asset = AVAsset(url: URL(string: $0.local)!)
                let style = $0.styles
                let orientation = $0.videoOrientation
                photosCombinerData.append(CombinerData(asset: asset, style: style, type: .photo, orientation: orientation))
            }
        }
        combinerData.append(contentsOf: photosCombinerData)
        guard !combinerData.isEmpty else {
            throw CombinerError.combinerDataIsEmpty
        }
        combinerData.sort { $0.style.zIndex > $1.style.zIndex }
        return combinerData
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
    
    private func generateAssetsFrom(stickers: [Sticker]) -> [Asset] {
      var result = [Asset]()
      stickers.enumerated().forEach { (index, sticker) in
        downloadImage(from: URL(string: sticker.uri)!, completion: { image in
          
          let tmpDirURL = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
          let imageUrl = tmpDirURL!.appendingPathComponent("sticker\(index)").appendingPathExtension("png")
          let data = image.pngData()
          do {
            try FileManager.default.removeItem(at: imageUrl)
          } catch {
            print("doesn't exist")
          }
          do {
            try data!.write(to: imageUrl)
          } catch {
            print("can't write image data")
          }
          
          let asset: Asset! = Asset(id: 0,
                                    uri: imageUrl.path,
                                    local: imageUrl.path,
                                    active: sticker.active,
                                    format: "photo",
                                    styles: sticker.styles,
                                    origURI: imageUrl.path,
                                    localWidth: sticker.localWidth,
                                    localHeight: sticker.localHeight,
                                    videoOrientation: "portrait")
          result.append(asset)
          if result.count == stickers.count {
            self.semaphore.signal()
          }
        })
        
      }
      
      if result.count == stickers.count {
        return result
      } else {
        self.semaphore.wait()
      }
      return result
    }
    
    private func downloadImage(from url: URL, completion: @escaping (_: UIImage) -> Void) {
      print("Download Started")
      func getData(from url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
        URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
      }
      getData(from: url) { data, response, error in
        guard let data = data, error == nil else { return }
        print(response?.suggestedFilename ?? url.lastPathComponent)
        print("Download Finished")
        return completion(UIImage(data: data)!)
      }
      
    }
    
    private func genearateBackgroundAsset(hex: String) -> Asset {
        let image = Utils.hexStringToUIColor(hex: hex).image(CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        let tmpDirURL = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let imageUrl = tmpDirURL!.appendingPathComponent("background").appendingPathExtension("png")
        let data = image.pngData()
        do {
            try FileManager.default.removeItem(at: imageUrl)
        } catch {
            print("doesn't exist")
        }
        do {
            try data!.write(to: imageUrl)
        } catch {
            print("can't write image data")
        }
        let transform: Transform = Transform(scale: 1, rotate: "0deg")
        let styles: Styles! = Styles(top: 0, stylesLeft: 0, zIndex: 0, transform: [transform, transform], position: "")
        let asset: Asset! = Asset(id: 0,
                                  uri: imageUrl.path,
                                  local: imageUrl.path,
                                  active: true,
                                  format: "",
                                  styles: styles,
                                  origURI: imageUrl.path,
                                  localWidth: Int(UIScreen.main.bounds.width),
                                  localHeight: Int(UIScreen.main.bounds.height),
                                  videoOrientation: "internal")
        return asset
    }
    
    private func generateAssetsFrom(labels: [Label]) -> [Asset] {
        return labels.enumerated().map { (index, label) in
            let image = renderImageFrom(text: label.message, styles: label.styles)
            let tmpDirURL = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let imageUrl = tmpDirURL!.appendingPathComponent("label\(index)").appendingPathExtension("png")
            let data = image!.pngData()
            do {
                try FileManager.default.removeItem(at: imageUrl)
            } catch {
                print("doesn't exist")
            }
            do {
                try data!.write(to: imageUrl)
            } catch {
                print("can't write image data")
            }
            let styles: Styles! = Styles(
                top: (label.styles.top - Double(UIScreen.main.bounds.height / 2) + Double(image!.size.height / 6)),
                stylesLeft: label.styles.stylesLeft + 40,
                zIndex: label.styles.zIndex,
                transform: label.styles.transform,
                position: "")
            let asset: Asset! = Asset(id: 0,
                                      uri: imageUrl.path,
                                      local: imageUrl.path,
                                      active: true,
                                      format: "",
                                      styles: styles,
                                      origURI: imageUrl.path,
                                      localWidth: Int(UIScreen.main.bounds.width),
                                      localHeight: Int(UIScreen.main.bounds.height),
                                      videoOrientation: "internalText")
            return asset
        }
    }
    
    private func renderImageFrom(text: String, styles: LabelStyles) -> UIImage? {
        let font = Utils.getFont(from: styles.fontFamily, size: styles.fontSize * 2)
        let width = UIScreen.main.bounds.width
        let height = Utils.heightForView(text: text, font: font, width: width * 0.8)
        let frame = CGRect(x: 0, y: 0, width: width * 0.8 * 2, height: height)
        let nameLabel = UILabel(frame: frame)
        nameLabel.textAlignment = styles.textAlign == "center" ? .center : .left
        nameLabel.backgroundColor = .clear
        nameLabel.textColor = Utils.hexStringToUIColor(hex: styles.color)
        nameLabel.font = font
        nameLabel.text = text
        nameLabel.numberOfLines = 0
        UIGraphicsBeginImageContext(CGSize(width: width * 1.05 * 2, height: height))
        if let currentContext = UIGraphicsGetCurrentContext() {
            nameLabel.layer.render(in: currentContext)
            let nameImage = UIGraphicsGetImageFromCurrentImageContext()
            return nameImage
        }
        return nil
    }
    
    private func generateVideoAssetsFromImages(photos: [Asset], completion: @escaping (CombinerThrowsCallback) -> Void) {
        guard let _renderSettings = renderSettings else {
            completion({ throw CombinerError.renderSettingsIsNil })
            return
        }
        videoGenerator = VideoGenerator(renderSettings: _renderSettings)
        videoGenerator!.render(assets: photos, completion: completion)
    }
    
    private func setupRenderSettings() {
        renderSettings = RenderSettings()
    }
}

extension AssetCombiner {
    
    private func finalCompletion(callback: MixerThrowsCallback) {
        do {
            let result = try callback()
            print("complete \(result)")
            
        } catch {
            if !self.wasError {
                self.wasError = true
                print(error)
            }
        }
    }
    
    @objc func combine(_ json: NSDictionary) -> Void {
        assetCombinerQueue.async { [weak self] in
            guard let self = self else { return }
            self.wasError = false
            self.setupRenderSettings()
            do {
                let swiftJSON = try self.parseJson(json: json as! [String : Any])
                if swiftJSON.videos.isEmpty {
                    self.imageMixer = ImageMixer(size: self.renderSettings!.size)
                    self.imageMixer!.compose(assets: self.getImageAssets(from: swiftJSON),
                                             complete: self.finalCompletion)
                } else {
                    let combinerData = try self.generateCombinerDataArray(json: swiftJSON)
                    self.videoMixer = VideoMixer(size: self.renderSettings!.size)
                    self.videoMixer!.compose(data: combinerData, complete: self.finalCompletion)
                }
            } catch {
                if !self.wasError {
                    self.wasError = true
                    print(error)
                }
            }
        }
    }
}

struct RenderSettings {
    
    var size: CGSize {
        let aspectRatio = UIScreen.main.bounds.height / UIScreen.main.bounds.width
        if aspectRatio > 2 {
//            return CGSize(width: 1180, height: 2560)
            return CGSize(width: 590, height: 1280)

        } else { return CGSize(width: 1080, height: 1920) }
    }

    var fps: Int32 = 2   // 2 frames per second
    var videoFilename = "render"
    var videoFilenameExt = "MOV"
    // Apple suggests a timescale of 600 because it's a multiple of standard video rates 24, 25, 30, 60 fps etc.
    var kTimescale: Int32 = 600
    
    
    var outputURL: URL {
        // Use the CachesDirectory so the rendered video file sticks around as long as we need it to.
        // Using the CachesDirectory ensures the file won't be included in a backup of the app.
        let fileManager = FileManager.default
        if let tmpDirURL = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            return tmpDirURL.appendingPathComponent(videoFilename).appendingPathExtension(videoFilenameExt)
        }
        fatalError("URLForDirectory() failed")
    }
}
