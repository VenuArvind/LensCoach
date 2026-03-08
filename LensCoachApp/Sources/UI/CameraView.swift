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
    @State private var showCloudSetup = false
    @State private var showSettings = false
    @State private var showDeleteConfirmation = false
    
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
                            if !showCloudSetup {
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
                                    showCloudSetup = true
                                }) {
                                    ModeButtonView(
                                        title: "CLOUD AI",
                                        subtitle: "5s / Deep Reasoning / LLM Analysis",
                                        icon: "cloud.fill",
                                        color: .blue
                                    )
                                }
                            } else {
                                // Cloud Setup Sub-screen
                                VStack(spacing: 20) {
                                    Text("Cloud AI Configuration")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Picker("Provider", selection: $cloudService.selectedProvider) {
                                        ForEach(AIProvider.allCases) { provider in
                                            Text(provider.rawValue).tag(provider)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    .padding(.horizontal)
                                    
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("\(cloudService.selectedProvider.rawValue) API Key")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white.opacity(0.6))
                                        
                                        Group {
                                            if cloudService.selectedProvider == .anthropic {
                                                SecureField("sk-ant-...", text: $cloudService.anthropicKey)
                                            } else if cloudService.selectedProvider == .gemini {
                                                SecureField("AIza...", text: $cloudService.geminiKey)
                                            } else {
                                                SecureField("sk-...", text: $cloudService.openaiKey)
                                            }
                                        }
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .padding()
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(10)
                                        .foregroundColor(.white)
                                    }
                                    .padding(.horizontal)
                                    
                                    HStack(spacing: 12) {
                                        Button(action: { showCloudSetup = false }) {
                                            Text("Back")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white.opacity(0.6))
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(Color.white.opacity(0.1))
                                                .cornerRadius(12)
                                        }
                                        
                                        Button(action: {
                                            cameraManager.scoringMode = .cloud
                                            selectionRequired = false
                                            cameraManager.start()
                                        }) {
                                            Text("Start Lens")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(Color.blue)
                                                .cornerRadius(12)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(20)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
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
                // Slim Top Bar
                HStack(spacing: 12) {
                    // Optimized Mode Picker
                    Picker("Scoring", selection: $cameraManager.scoringMode) {
                        Text("LOCAL").tag(ScoringMode.local)
                        Text("CLOUD").tag(ScoringMode.cloud)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 140)
                    .scaleEffect(0.9)
                    
                    if (cameraManager.scoringMode == .cloud && cameraManager.cloudScoringService.isScoring) || cloudService.isAnalyzing {
                        HStack(spacing: 6) {
                            if let lastFrame = cameraManager.cloudScoringService.lastAnonymizedFrame {
                                Image(uiImage: lastFrame)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 30, height: 30)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.green, lineWidth: 1))
                            }
                            Image(systemName: "face.dashed.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                        }
                        .transition(.opacity)
                    }
                    
                    Spacer()
                    
                    // Compact Gallery & Settings Buttons
                    HStack(spacing: 12) {
                        Button(action: { showGallery = true }) {
                            Image(systemName: "photo.stack")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(BlurView(style: .systemThinMaterialDark).clipShape(Circle()))
                        }
                        
                        Button(action: { showSettings.toggle() }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(BlurView(style: .systemThinMaterialDark).clipShape(Circle()))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 44)
                
                // Small Score Ring (Floating)
                HStack {
                    ScoreRing(score: cameraManager.aestheticAnalyzer.aestheticScore)
                        .scaleEffect(0.7) // Shrink to ~56px
                        .frame(width: 60, height: 60)
                        .padding(.leading, 10)
                    
                    if cameraManager.scoringMode == .cloud && !cameraManager.cloudScoringService.isScoring && !cloudService.isAnalyzing {
                        if cloudService.currentKey.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "key.fill")
                                Text("Key Required")
                            }
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1).cornerRadius(4))
                        } else {
                            Text("Cloud AI Active")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.blue.opacity(0.8))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(BlurView(style: .systemThinMaterialDark).cornerRadius(4))
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top, 8)
                
                // Compact Tip Bubble (Floating Bottom-Left)
                if !cameraManager.tipGenerator.currentTip.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                            Text("AI TIP")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.yellow.opacity(0.8))
                        }
                        
                        Text(cameraManager.tipGenerator.currentTip)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: 220, alignment: .leading)
                    .background(BlurView(style: .systemThinMaterialDark).cornerRadius(12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .padding(.leading, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(cameraManager.tipGenerator.currentTip)
                }
                
                Spacer()
                
                // Mini Attribute HUD (Coaching) - Shrink and move to edge
                if cameraManager.aestheticAnalyzer.aestheticScore > 0 {
                    HStack(spacing: 12) {
                        ForEach(weakestAttributes, id: \.0) { attr, score in
                            HStack(spacing: 6) {
                                Text(attr.prefix(4).uppercased())
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text(String(format: "%.1f", score))
                                    .foregroundColor(.white)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(scoreColor(score).opacity(0.4))
                                    .cornerRadius(4)
                            }
                            .padding(4)
                            .background(BlurView(style: .systemThinMaterialDark).cornerRadius(6))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    .transition(.opacity)
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
            
            // Floating Settings Panel
            if showSettings {
                VStack {
                    Spacer()
                    VStack(spacing: 20) {
                        HStack {
                            Text("AI Engine Settings")
                                .font(.system(size: 18, weight: .bold))
                            Spacer()
                            Button(action: { showSettings = false }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.4))
                                    .font(.title3)
                            }
                        }
                        
                        Picker("Provider", selection: $cloudService.selectedProvider) {
                            ForEach(AIProvider.allCases) { provider in
                                Text(provider.rawValue).tag(provider)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(cloudService.selectedProvider.rawValue) API Key")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Group {
                                if cloudService.selectedProvider == .anthropic {
                                    SecureField("sk-ant-...", text: $cloudService.anthropicKey)
                                } else if cloudService.selectedProvider == .gemini {
                                    SecureField("AIza...", text: $cloudService.geminiKey)
                                } else {
                                    SecureField("sk-...", text: $cloudService.openaiKey)
                                }
                            }
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                        }
                        
                        Text("Changes take effect immediately for live scoring.")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                            .italic()
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Delete All Captured Photos")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(24)
                    .background(BlurView(style: .systemMaterialDark).cornerRadius(30))
                    .padding()
                    .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(5)
                .alert("Delete All Photos?", isPresented: $showDeleteConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete All", role: .destructive) {
                        GalleryManager.shared.clearAll()
                        showSettings = false
                    }
                } message: {
                    Text("This will permanently remove all photos from your LensCoach gallery. This action cannot be undone.")
                }
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
