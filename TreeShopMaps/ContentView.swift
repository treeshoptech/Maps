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
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        ZStack {
            MapView(region: $region, showUserLocation: $showUserLocation)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    SearchBar(text: $searchText, onSearchButtonClicked: {
                        performSearch()
                    })
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                
                Spacer()
                
                HStack {
                    Spacer()
                    
                    VStack(spacing: 8) {
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