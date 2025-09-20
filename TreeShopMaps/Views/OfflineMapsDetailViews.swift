import SwiftUI
import MapKit
import CoreData

// MARK: - Offline Map Row
struct OfflineMapRow: View {
    let map: OfflineMapRegion
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Map Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "map.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    if map.isDownloading {
                        CircularProgressView(progress: map.downloadProgress)
                            .frame(width: 60, height: 60)
                    }
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(map.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text(map.formattedSize)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 12) {
                        Label(formatDate(map.downloadedAt), systemImage: "arrow.down.circle")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        if let expiresAt = map.expiresAt {
                            Label("Expires \(formatDate(expiresAt))", systemImage: "clock")
                                .font(.caption2)
                                .foregroundColor(isExpiringSoon(expiresAt) ? .orange : .gray)
                        }
                    }
                }
                
                Spacer()
                
                // Status
                if map.isDownloading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.7)
                        Text("\(Int(map.downloadProgress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.08))
            .cornerRadius(16)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    private func isExpiringSoon(_ date: Date) -> Bool {
        date.timeIntervalSinceNow < 7 * 24 * 60 * 60 // Within 7 days
    }
}

// MARK: - Add Offline Map View
struct AddOfflineMapView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mapName = ""
    @State private var selectedRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    @State private var selectedQuality: MapQuality = .standard
    @State private var estimatedSize: String = "0 MB"
    @State private var isDownloading = false
    
    enum MapQuality: String, CaseIterable {
        case standard = "Standard"
        case high = "High"
        case maximum = "Maximum"
        
        var zoomLevels: (min: Int, max: Int) {
            switch self {
            case .standard: return (10, 14)
            case .high: return (10, 16)
            case .maximum: return (10, 18)
            }
        }
        
        var estimatedSizeMultiplier: Double {
            switch self {
            case .standard: return 1.0
            case .high: return 2.5
            case .maximum: return 5.0
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Map Selection Area
                    ZStack {
                        MapRegionSelector(region: $selectedRegion)
                            .frame(height: 300)
                        
                        // Region Overlay
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue, lineWidth: 2)
                            .padding(40)
                            .allowsHitTesting(false)
                    }
                    
                    // Settings
                    ScrollView {
                        VStack(spacing: 20) {
                            // Name Input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Map Name")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                TextField("Enter map name", text: $mapName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            .padding(.horizontal)
                            
                            // Quality Selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Download Quality")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Picker("Quality", selection: $selectedQuality) {
                                    ForEach(MapQuality.allCases, id: \.self) { quality in
                                        Text(quality.rawValue).tag(quality)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: selectedQuality) { _ in
                                    updateEstimatedSize()
                                }
                            }
                            .padding(.horizontal)
                            
                            // Download Info
                            VStack(spacing: 12) {
                                InfoRow(label: "Estimated Size", value: estimatedSize)
                                InfoRow(label: "Zoom Levels", value: "\(selectedQuality.zoomLevels.min)-\(selectedQuality.zoomLevels.max)")
                                InfoRow(label: "Expires", value: "30 days")
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            
                            // Download Button
                            Button(action: {
                                downloadMap()
                            }) {
                                HStack {
                                    if isDownloading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.down.circle.fill")
                                    }
                                    Text(isDownloading ? "Downloading..." : "Download Map")
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isDownloading ? Color.gray : Color.blue)
                                .cornerRadius(12)
                            }
                            .disabled(mapName.isEmpty || isDownloading)
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Download Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            updateEstimatedSize()
        }
    }
    
    private func updateEstimatedSize() {
        let baseSize = 50.0 // MB
        let regionMultiplier = Double(selectedRegion.span.latitudeDelta * selectedRegion.span.longitudeDelta) * 100
        let size = baseSize * regionMultiplier * selectedQuality.estimatedSizeMultiplier
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        estimatedSize = formatter.string(fromByteCount: Int64(size * 1024 * 1024))
    }
    
    private func downloadMap() {
        isDownloading = true
        
        // Create offline map region in Core Data
        let context = DataStackManager.shared.viewContext
        let offlineMap = OfflineMapRegion(context: context)
        
        offlineMap.id = UUID()
        offlineMap.name = mapName
        offlineMap.minLatitude = selectedRegion.center.latitude - selectedRegion.span.latitudeDelta / 2
        offlineMap.maxLatitude = selectedRegion.center.latitude + selectedRegion.span.latitudeDelta / 2
        offlineMap.minLongitude = selectedRegion.center.longitude - selectedRegion.span.longitudeDelta / 2
        offlineMap.maxLongitude = selectedRegion.center.longitude + selectedRegion.span.longitudeDelta / 2
        offlineMap.zoomLevelMin = Int16(selectedQuality.zoomLevels.min)
        offlineMap.zoomLevelMax = Int16(selectedQuality.zoomLevels.max)
        offlineMap.downloadedAt = Date()
        offlineMap.lastUpdatedAt = Date()
        offlineMap.expiresAt = Date().addingTimeInterval(30 * 24 * 60 * 60)
        offlineMap.isDownloading = true
        offlineMap.downloadProgress = 0.0
        offlineMap.user = UserProfile.current(in: context)
        
        DataStackManager.shared.save()
        
        // Simulate download
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            offlineMap.isDownloading = false
            offlineMap.downloadProgress = 1.0
            offlineMap.sizeInBytes = Int64(50 * 1024 * 1024) // 50 MB for demo
            DataStackManager.shared.save()
            dismiss()
        }
    }
}

