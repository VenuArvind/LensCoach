import Foundation
import CoreML
import Vision
import CoreImage

public class AestheticAnalyzer: ObservableObject {
    @Published public var aestheticScore: Float = 0.0
    @Published public var smoothedAttributes: [String: Float] = [:]
    
    private var model: VNCoreMLModel?
    private var alpha: Float = 0.3 // EMA smoothing factor
    private var lastScores: [Float] = Array(repeating: 0.0, count: 12)
    
    public let attributeNames = [
        "Score", "Balance", "Color", "Content", "DoF", 
        "Light", "Blur", "Object", "Repetition", "RuleOfThirds", 
        "Symmetry", "Vivid"
    ]
    
    public init() {
        setupModel()
    }
    
    private func setupModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all 
            
            // Try to find the model in the bundle
            guard let modelURL = Bundle.main.url(forResource: "FrameScore", withExtension: "mlmodelc") ??
                                Bundle.module.url(forResource: "FrameScore", withExtension: "mlmodelc") else {
                print("Could not find FrameScore model in bundle")
                return
            }
            
            let coreMLModel = try MLModel(contentsOf: modelURL, configuration: config)
            self.model = try VNCoreMLModel(for: coreMLModel)
        } catch {
            print("Error loading CoreML model: \(error)")
        }
    }
    
    func analyze(pixelBuffer: CVPixelBuffer) {
        guard let model = model else { return }
        
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            guard let self = self,
                  let results = request.results as? [VNCoreMLFeatureValueObservation],
                  let multiArray = results.first?.featureValue.multiArrayValue else { return }
            
            self.processResults(multiArray)
        }
        
        request.imageCropAndScaleOption = .centerCrop
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Vision request failed: \(error)")
        }
    }
    
    private func processResults(_ multiArray: MLMultiArray) {
        // We know we have 12 outputs
        var currentScores = [Float]()
        for i in 0..<12 {
            currentScores.append(multiArray[i].floatValue)
        }
        
        // Apply EMA Smoothing: smoothed = alpha * new + (1 - alpha) * old
        var newSmoothed = [Float]()
        for i in 0..<12 {
            let smoothed = (alpha * currentScores[i]) + ((1.0 - alpha) * lastScores[i])
            newSmoothed.append(smoothed)
            lastScores[i] = smoothed
        }
        
        DispatchQueue.main.async {
            self.aestheticScore = newSmoothed[0] // Overall score is index 0
            
            var attrMap: [String: Float] = [:]
            for i in 1..<12 {
                attrMap[self.attributeNames[i]] = newSmoothed[i]
            }
            self.smoothedAttributes = attrMap
        }
    }
    
    public func updateScores(from externalScores: [String: Float]) {
        DispatchQueue.main.async {
            if let score = externalScores["Score"] {
                self.aestheticScore = score
            }
            // Update smoothed attributes with filtered keys
            var updated = self.smoothedAttributes
            for (key, val) in externalScores where key != "Score" {
                updated[key] = val
            }
            self.smoothedAttributes = updated
            
            // Sync internal lastScores to prevent jumps on transition
            for i in 0..<12 {
                let name = self.attributeNames[i]
                if let val = externalScores[name] {
                    self.lastScores[i] = val
                }
            }
        }
    }
    
    public func resetSmoother() {
        self.lastScores = Array(repeating: 0.0, count: 12)
    }
}
