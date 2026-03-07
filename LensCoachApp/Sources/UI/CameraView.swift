import SwiftUI
import AVFoundation

public struct CameraPreview: UIViewRepresentable {
    @ObservedObject public var cameraManager: CameraManager
    
    public init(cameraManager: CameraManager) {
        self.cameraManager = cameraManager
    }
    
    public func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Final Rule of Thirds Grid
        let gridLayer = CAShapeLayer()
        gridLayer.strokeColor = UIColor.white.withAlphaComponent(0.4).cgColor
        gridLayer.lineWidth = 1.0
        view.layer.addSublayer(gridLayer)
        
        context.coordinator.previewLayer = previewLayer
        context.coordinator.gridLayer = gridLayer
        
        return view
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
        context.coordinator.updateGrid(in: uiView.bounds)
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public class Coordinator: NSObject {
        var previewLayer: AVCaptureVideoPreviewLayer?
        var gridLayer: CAShapeLayer?
        
        func updateGrid(in rect: CGRect) {
            guard let gridLayer = gridLayer else { return }
            let path = UIBezierPath()
            
            // Vertical lines
            for i in 1...2 {
                let x = rect.width * CGFloat(i) / 3.0
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: rect.height))
            }
            
            // Horizontal lines
            for i in 1...2 {
                let y = rect.height * CGFloat(i) / 3.0
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: rect.width, y: y))
            }
            
            gridLayer.path = path.cgPath
        }
    }
}

public struct CameraView: View {
    @StateObject public var cameraManager = CameraManager()
    @StateObject public var cloudService = CloudCritiqueService()
    @State private var showCritique = false
    @State private var showGallery = false
    @State private var selectionRequired = true
    
    public init() {}
    
    public var weakestAttributes: [(String, Float)] {
        cameraManager.aestheticAnalyzer.smoothedAttributes
            .sorted { $0.value < $1.value }
            .prefix(3)
            .map { ($0.key, $0.value) }
    }
    
    public var body: some View {
        ZStack {
            // Camera Preview
            if let frame = cameraManager.currentFrame {
                // NOTE: The CameraPreview struct's initializer needs to be updated to accept pixelBuffer
                // For now, keeping the original CameraPreview(cameraManager:) to avoid compilation errors
                // as the instruction only provided CameraView changes.
                // If CameraPreview was updated to take pixelBuffer, this would be:
                // CameraPreview(pixelBuffer: frame)
                CameraPreview(cameraManager: cameraManager)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        if !selectionRequired {
                            cameraManager.start()
                        }
                    }
            } else {
                Color.black.edgesIgnoringSafeArea(.all)
            }
            
            // Initial Mode Selection Overlay
            if selectionRequired {
                ZStack {
                    Color.black.opacity(0.85).edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 30) {
                        Image(systemName: "camera.aperture")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                        
                        Text("Choose Your Lens Engine")
                            .font(.system(size: 26, weight: .black))
                            .foregroundColor(.white)
                        
                        Text("How should LensCoach see the world?")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                        
                        VStack(spacing: 16) {
                            Button(action: {
                                cameraManager.scoringMode = .local
                                selectionRequired = false
                                cameraManager.start()
                            }) {
                                ModeButtonView(
                                    title: "LOCAL COREML",
                                    subtitle: "15fps / Instant / Battery Efficient",
                                    icon: "cpu.fill",
                                    color: .green
                                )
                            }
                            
                            Button(action: {
                                cameraManager.scoringMode = .cloud
                                selectionRequired = false
                                cameraManager.start()
                            }) {
                                ModeButtonView(
                                    title: "CLOUD AI",
                                    subtitle: "5s / Deep Reasoning / LLM Analysis",
                                    icon: "cloud.fill",
                                    color: .blue
                                )
                            }
                        }
                        .padding(.horizontal, 30)
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
            
            // HUD and Controls
            VStack(spacing: 0) {
                // Top HUD
                VStack(spacing: 8) {
                    HStack {
                        // Scoring Mode Toggle
                        Picker("Scoring", selection: $cameraManager.scoringMode) {
                            Text("COREML").tag(ScoringMode.local)
                            Text("CLOUD").tag(ScoringMode.cloud)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 160)
                        
                        Spacer()
                        
                        // Gallery Button
                        Button(action: { showGallery = true }) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(BlurView(style: .systemThinMaterialDark).clipShape(Circle()))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 50)
                    
                    if cameraManager.scoringMode == .cloud && cameraManager.cloudScoringService.isScoring {
                        Text("Cloud AI is reasoning...")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue.opacity(0.8))
                            .padding(.top, 2)
                            .transition(.opacity)
                    }
                }
                
                // Score Ring & Pro Tip
                HStack(alignment: .top) {
                    ScoreRing(score: cameraManager.aestheticAnalyzer.aestheticScore)
                        .padding(.leading, 20)
                    
                    Spacer()
                }
                .padding(.top, 16)
                
                // Tip Card (New for Phase 4)
                if !cameraManager.tipGenerator.currentTip.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text("PRO TIP")
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(.yellow)
                        }
                        
                        Text(cameraManager.tipGenerator.currentTip)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BlurView(style: .systemThinMaterialDark).cornerRadius(16))
                    .padding(.horizontal)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .id(cameraManager.tipGenerator.currentTip) // Force refresh animation on tip change
                }
                
