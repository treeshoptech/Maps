import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
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
        .onAppear {
            locationManager.requestLocationPermission()
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
        .alert("Name Work Area", isPresented: $showWorkAreaName) {
            TextField("Work Area Name", text: $newWorkAreaName)
            Button("Save") {
                saveCurrentWorkArea()
            }
            Button("Cancel", role: .cancel) {
                isDrawingMode = false
            }
        } message: {
            Text("Enter a name for this work area")
        }
        .overlay(alignment: .bottomLeading) {
            if !savedWorkAreas.isEmpty {
                WorkAreaListView(
                    workAreas: savedWorkAreas,
                    selectedWorkArea: $selectedWorkArea,
                    onDelete: { workArea in
                        deleteWorkArea(workArea)
                    }
                )
                .padding(.leading, 16)
                .padding(.bottom, 100)
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
            perimeter: currentPerimeter
        )
        
        savedWorkAreas.append(workArea)
        
        // Reset drawing state
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
                    Text("Perimeter: \(String(format: "%.0f", perimeter)) m")
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Work Areas")
                .font(.headline)
                .foregroundColor(.white)
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
                    
                    Text("\(String(format: "%.0f", workArea.perimeter)) m")
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

struct SearchBar: View {
    @Binding var text: String
    var onSearchButtonClicked: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search TreeShop Maps", text: $text)
                .foregroundColor(.white)
                .onSubmit {
                    onSearchButtonClicked()
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.8))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var lastKnownLocation: CLLocation?
    
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
        lastKnownLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}

#Preview {
    ContentView()
}