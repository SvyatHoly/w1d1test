//
//  AffineTransformer.swift
//  RNAssetCombinerTest
//
//  Created by Svyatoslav Ivanov on 19.02.2021.
//  Copyright © 2021 ARMA APP OU. All rights reserved.
//

import Foundation
import UIKit

struct AffineTransformer {
    
    func createTransform(size: CGSize, width: CGFloat, height: CGFloat, styles: Styles, orientation: String)
    -> CGAffineTransform {

        var orientationChecked = orientation
        if orientation == "portrait"  && width < height {
            orientationChecked = "landscape"
        }
        let screenSize: CGRect = UIScreen.main.bounds
//        let screenSize: CGRect = CGRect(x: 0, y: 0, width: 800, height: 1408)
        var transform = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
        let string = styles.transform[1].rotate!
        let degrees = CGFloat(Float(string.dropLast(3))!)
        let scale = CGFloat(styles.transform[0].scale!)
        
        let multiplierY: CGFloat = CGFloat(size.height) / screenSize.height
        
        var transX = CGFloat(CGFloat(styles.stylesLeft) * multiplierY)
        var transY = CGFloat(CGFloat(styles.top) * multiplierY)
        
        var heightDifference: CGFloat = CGFloat(size.height) / CGFloat(width)

        if orientationChecked == "landscape" {
            transX = CGFloat(CGFloat(styles.top) * multiplierY)
            transY = CGFloat(CGFloat(styles.stylesLeft) * multiplierY)

            heightDifference = CGFloat(size.height) / CGFloat(height)
        } else {
            // initial rotate 90 degrees
            transform = transform.concatenating(CGAffineTransform(rotationAngle: CGFloat( CGFloat.pi / 180 * 90)))

            // translate assets to Top 0 Left 0
            transform = transform.concatenating(CGAffineTransform(translationX: height, y: 0))
        }

        // init scale assets into export frame height
        transform = transform.concatenating(CGAffineTransform(scaleX: heightDifference, y: heightDifference))
        
        if orientationChecked == "landscape" {
            transform = transform.concatenating(CGAffineTransform(translationX: transY, y: transX))

        } else {
            transform = transform.concatenating(CGAffineTransform(translationX: transX, y: transY))
        }
        
        // set style translate

        // set style scale
        transform = transform.concatenating(CGAffineTransform(scaleX: scale, y:  scale))

        var centerY: CGFloat
        var centerX: CGFloat
        if orientationChecked == "landscape" {
            // translate after scale
            let actualWidthAfterInitScale = height * heightDifference
            let actualHeightAfterInitScale = width * heightDifference
            centerY = actualWidthAfterInitScale / 2 + transX
            centerX = actualHeightAfterInitScale / 2 + transY

            let scaledToCenterX = centerX - (actualHeightAfterInitScale * scale / 2)
            let scaledToCenterY = centerY - (actualWidthAfterInitScale * scale / 2)
            let scaledToZeroX = transX * scale
            let scaledToZeroY = transY * scale
            let newTransOffsetX = scaledToCenterX - scaledToZeroY
            let newTransOffsetY = scaledToCenterY - scaledToZeroX

            transform = transform.concatenating(CGAffineTransform(translationX: newTransOffsetX, y: newTransOffsetY))
        } else {
            // translate after scale
            let actualWidthAfterInitScale = width * heightDifference
            let actualHeightAfterInitScale = height * heightDifference
            centerY = actualWidthAfterInitScale / 2 + transY
            centerX = actualHeightAfterInitScale / 2 + transX

            let scaledToCenterX = centerX - (actualHeightAfterInitScale * scale / 2)
            let scaledToCenterY = centerY - (actualWidthAfterInitScale * scale / 2)
            let scaledToZeroX = transX * scale
            let scaledToZeroY = transY * scale
            let newTransOffsetX = scaledToCenterX - scaledToZeroX
            let newTransOffsetY = scaledToCenterY - scaledToZeroY

            transform = transform.concatenating(CGAffineTransform(translationX: newTransOffsetX, y: newTransOffsetY))
        }

        // set style rotate
        let a = CGFloat( CGFloat.pi / 180 * degrees)
        let x: CGFloat = centerX
        let y: CGFloat = centerY
        let trans = CGAffineTransform(
            a: cos(a),
            b: sin(a),
            c: -sin(a),
            d: cos(a),
            tx: CGFloat(x - x * cos(a) + y * sin(a)),
            ty: CGFloat(y - x * sin(a) - y * cos(a)))
        transform = transform.concatenating(trans)

        return transform
    }
}
