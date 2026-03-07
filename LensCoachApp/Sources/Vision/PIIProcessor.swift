import Foundation
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

public class PIIProcessor {
    public static let shared = PIIProcessor()
    private let context = CIContext()
    
    private init() {}
    
    
    public func processImage(_ image: UIImage, redactFaces: Bool = true, completion: @escaping (UIImage) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(image)
            return
        }
        
        // 1. Properly orient the CIImage FIRST
        let cgOrientation = CGImagePropertyOrientation(image.imageOrientation)
        var ciImage = CIImage(cgImage: cgImage).oriented(cgOrientation)
        
        if redactFaces {
            // 2. Detect and redact on the correctly oriented image (now always .up)
            detectAndRedactFaces(in: ciImage) { redactedCIImage in
                let outputImage = self.renderCIImage(redactedCIImage)
                completion(outputImage)
            }
        } else {
            let outputImage = renderCIImage(ciImage)
            completion(outputImage)
        }
    }
    
    private func detectAndRedactFaces(in image: CIImage, completion: @escaping (CIImage) -> Void) {
        // Oriented to .up already, so handler doesn't need orientation
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        let request = VNDetectFaceRectanglesRequest { request, error in
            guard let observations = request.results as? [VNFaceObservation], !observations.isEmpty else {
                completion(image)
                return
            }
            
            var currentImage = image
            let size = image.extent.size
            
            for observation in observations {
                // Vision is normalized 0-1 (bottom-left)
                let box = observation.boundingBox
                
                // Pad the box 20% to ensure full head coverage
                let padding: CGFloat = 0.2
                let paddedBox = box.insetBy(dx: -box.width * padding, dy: -box.height * padding)
                
                let rect = CGRect(
                    x: paddedBox.origin.x * size.width,
                    y: paddedBox.origin.y * size.height,
                    width: paddedBox.size.width * size.width,
                    height: paddedBox.size.height * size.height
                ).intersection(image.extent)
                
                // Heavy blur for privacy
                let blurFilter = CIFilter.gaussianBlur()
                blurFilter.inputImage = currentImage.clampedToExtent()
                blurFilter.radius = Float(min(rect.width, rect.height) * 0.2)
                
                guard let blurredImage = blurFilter.outputImage?.cropped(to: image.extent) else { continue }
                
                // Create a clean mask (white rectangle on black background)
                let maskImage = CIImage(color: .white)
                    .cropped(to: rect)
                    .composited(over: CIImage(color: .black).cropped(to: image.extent))
                
                let blendFilter = CIFilter.blendWithMask()
                blendFilter.inputImage = blurredImage
                blendFilter.backgroundImage = currentImage
                blendFilter.maskImage = maskImage
                
                if let combined = blendFilter.outputImage {
                    currentImage = combined.cropped(to: image.extent)
                }
            }
            
            completion(currentImage)
        }
        
        do {
            try handler.perform([request])
        } catch {
            completion(image)
        }
    }
    
    private func renderCIImage(_ ciImage: CIImage) -> UIImage {
        // Orientation is already baked into the ciImage pixels now
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return UIImage(ciImage: ciImage)
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
