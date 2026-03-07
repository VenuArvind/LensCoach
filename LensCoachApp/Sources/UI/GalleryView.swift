import SwiftUI
import Charts

public struct GalleryView: View {
    @ObservedObject var gallery = GalleryManager.shared
    @Environment(\.dismiss) var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Analytics Section
                        if gallery.photos.count > 1 {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("SCORE TRENDS")
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                ChartView(photos: gallery.photos)
                                    .frame(height: 200)
                                    .padding()
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(16)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Gallery Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(gallery.photos) { entry in
                                GalleryItemView(entry: entry)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Your Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct ChartView: View {
    var photos: [PhotoEntry]
    
    var body: some View {
        Chart {
            ForEach(photos.reversed()) { entry in
                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Score", entry.aestheticScore)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                
                AreaMark(
                    x: .value("Date", entry.date),
                    y: .value("Score", entry.aestheticScore)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
            }
        }
        .chartYScale(domain: 0...1)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.1))
                AxisTick().foregroundStyle(.white.opacity(0.1))
                AxisValueLabel().foregroundStyle(.white.opacity(0.5))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.1))
                AxisValueLabel {
                    if let score = value.as(Double.self) {
                        Text("\(Int(score * 100))%")
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
    }
}

struct GalleryItemView: View {
    let entry: PhotoEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = GalleryManager.shared.loadImage(for: entry) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: (UIScreen.main.bounds.width - 48) / 2, height: 200)
                    .clipped()
                    .cornerRadius(12)
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("\(Int(entry.aestheticScore * 100))%")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(scoreColor(entry.aestheticScore).opacity(0.8))
                                    .cornerRadius(8)
                                    .padding(8)
                            }
                        }
                    )
            }
            
            Text(entry.date, style: .date)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    func scoreColor(_ score: Float) -> Color {
        if score > 0.7 { return .green }
        if score > 0.4 { return .yellow }
        return .red
    }
}
