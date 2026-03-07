import SwiftUI

public struct CritiqueView: View {
    @ObservedObject var service: CloudCritiqueService
    var onDismiss: () -> Void
    
    public init(service: CloudCritiqueService, onDismiss: @escaping () -> Void) {
        self.service = service
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            // Provider Picker
            VStack {
                Picker("Provider", selection: $service.selectedProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                Divider().background(Color.white.opacity(0.1))
            }
            .background(BlurView(style: .systemThinMaterialDark))

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if service.isAnalyzing {
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("\(service.selectedProvider.rawValue) is analyzing your composition...")
                                .font(.system(size: 16, weight: .medium, design: .serif))
                                .italic()
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                    } else if service.currentKey.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 40))
                                .foregroundColor(providerColor(service.selectedProvider))
                            
                            Text("\(service.selectedProvider.rawValue) API Key Required")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                switch service.selectedProvider {
                                case .anthropic:
                                    SecureField("Enter Anthropic Key", text: $service.anthropicKey)
                                case .gemini:
                                    SecureField("Enter Gemini Key", text: $service.geminiKey)
                                case .openai:
                                    SecureField("Enter OpenAI Key", text: $service.openaiKey)
                                }
                            }
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                            
                            Text("Your key is only stored in memory for this session.")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .padding(.top, 50)
                    } else if let error = service.error {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.orange)
                            Text(error)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                    } else if let critique = service.critique {
                        CritiqueSection(title: "Technical", icon: "video.fill", content: critique.technical)
                        CritiqueSection(title: "Composition", icon: "rectangle.activeviewcenter", content: critique.composition)
                        CritiqueSection(title: "Creative", icon: "paintpalette.fill", content: critique.creative)
                        
                        Divider().background(Color.white.opacity(0.3))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("VERDICT")
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundColor(providerColor(service.selectedProvider))
                                Spacer()
                                Text(service.selectedProvider.rawValue)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            Text(critique.overall)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(16)
                    }
                }
                .padding()
            }
        }
        .background(Color.black.opacity(0.9))
        .cornerRadius(20)
        .shadow(radius: 20)
    }
    
    private func providerColor(_ provider: AIProvider) -> Color {
        switch provider {
        case .anthropic: return .yellow
        case .gemini: return .blue
        case .openai: return .green
        }
    }
}

struct CritiqueSection: View {
    var title: String
    var icon: String
    var content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title.uppercased())
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Text(content)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
    }
}
