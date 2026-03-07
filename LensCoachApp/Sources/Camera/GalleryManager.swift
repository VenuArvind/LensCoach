import Foundation
import UIKit

public struct PhotoEntry: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let imagePath: String
    public let aestheticScore: Float
    public let attributes: [String: Float]
    
    public init(id: UUID = UUID(), date: Date = Date(), imagePath: String, aestheticScore: Float, attributes: [String: Float]) {
        self.id = id
        self.date = date
        self.imagePath = imagePath
        self.aestheticScore = aestheticScore
        self.attributes = attributes
    }
}

public class GalleryManager: ObservableObject {
    @Published public var photos: [PhotoEntry] = []
    
    private let fileManager = FileManager.default
    private let storageFolderName = "LensCoachPhotos"
    private let indexFileName = "gallery_index.json"
    
    public static let shared = GalleryManager()
    
    private init() {
        loadIndex()
    }
    
    private var baseDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(storageFolderName)
    }
    
    private var indexURL: URL {
        baseDirectory.appendingPathComponent(indexFileName)
    }
    
    public func savePhoto(_ image: UIImage, aestheticScore: Float, attributes: [String: Float]) {
        ensureDirectoryExists()
        
        let id = UUID()
        let fileName = "\(id.uuidString).jpg"
        let fileURL = baseDirectory.appendingPathComponent(fileName)
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        do {
            try imageData.write(to: fileURL)
            
            let entry = PhotoEntry(
                id: id,
                imagePath: fileName,
                aestheticScore: aestheticScore,
                attributes: attributes
            )
            
            DispatchQueue.main.async {
                self.photos.insert(entry, at: 0)
                self.saveIndex()
            }
        } catch {
            print("Error saving photo: \(error)")
        }
    }
    
    public func loadImage(for entry: PhotoEntry) -> UIImage? {
        let fileURL = baseDirectory.appendingPathComponent(entry.imagePath)
        return UIImage(contentsOfFile: fileURL.path)
    }
    
    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func saveIndex() {
        do {
            let data = try JSONEncoder().encode(photos)
            try data.write(to: indexURL)
        } catch {
            print("Error saving gallery index: \(error)")
        }
    }
    
    private func loadIndex() {
        guard fileManager.fileExists(atPath: indexURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: indexURL)
            let entries = try JSONDecoder().decode([PhotoEntry].self, from: data)
            DispatchQueue.main.async {
                self.photos = entries
            }
        } catch {
            print("Error loading gallery index: \(error)")
        }
    }
}