// MARK: - Offline Map Detail View
struct OfflineMapDetailView: View {
    let map: OfflineMapRegion
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    @State private var showingUpdateAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Map Preview
                        MapPreview(region: map.region)
                            .frame(height: 250)
                            .cornerRadius(16)
                            .padding(.horizontal)
                        
                        // Map Info
                        VStack(spacing: 16) {
                            InfoSection(title: "Details") {
                                InfoRow(label: "Name", value: map.name)
                                InfoRow(label: "Size", value: map.formattedSize)
                                InfoRow(label: "Downloaded", value: formatDate(map.downloadedAt))
                                InfoRow(label: "Last Updated", value: formatDate(map.lastUpdatedAt))
                                if let expiresAt = map.expiresAt {
                                    InfoRow(label: "Expires", value: formatDate(expiresAt))
                                }
                            }
                            
                            InfoSection(title: "Coverage") {
                                InfoRow(label: "Zoom Levels", value: "\(map.zoomLevelMin)-\(map.zoomLevelMax)")
                                InfoRow(label: "Tile Count", value: "\(map.tileCount)")
                                InfoRow(label: "Area", value: formatArea())
                            }
                        }
                        .padding(.horizontal)
                        
                        // Actions
                        VStack(spacing: 12) {
                            Button(action: {
                                showingUpdateAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Check for Updates")
                                }
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                showingDeleteAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Map")
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Offline Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Delete Map", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteMap()
                }
            } message: {
                Text("Are you sure you want to delete this offline map? This action cannot be undone.")
            }
            .alert("Check for Updates", isPresented: $showingUpdateAlert) {
                Button("OK") {}
            } message: {
                Text("This map is up to date. No updates available.")
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatArea() -> String {
        let latDelta = map.maxLatitude - map.minLatitude
        let lonDelta = map.maxLongitude - map.minLongitude
        let area = latDelta * lonDelta * 111 * 111 // Rough km² calculation
        return String(format: "%.0f km²", area)
    }
    
    private func deleteMap() {
        let context = DataStackManager.shared.viewContext
        context.delete(map)
        DataStackManager.shared.save()
        dismiss()
    }
}

// MARK: - Supporting Components
struct MapRegionSelector: View {
    @Binding var region: MKCoordinateRegion
    
    var body: some View {
        ZStack {
            // Placeholder for actual map
            Rectangle()
                .fill(Color.gray.opacity(0.2))
            
            VStack {
                Image(systemName: "map")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                Text("Drag to select region")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct MapPreview: View {
    let region: MKCoordinateRegion
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
            
            VStack {
                Image(systemName: "map.fill")
                    .font(.largeTitle)
                    .foregroundColor(.green)
                Text("Offline Map Region")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct InfoSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                content
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }
}

struct CircularProgressView: View {
    let progress: Float
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear, value: progress)
        }
    }
}

// MARK: - Additional Supporting Views
struct SyncOptionRow: View {
    let title: String
    let isEnabled: Bool
    let lastSync: Date?
    
    var body: some View {
        HStack {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isEnabled ? .green : .gray)
            
            Text(title)
                .foregroundColor(.white)
            
            Spacer()
            
            if let lastSync = lastSync {
                Text(formatRelativeTime(lastSync))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct DataCategoryRow: View {
    let icon: String
    let title: String
    let count: String
    let size: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.15))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text(count)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(size)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.08))
            .cornerRadius(12)
        }
    }
}

struct StorageOverview: View {
    @State private var usedStorage: Double = 973.5
    @State private var totalStorage: Double = 10240.0
    
    var availableStorage: Double {
        totalStorage - usedStorage
    }
    
    var storagePercentage: Double {
        usedStorage / totalStorage
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Local Storage", systemImage: "internaldrive")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(formatBytes(usedStorage)) of \(formatBytes(totalStorage))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Storage Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * storagePercentage)
                }
            }
            .frame(height: 12)
            
            // Storage Breakdown
            HStack(spacing: 20) {
                StorageCategory(label: "Maps", size: 847, color: .green)
                StorageCategory(label: "Photos", size: 124, color: .purple)
                StorageCategory(label: "Other", size: 2.5, color: .gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    private func formatBytes(_ megabytes: Double) -> String {
        if megabytes >= 1024 {
            return String(format: "%.1f GB", megabytes / 1024)
        } else {
            return String(format: "%.0f MB", megabytes)
        }
    }
}

struct StorageCategory: View {
    let label: String
    let size: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
            
            Text("\(Int(size)) MB")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }
}