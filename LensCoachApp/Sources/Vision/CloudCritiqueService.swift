import Foundation
import UIKit

public struct CritiqueResponse: Codable {
    public let technical: String
    public let composition: String
    public let creative: String
    public let overall: String
}

public enum AIProvider: String, CaseIterable, Identifiable {
    case anthropic = "Anthropic"
    case gemini = "Gemini"
    case openai = "OpenAI"
    public var id: String { self.rawValue }
}

public class CloudCritiqueService: ObservableObject {
    @Published public var isAnalyzing = false
    @Published public var critique: CritiqueResponse?
    @Published public var error: String?
    @Published public var selectedProvider: AIProvider = .anthropic
    
    // Multi-key management
    @Published public var anthropicKey: String = ""
    @Published public var geminiKey: String = ""
    @Published public var openaiKey: String = ""
    
    public init() {}
    
    public var currentKey: String {
        switch selectedProvider {
        case .anthropic: return anthropicKey
        case .gemini: return geminiKey
        case .openai: return openaiKey
        }
    }
    
    public func analyzeImage(_ image: UIImage, scores: [String: Float]) {
        let key = currentKey
        guard !key.isEmpty else {
            self.error = "\(selectedProvider.rawValue) API Key missing."
            return
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            self.error = "Could not process image data."
            return
        }
        
        isAnalyzing = true
        error = nil
        
        // Context context
        let scoreContext = scores.map { "\($0.key): \(String(format: "%.2f", $0.value))" }.joined(separator: ", ")
        let prompt = """
        Analyze this photograph with an artistic eye. 
        On-device technical scores are: \(scoreContext).
        
        Provide a detailed critique in 4 categories:
        1. Technical (Focus, Exposure, Sharpness)
        2. Composition (Balance, Movement, Framing)
        3. Creative (Mood, Story, Color harmony)
        4. Overall (Final verdict)
        
        Keep each category concise but professional.
        """

        switch selectedProvider {
        case .anthropic:
            analyzeWithAnthropic(imageData: imageData, prompt: prompt, key: key)
        case .gemini:
            analyzeWithGemini(imageData: imageData, prompt: prompt, key: key)
        case .openai:
            analyzeWithOpenAI(imageData: imageData, prompt: prompt, key: key)
        }
    }
    
    private func analyzeWithAnthropic(imageData: Data, prompt: String, key: String) {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(key, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let parameters: [String: Any] = [
            "model": "claude-3-5-sonnet-20240620",
            "max_tokens": 1024,
            "messages": [
                ["role": "user", "content": [
                    ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": imageData.base64EncodedString()]],
                    ["type": "text", "text": prompt]
                ]]
            ]
        ]
        
        performRequest(request, parameters: parameters) { json in
            if let content = json["content"] as? [[String: Any]], let text = content.first?["text"] as? String {
                return text
            }
            return nil
        }
    }
    
    private func analyzeWithGemini(imageData: Data, prompt: String, key: String) {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(key)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": ["mime_type": "image/jpeg", "data": imageData.base64EncodedString()]]
                ]
            ]]
        ]
        
        performRequest(request, parameters: parameters) { json in
            if let candidates = json["candidates"] as? [[String: Any]],
               let first = candidates.first,
               let content = first["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                return text
            }
            return nil
        }
    }
    
    private func analyzeWithOpenAI(imageData: Data, prompt: String, key: String) {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        let parameters: [String: Any] = [
            "model": "gpt-4o",
            "max_tokens": 1024,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(imageData.base64EncodedString())"]]
                ]
            ]]
        ]
        
        performRequest(request, parameters: parameters) { json in
            if let choices = json["choices"] as? [[String: Any]],
               let first = choices.first,
               let message = first["message"] as? [String: Any],
               let text = message["content"] as? String {
                return text
            }
            return nil
        }
    }
    
    private func performRequest(_ request: URLRequest, parameters: [String: Any], parser: @escaping ([String: Any]) -> String?) {
        var mutableRequest = request
        do {
            mutableRequest.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            self.error = "Failed to encode request."
            self.isAnalyzing = false
            return
        }
        
        URLSession.shared.dataTask(with: mutableRequest) { data, response, error in
            DispatchQueue.main.async {
                self.isAnalyzing = false
                if let error = error {
                    self.error = error.localizedDescription
                    return
                }
                guard let data = data else {
                    self.error = "No data received."
                    return
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let text = parser(json) {
                    self.parseCritique(text)
                } else {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorObj = json["error"] as? [String: Any],
                       let message = errorObj["message"] as? String {
                        self.error = message
                    } else {
                        self.error = "Failed to parse AI response."
                    }
                }
            }
        }.resume()
    }
    
    private func parseCritique(_ text: String) {
        let sections = text.components(separatedBy: "\n\n")
        var technical = "N/A"
        var composition = "N/A"
        var creative = "N/A"
        var overall = "N/A"
        
        for section in sections {
            if section.localizedCaseInsensitiveContains("Technical") { technical = section }
            else if section.localizedCaseInsensitiveContains("Composition") { composition = section }
            else if section.localizedCaseInsensitiveContains("Creative") { creative = section }
            else if section.localizedCaseInsensitiveContains("Overall") { overall = section }
        }
        
        self.critique = CritiqueResponse(
            technical: technical,
            composition: composition,
            creative: creative,
            overall: overall
        )
    }
}
