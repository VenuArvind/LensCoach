import AVFoundation
import UIKit
import CoreImage
import Combine

public enum ScoringMode {
    case local, cloud
}

public class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    @Published public var currentFrame: CVPixelBuffer?
    @Published public var capturedImage: UIImage?
    @Published public var aestheticAnalyzer = AestheticAnalyzer()
    @Published public var tipGenerator = LLMTipGenerator()
    @Published public var cloudScoringService = CloudScoringService()
    @Published public var cloudCritiqueService = CloudCritiqueService()
    
    @Published public var scoringMode: ScoringMode = .local {
        didSet {
            if scoringMode == .cloud {
                startCloudScoringTimer()
            } else {
                stopCloudScoringTimer()
                aestheticAnalyzer.resetSmoother()
            }
        }
    }
    
    public let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.lenscoach.sessionQueue")
    private let videoOutputQueue = DispatchQueue(label: "com.lenscoach.videoOutputQueue")
    
    private var frameCount = 0
    private var cloudScoringTimer: Timer?
    
    public override init() {
        super.init()
        setupSession()
    }
    
    public func setupSession() {
        sessionQueue.async {
            self.session.beginConfiguration()
            
            // 1. Setup Input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.session.canAddInput(videoDeviceInput) else {
                print("Could not add video device input to the session")
                return
            }
            self.session.addInput(videoDeviceInput)
            
            // 2. Setup Video Output (for live inference)
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.setSampleBufferDelegate(self, queue: self.videoOutputQueue)
                self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            }
            
            // 3. Setup Photo Output (for cloud critique)
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            
            self.session.sessionPreset = .photo
            self.session.commitConfiguration()
        }
    }
    
    public func start() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }
    
    public func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
    
    public func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func startCloudScoringTimer() {
        cloudScoringTimer?.invalidate()
        cloudScoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.performCloudScoring()
        }
    }
    
    private func stopCloudScoringTimer() {
        cloudScoringTimer?.invalidate()
        cloudScoringTimer = nil
    }
    
    private func performCloudScoring() {
        guard scoringMode == .cloud, let pixelBuffer = currentFrame else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)
        
        cloudScoringService.fetchScores(
            for: uiImage,
            provider: cloudCritiqueService.selectedProvider,
            key: cloudCritiqueService.currentKey
        ) { [weak self] scores in
            if let scores = scores {
                self?.aestheticAnalyzer.updateScores(from: scores)
                // Trigger tips based on cloud scores too
                self?.tipGenerator.generateTipIfNeeded(scores: self?.aestheticAnalyzer.smoothedAttributes ?? [:])
            }
        }
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Always update preview layer for UI smoothness
        DispatchQueue.main.async {
            self.currentFrame = pixelBuffer
        }
        
        // Frame Sampling: Every 2nd frame for local inference
        frameCount += 1
        guard frameCount % 2 == 0 else { return }
        
        if scoringMode == .local {
            // Feed to ML Scorer
            aestheticAnalyzer.analyze(pixelBuffer: pixelBuffer)
            
            // Trigger Tip Generator if needed (checks its own 2.5s debounce)
            tipGenerator.generateTipIfNeeded(scores: aestheticAnalyzer.smoothedAttributes)
        }
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        
        // Save to Gallery
        GalleryManager.shared.savePhoto(
            image,
            aestheticScore: aestheticAnalyzer.aestheticScore,
            attributes: aestheticAnalyzer.smoothedAttributes
        )
        
        DispatchQueue.main.async {
            self.capturedImage = image
        }
    }
}
