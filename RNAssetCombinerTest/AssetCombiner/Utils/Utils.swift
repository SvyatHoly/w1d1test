import UIKit
import Foundation
import Photos

open class Utils {
    
    class func hexStringToUIColor (hex:String) -> UIColor {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }
        
        if ((cString.count) != 6) {
            return UIColor.white
        }
        
        var rgbValue:UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
    
    class func loadAssetFromLibrary(url: String, completion:@escaping (Any) -> Void) {
        let range = url.range(of: "(?<=id=).*(?=&)", options: .regularExpression)
        let id = url[range!.lowerBound..<range!.upperBound]
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [String(id)],
                                              options: nil).firstObject
        else {
            fatalError("No Asset found with identifier: \(url)")
        }
        
        if asset.mediaType == .image {
            let options = PHImageRequestOptions()
            options.resizeMode = .none
            options.deliveryMode = .highQualityFormat
            PHImageManager().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFill, options: options) { image, _ in
                if image == nil { print("fucking waiting") } else {
                    print("fck yeah")
                    completion(image!)
                }}}
        else if asset.mediaType == .video {
            PHImageManager().requestAVAsset(forVideo: asset, options: nil) { (avAsset, audioMix, userInfo) in
                guard let avAsset = avAsset else { fatalError("AVAsset is nil") }
                completion(avAsset)
            }
        }
    }
    
    class func getFont(from discriptor: String, size: Int) -> UIFont {
      var fontName: String = ""
      switch discriptor {
      case "bagnard": fontName = "MenoeGrotesquePro-Regular"
        break
      case "regular": fontName = "CoFo Sans"
        break
      case "serif": fontName = "Archaism-Ct2Wd50"
        break
      case "terminalGrotesque": fontName = "TransgenderGrotesk-Regular"
        break
      case "trickster": fontName = "Epos-Medium"
        break
      default:
        fontName = "CoFo Sans"
      }
      guard let result = UIFont(name: fontName, size: CGFloat(size)) else {
        return UIFont.systemFont(ofSize: CGFloat(size))}
      return result
    }
      
    class func heightForView(text: String, font: UIFont, width: CGFloat) -> CGFloat{
      let label:UILabel = UILabel(frame: CGRect(x: 0, y: 0, width: width, height: CGFloat.greatestFiniteMagnitude))
      label.lineBreakMode = NSLineBreakMode.byCharWrapping
      label.font = font
      label.text = text
      label.numberOfLines = 0
      label.sizeToFit()
      return label.frame.height
    }
}

