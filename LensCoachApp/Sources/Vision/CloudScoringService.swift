import Foundation
import UIKit

public class CloudScoringService: ObservableObject {
    @Published public var isScoring = false
    @Published public var lastAnonymizedFrame: UIImage?
    
    public init() {}
    
    public func fetchScores(for image: UIImage, provider: AIProvider, key: String, completion: @escaping ([String: Float]?) -> Void) {
        guard !key.isEmpty else { return }
        
        let prompt = """
        Analyze this photography frame and provide aesthetic scores from 0.0 to 1.0.
        Output ONLY a JSON object with these keys: 
        ["Score", "Balance", "Color", "Content", "DoF", "Light", "Blur", "Object", "Repetition", "RuleOfThirds", "Symmetry", "Vivid"]
        
        Example: {"Score": 0.85, "Balance": 0.7, ...}
        """
        
        isScoring = true
        
        PIIProcessor.shared.processImage(image) { anonymizedImage in
            DispatchQueue.main.async { self.lastAnonymizedFrame = anonymizedImage }
            
            guard let imageData = anonymizedImage.jpegData(compressionQuality: 0.5) else {
                DispatchQueue.main.async { self.isScoring = false }
                return
            }
            
            DispatchQueue.main.async {
                switch provider {
                case .anthropic:
                    self.requestAnthropic(imageData: imageData, prompt: prompt, key: key, completion: completion)
                case .gemini:
                    self.requestGemini(imageData: imageData, prompt: prompt, key: key, completion: completion)
                case .openai:
                    self.requestOpenAI(imageData: imageData, prompt: prompt, key: key, completion: completion)
                }
            }
        }
    }
    
    private func requestAnthropic(imageData: Data, prompt: String, key: String, completion: @escaping ([String: Float]?) -> Void) {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(key, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let parameters: [String: Any] = [
            "model": "claude-3-5-sonnet-20240620",
            "max_tokens": 200,
            "messages": [
                ["role": "user", "content": [
                    ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": imageData.base64EncodedString()]],
                    ["type": "text", "text": prompt]
                ]]
            ]
        ]
        
        executeRequest(request, parameters: parameters, completion: completion)
    }
    
    private func requestGemini(imageData: Data, prompt: String, key: String, completion: @escaping ([String: Float]?) -> Void) {
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
            ]],
            "generationConfig": ["response_mime_type": "application/json"]
        ]
        
        executeRequest(request, parameters: parameters, completion: completion)
    }
    
    private func requestOpenAI(imageData: Data, prompt: String, key: String, completion: @escaping ([String: Float]?) -> Void) {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        let parameters: [String: Any] = [
            "model": "gpt-4o-mini", // Using a fast, cheap model
            "response_format": ["type": "json_object"],
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(imageData.base64EncodedString())"]]
                ]
            ]]
        ]
        
        executeRequest(request, parameters: parameters, completion: completion)
    }
    
    private func executeRequest(_ request: URLRequest, parameters: [String: Any], completion: @escaping ([String: Float]?) -> Void) {
        var mutableRequest = request
        mutableRequest.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        URLSession.shared.dataTask(with: mutableRequest) { data, _, _ in
            DispatchQueue.main.async { self.isScoring = false }
            
            guard let data = data else {
                completion(nil)
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Extract text response based on provider and parse JSON from it
                let text = self.extractText(from: json)
                if let scores = self.parseJSONScores(text) {
                    completion(scores)
                    return
                }
            }
            completion(nil)
        }.resume()
    }
    
    private func extractText(from json: [String: Any]) -> String {
        // Anthropic
        if let content = json["content"] as? [[String: Any]], let text = content.first?["text"] as? String {
            return text
        }
        // Gemini
        if let candidates = json["candidates"] as? [[String: Any]], let first = candidates.first,
           let content = first["content"] as? [String: Any], let parts = content["parts"] as? [[String: Any]],
           let text = parts.first?["text"] as? String {
            return text
        }
        // OpenAI
        if let choices = json["choices"] as? [[String: Any]], let first = choices.first,
           let message = first["message"] as? [String: Any], let text = message["content"] as? String {
            return text
        }
        return ""
    }
    
    private func parseJSONScores(_ text: String) -> [String: Float]? {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleanedText.data(using: .utf8) else { return nil }
        
        do {
            let dict = try JSONDecoder().decode([String: Float].self, from: data)
            return dict
        } catch {
            // Fallback for markdown-wrapped JSON
            if let range = cleanedText.range(of: "\\{.*\\}", options: .regularExpression) {
                let sub = String(cleanedText[range])
                if let data2 = sub.data(using: .utf8),
                   let dict2 = try? JSONDecoder().decode([String: Float].self, from: data2) {
                    return dict2
                }
            }
            return nil
        }
    }
}
