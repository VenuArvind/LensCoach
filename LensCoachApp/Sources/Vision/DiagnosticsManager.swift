import UIKit
import os

public class DiagnosticsManager {
    public static let shared = DiagnosticsManager()
    private var timer: Timer?
    
    // Performance metrics
    public var lastInferenceLatency: Double = 0.0
    private var frameCount: Int = 0
    private var currentFPS: Int = 0
    
    // Returns memory used by the app in Megabytes
    private func getMemoryUsageMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024)
        } else {
            return 0.0
        }
    }
    
    // Public hook for CameraManager to report a frame was processed
    public func reportFrame() {
        frameCount += 1
    }
    
    // Public hook for AestheticAnalyzer to report latency
    public func reportInferenceLatency(_ ms: Double) {
        lastInferenceLatency = ms
    }
    
    // Starts logging diagnostics to the console and a local CSV file
    public func startLogging() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let logURL = documentsURL.appendingPathComponent("diagnostics.csv")
        
        // Ensure file exists with header
        if !fileManager.fileExists(atPath: logURL.path) {
            let header = "Timestamp,FPS,Latency_ms,Memory_MB,ThermalState,Battery_Percent\n"
            try? header.write(to: logURL, atomically: true, encoding: .utf8)
        }
        
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let memoryMB = self.getMemoryUsageMB()
            let thermalState = ProcessInfo.processInfo.thermalState.rawValue
            let batteryLevel = UIDevice.current.batteryLevel * 100
            
            // Calculate FPS
            self.currentFPS = self.frameCount
            self.frameCount = 0
            
            let timestamp = Date().timeIntervalSince1970
            let logLine = "\(timestamp),\(self.currentFPS),\(String(format: "%.1f", self.lastInferenceLatency)),\(String(format: "%.1f", memoryMB)),\(thermalState),\(Int(batteryLevel))\n"
            
            // Print to console for immediate visibility
            print("DIAGNOSTICS | \(logLine.trimmingCharacters(in: .newlines))")
            
            // Append to File
            if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                fileHandle.seekToEndOfFile()
                if let data = logLine.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            }
        }
    }
    
    public func stopLogging() {
        self.timer?.invalidate()
        self.timer = nil
    }
}
