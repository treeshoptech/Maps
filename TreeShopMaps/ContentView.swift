import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var showUserLocation = true
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var showProfile = false
    @State private var isDrawingMode = false
    @State private var polygonPoints: [CLLocationCoordinate2D] = []
    @State private var currentArea: Double = 0.0
    @State private var currentPerimeter: Double = 0.0
    @State private var savedWorkAreas: [WorkAreaDisplay] = []
    @State private var selectedWorkArea: WorkAreaDisplay? = nil
    @State private var showWorkAreaName = false
    @State private var newWorkAreaName = ""
    @State private var showWorkAreaList = false
    @State private var selectedProjectSize: ProjectSize = .large
    @State private var mapType: MKMapType = .satellite
    @StateObject private var locationManager = LocationManager()
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some View {
        ZStack {
            MapView(
                region: $region,
                showUserLocation: $showUserLocation,
                isDrawingMode: $isDrawingMode,
                polygonPoints: $polygonPoints,
                currentArea: $currentArea,
                currentPerimeter: $currentPerimeter,
                savedWorkAreas: $savedWorkAreas,
                selectedWorkArea: $selectedWorkArea,
                selectedProjectSize: $selectedProjectSize,
                mapType: $mapType,
                onPointAdded: { coordinate in
                    // Handle point added
                },
                onPolygonCompleted: { coordinates in
                    // Handle polygon completion
                },
                onWorkAreaTapped: { workArea in
                    selectedWorkArea = selectedWorkArea?.id == workArea.id ? nil : workArea
                },
                onWorkAreaLongPressed: { workArea in
                    // Handle long press - could show delete/edit options
                }
            )
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    SearchBar(text: $searchText, onSearchButtonClicked: {
                        performSearch()
                    })
                    
                    if !savedWorkAreas.isEmpty {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showWorkAreaList.toggle()
                            }
                        }) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(showWorkAreaList ? Color.blue.opacity(0.9) : Color.black.opacity(0.75))
                                .clipShape(Circle())
                        }
                    }
                    
                    Button(action: {
                        showProfile = true
                    }) {
                        Image(systemName: authManager.isAuthenticated ? "person.crop.circle.fill" : "person.crop.circle")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.75))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                if isDrawingMode && !polygonPoints.isEmpty {
                    MeasurementDisplay(area: currentArea, perimeter: currentPerimeter, pointCount: polygonPoints.count)
                        .padding(.horizontal)
                        .transition(.opacity)
                }
                
                Spacer()
                
                HStack {
                    if isDrawingMode {
                        VStack(spacing: 8) {
                            Button(action: {
                                if !polygonPoints.isEmpty {
                                    polygonPoints.removeLast()
                                }
                            }) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.orange.opacity(0.9))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .disabled(polygonPoints.isEmpty)
                            .opacity(polygonPoints.isEmpty ? 0.5 : 1.0)
                            
                            Button(action: {
                                if !polygonPoints.isEmpty {
                                    // First click: clear points
                                    polygonPoints.removeAll()
                                    currentArea = 0.0
                                    currentPerimeter = 0.0
                                } else {
                                    // Second click (nothing to delete): exit drawing mode
                                    isDrawingMode = false
                                }
                            }) {
                                Image(systemName: polygonPoints.isEmpty ? "xmark" : "trash")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(polygonPoints.isEmpty ? Color.gray.opacity(0.9) : Color.red.opacity(0.9))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            
                            Button(action: {
                                if polygonPoints.count >= 3 {
                                    showWorkAreaName = true
                                } else {
                                    isDrawingMode = false
                                }
                            }) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.green.opacity(0.9))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .disabled(polygonPoints.count < 3)
                            .opacity(polygonPoints.count < 3 ? 0.5 : 1.0)
                        }
                        .padding(.leading, 16)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        if !isDrawingMode {
                            Button(action: {
                                isDrawingMode = true
                            }) {
                                Image(systemName: "pencil.tip.crop.circle")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.blue.opacity(0.9))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        Button(action: {
                            zoomIn()
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        Button(action: {
                            zoomOut()
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        Divider()
                            .frame(width: 30)
                            .background(Color.gray.opacity(0.5))
                            .padding(.vertical, 4)
                        
                        Button(action: {
                            centerOnUserLocation()
                        }) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 100)
                }
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
        .onAppear {
            locationManager.onLocationUpdate = { location in
                // Set region to user location with zoom level ~16
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
            locationManager.requestLocationPermission()
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
        .sheet(isPresented: $showWorkAreaName) {
            WorkAreaCreationSheet(
                workAreaName: $newWorkAreaName,
                area: currentArea,
                perimeter: currentPerimeter,
                onSave: {
                    saveCurrentWorkArea()
                },
                onCancel: {
                    isDrawingMode = false
                    showWorkAreaName = false
                }
            )
        }
        .overlay(alignment: .bottomLeading) {
            if showWorkAreaList && !savedWorkAreas.isEmpty {
                WorkAreaListView(
                    workAreas: savedWorkAreas,
                    selectedWorkArea: $selectedWorkArea,
                    onDelete: { workArea in
                        deleteWorkArea(workArea)
                    },
                    onClose: {
                        showWorkAreaList = false
                    }
                )
                .padding(.leading, 16)
                .padding(.bottom, 100)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
    }
    
    func zoomIn() {
        region.span.latitudeDelta *= 0.5
        region.span.longitudeDelta *= 0.5
    }
    
    func zoomOut() {
        region.span.latitudeDelta *= 2.0
        region.span.longitudeDelta *= 2.0
    }
    
    func centerOnUserLocation() {
        if let location = locationManager.lastKnownLocation {
            region.center = location.coordinate
        }
    }
    
    func performSearch() {
    }
    
    func saveCurrentWorkArea() {
        guard polygonPoints.count >= 3 else { return }
        
        let workAreaName = newWorkAreaName.isEmpty ? "Work Area \(savedWorkAreas.count + 1)" : newWorkAreaName
        let workArea = WorkAreaDisplay(
            name: workAreaName,
            coordinates: polygonPoints,
            area: currentArea,
            perimeter: currentPerimeter,
            projectSize: .large
        )
        
        savedWorkAreas.append(workArea)
        
        // Reset drawing state - clear points first to trigger polygon cleanup
        polygonPoints.removeAll()
        currentArea = 0.0
        currentPerimeter = 0.0
        isDrawingMode = false
        newWorkAreaName = ""
    }
    
    func deleteWorkArea(_ workArea: WorkAreaDisplay) {
        savedWorkAreas.removeAll { $0.id == workArea.id }
        if selectedWorkArea?.id == workArea.id {
            selectedWorkArea = nil
        }
    }
}

struct MeasurementDisplay: View {
    let area: Double
    let perimeter: Double
    let pointCount: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "circle.grid.2x2")
                        .foregroundColor(.blue)
                    Text("Area: \(String(format: "%.2f", area)) acres")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                HStack {
                    Image(systemName: "arrow.triangle.swap")
                        .foregroundColor(.green)
                    Text("Perimeter: \(String(format: "%.0f", perimeter)) ft")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.orange)
                    Text("Points: \(pointCount)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

struct WorkAreaListView: View {
    let workAreas: [WorkAreaDisplay]
    @Binding var selectedWorkArea: WorkAreaDisplay?
    let onDelete: (WorkAreaDisplay) -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Work Areas")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(workAreas) { workArea in
                        WorkAreaRow(
                            workArea: workArea,
                            isSelected: selectedWorkArea?.id == workArea.id,
                            onTap: {
                                selectedWorkArea = selectedWorkArea?.id == workArea.id ? nil : workArea
                            },
                            onDelete: {
                                onDelete(workArea)
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(maxHeight: 200)
        }
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct WorkAreaRow: View {
    let workArea: WorkAreaDisplay
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            // Color indicator and icon
            HStack(spacing: 6) {
                Circle()
                    .fill(workArea.projectSize.swiftUIColor)
                    .frame(width: 12, height: 12)
                
                Image(systemName: workArea.projectSize.icon)
                    .font(.system(size: 12))
                    .foregroundColor(workArea.projectSize.swiftUIColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(workArea.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                HStack {
                    Text("\(String(format: "%.2f", workArea.area)) acres")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("\(String(format: "%.0f", workArea.perimeter)) ft")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.green.opacity(0.3) : Color.clear)
        .cornerRadius(8)
        .onTapGesture {
            onTap()
        }
    }
}

struct WorkAreaCreationSheet: View {
    @Binding var workAreaName: String
    let area: Double
    let perimeter: Double
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Area Info
                VStack(spacing: 12) {
                    Text("Work Area Details")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Area")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(String(format: "%.2f", area)) acres")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Perimeter")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(String(format: "%.0f", perimeter)) ft")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Name Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Work Area Name (Optional)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("Enter custom name", text: $workAreaName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    
                    Button("Save Work Area") {
                        onSave()
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }
            .padding()
            .background(Color.black)
            .navigationTitle("Create Work Area")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
        }
    }
}

struct ProjectSizeButton: View {
    let projectSize: ProjectSize
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Color indicator
                Circle()
                    .fill(projectSize.swiftUIColor)
                    .frame(width: 16, height: 16)
                
                // Icon
                Image(systemName: projectSize.icon)
                    .font(.system(size: 18))
                    .foregroundColor(projectSize.swiftUIColor)
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(projectSize.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(projectSize.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var onSearchButtonClicked: () -> Void
    @StateObject private var searchCompleter = SearchCompleter()
    @State private var showingSuggestions = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search TreeShop Maps", text: $text)
                    .foregroundColor(.white)
                    .onSubmit {
                        onSearchButtonClicked()
                        hideKeyboard()
                        showingSuggestions = false
                    }
                    .onChange(of: text) {
                        searchCompleter.searchFragment = text
                        showingSuggestions = !text.isEmpty && !searchCompleter.completions.isEmpty
                    }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                        showingSuggestions = false
                        hideKeyboard()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.8))
            .cornerRadius(showingSuggestions ? 10 : 10, corners: showingSuggestions ? [.topLeft, .topRight] : .allCorners)
            
            if showingSuggestions {
                VStack(spacing: 0) {
                    ForEach(Array(searchCompleter.completions.prefix(5).enumerated()), id: \.offset) { index, completion in
                        Button(action: {
                            text = completion.title
                            showingSuggestions = false
                            hideKeyboard()
                            onSearchButtonClicked()
                        }) {
                            HStack {
                                Image(systemName: "location")
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(completion.title)
                                        .foregroundColor(.white)
                                        .font(.body)
                                        .multilineTextAlignment(.leading)
                                    
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle)
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        
                        if index < min(4, searchCompleter.completions.count - 1) {
                            Divider()
                                .background(Color.gray.opacity(0.3))
                        }
                    }
                }
                .background(Color.black.opacity(0.8))
                .cornerRadius(10, corners: [.bottomLeft, .bottomRight])
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var lastKnownLocation: CLLocation?
    @Published var hasInitialLocation = false
    var onLocationUpdate: ((CLLocation) -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastKnownLocation = location
        
        if !hasInitialLocation {
            hasInitialLocation = true
            onLocationUpdate?(location)
            // Stop updating after getting initial location to save battery
            locationManager.stopUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}

// MARK: - Search Autocomplete
class SearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var completions: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()
    
    var searchFragment: String = "" {
        didSet {
            if searchFragment.isEmpty {
                completions = []
            } else {
                completer.queryFragment = searchFragment
            }
        }
    }
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.completions = completer.results
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error.localizedDescription)")
    }
}

// MARK: - Keyboard Hiding
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    ContentView()
}