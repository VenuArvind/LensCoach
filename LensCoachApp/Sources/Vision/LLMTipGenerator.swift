import Foundation
import Combine

public class LLMTipGenerator: ObservableObject {
    @Published public var currentTip: String = ""
    @Published public var tipHistory: [String] = []
    
    // Local Model Path
    private var modelPath: String? {
        Bundle.main.path(forResource: "Phi-3-mini-4k-instruct-q4", ofType: "gguf") ??
        Bundle.module.path(forResource: "Phi-3-mini-4k-instruct-q4", ofType: "gguf")
    }
    
    // Rate limiting: 1 tip per 5 seconds
    private var lastTipTime: Date = .distantPast
    private let tipInterval: TimeInterval = 2.5
    
    // Prompt Template (from LensCoach.md)
    private let promptTemplate = """
    Camera viewfinder scores:
    %@
    The weakest area is %s.
    Give one short, specific tip to improve this shot.
    """
    
    // This would be replaced by the actual llama.cpp interface
    // private var model: LlamaModel?
    
    public init() {}
    
    public func generateTipIfNeeded(scores: [String: Float]) {
        let now = Date()
        guard now.timeIntervalSince(lastTipTime) >= tipInterval else { return }
        
        // Identify the weakest attribute
        guard let weakest = scores.min(by: { $0.value < $1.value }) else { return }
        
        // Format the scores for the prompt
        // let scoreString = scores.map { "\($0.key): \(String(format: "%.2f", $0.value))" }.joined(separator: ", ")
        // let prompt = String(format: "Camera viewfinder scores: %@. The weakest area is %@. Give one short, specific tip to improve this shot.", scoreString, weakest.key)
        
        // In a real implementation:
        // Task {
        //    let tip = await model?.generate(prompt: prompt, maxTokens: 20)
        //    updateTip(tip)
        // }
        
        // For now, let's trigger a conceptual tip so we can build the UI
        self.lastTipTime = now
        self.processTipGeneration(weakest: weakest.key)
    }
    
    private func processTipGeneration(weakest: String) {
        // Mock tips for UI verification while llama.cpp is being wired
        let mockTips: [String: String] = [
            "RuleOfThirds": "Try placing your subject along one of the grid lines for a more balanced shot.",
            "Symmetry": "Center your subject exactly to emphasize the symmetrical patterns.",
            "Light": "Move closer to a light source or wait for the light to hit the subject directly.",
            "Color": "Look for contrasting colors to make the subject pop against the background.",
            "Balance": "Adjust your framing to avoid leaving too much empty space on one side.",
            "Blur": "Hold the camera steady or increase your shutter speed to capture sharp detail.",
            "DoF": "Get closer to your subject to create a more pleasing blurred background."
        ]
        
        let tip = mockTips[weakest] ?? "Keep experimenting with your composition!"
        
        DispatchQueue.main.async {
            self.currentTip = tip
            self.tipHistory.insert(tip, at: 0)
            if self.tipHistory.count > 5 {
                self.tipHistory.removeLast()
            }
        }
    }
}