                Spacer()
                
                // Bottom Overlay for weakest scores (Coaching)
                if cameraManager.aestheticAnalyzer.aestheticScore > 0 {
                    HStack {
                        ForEach(weakestAttributes, id: \.0) { attr, score in
                            VStack(spacing: 4) {
                                Text(attr)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Capsule()
                                    .fill(scoreColor(score).opacity(0.6))
                                    .frame(width: 80, height: 24)
                                    .overlay(
                                        Text(String(format: "%.1f", score))
                                            .foregroundColor(.white)
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    )
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 30)
                }
                
                // Capture Button
                Button(action: {
                    cameraManager.capturePhoto()
                }) {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 76, height: 76)
                        .overlay(Circle().fill(Color.white).scaleEffect(0.85))
                }
                .padding(.bottom, 40)
            }
            
            // Photo Review Overlay
            if let capturedImage = cameraManager.capturedImage {
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    Image(uiImage: capturedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(20)
                        .padding()
                    
                    VStack {
                        HStack {
                            Button(action: {
                                cameraManager.capturedImage = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.top, 50)
                            .padding(.leading, 20)
                            
                            Spacer()
                        }
                        
                        Spacer()
                        
                        // Cloud Critique Button
                        Button(action: {
                            if cloudService.currentKey.isEmpty {
                                // Show API Key input or notify user
                                cloudService.error = "Please provide your \(cloudService.selectedProvider.rawValue) API Key."
                            }
                            cloudService.analyzeImage(capturedImage, scores: cameraManager.aestheticAnalyzer.smoothedAttributes)
                            showCritique = true
                        }) {
                            HStack {
                                if cloudService.isAnalyzing {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(cloudService.isAnalyzing ? "Analyzing..." : "Get AI Critique")
                            }
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 32)
                            .background(
                                LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(30)
                            .shadow(radius: 10)
                        }
                        .padding(.bottom, 60)
                        .disabled(cloudService.isAnalyzing)
                    }
                    
                    // Sliding Critique Panel
                    if showCritique {
                        CritiqueView(service: cloudService, onDismiss: {
                            showCritique = false
                        })
                        .transition(.move(edge: .bottom))
                        .zIndex(2)
                    }
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.spring(), value: cameraManager.aestheticAnalyzer.aestheticScore)
        .animation(.easeInOut, value: cameraManager.capturedImage != nil)
        .animation(.spring(), value: showCritique)
        .sheet(isPresented: $showGallery) {
            GalleryView()
        }
    }
    
    public func scoreColor(_ score: Float) -> Color {
        if score > 0.7 { return .green }
        if score > 0.4 { return .yellow }
        return .red
    }
}

public struct ScoreRing: View {
    var score: Float
    
    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 8)
                .frame(width: 80, height: 80)
            
            Circle()
                .trim(from: 0, to: CGFloat(score))
                .stroke(scoreColor(score), lineWidth: 8)
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))
            
            Text(String(format: "%.0f", score * 100))
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
    }
    
    func scoreColor(_ score: Float) -> Color {
        if score > 0.7 { return .green }
        if score > 0.4 { return .yellow }
        return .red
    }
}

// Helper for glassmorphism effect
public struct BlurView: UIViewRepresentable {
    public var style: UIBlurEffect.Style
    
    public init(style: UIBlurEffect.Style) {
        self.style = style
    }
    
    public func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    public func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

public struct ModeButtonView: View {
    var title: String
    var subtitle: String
    var icon: String
    var color: Color
    
    public var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
                .frame(width: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.3))
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
