import SwiftUI
import MapKit
import CoreLocation

enum ProjectSize: String, CaseIterable, Equatable {
    case small = "Small"
    case medium = "Medium" 
    case large = "Large"
    case xLarge = "X-Large"
    case max = "MAX"
    
    var color: UIColor {
        switch self {
        case .small: return UIColor(red: 0.0, green: 0.9, blue: 0.0, alpha: 1.0)      // Bright Green
        case .medium: return UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)     // Bright Blue  
        case .large: return UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)      // Bright Orange
        case .xLarge: return UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)     // Bright Red
        case .max: return UIColor(red: 0.8, green: 0.2, blue: 1.0, alpha: 1.0)        // Bright Purple
        }
    }
    
    var swiftUIColor: Color {
        Color(color)
    }
    
    var description: String {
        switch self {
        case .small: return "Small Forestry Mulching"
        case .medium: return "Medium Forestry Mulching"
        case .large: return "Large Forestry Mulching"
        case .xLarge: return "X-Large Forestry Mulching"
        case .max: return "MAX Land Clearing (Full Strip)"
        }
    }
    
    var icon: String {
        switch self {
        case .small: return "leaf.fill"
        case .medium: return "tree.fill"
        case .large: return "forest.fill"
        case .xLarge: return "mountains.fill"
        case .max: return "bulldozer.fill"
        }
    }
}


struct WorkAreaDisplay: Identifiable, Hashable {
    let id: UUID
    let name: String
    let coordinates: [CLLocationCoordinate2D]
    let area: Double
    let perimeter: Double
    let isSelected: Bool
    let projectSize: ProjectSize
    
    init(id: UUID = UUID(), name: String, coordinates: [CLLocationCoordinate2D], area: Double, perimeter: Double, isSelected: Bool = false, projectSize: ProjectSize = .large) {
        self.id = id
        self.name = name
        self.coordinates = coordinates
        self.area = area
        self.perimeter = perimeter
        self.isSelected = isSelected
        self.projectSize = projectSize
    }
    
    var color: UIColor {
        projectSize.color
    }
    
    var colorName: String {
        projectSize.rawValue
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: WorkAreaDisplay, rhs: WorkAreaDisplay) -> Bool {
        lhs.id == rhs.id
    }
}

struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var showUserLocation: Bool
    @Binding var isDrawingMode: Bool
    @Binding var polygonPoints: [CLLocationCoordinate2D]
    @Binding var currentArea: Double
    @Binding var currentPerimeter: Double
    @Binding var savedWorkAreas: [WorkAreaDisplay]
    @Binding var selectedWorkArea: WorkAreaDisplay?
    @Binding var selectedProjectSize: ProjectSize
    @Binding var mapType: MKMapType
    
    var onPointAdded: ((CLLocationCoordinate2D) -> Void)?
    var onPolygonCompleted: (([CLLocationCoordinate2D]) -> Void)?
    var onWorkAreaTapped: ((WorkAreaDisplay) -> Void)?
    var onWorkAreaLongPressed: ((WorkAreaDisplay) -> Void)?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        mapView.mapType = mapType
        mapView.pointOfInterestFilter = .includingAll
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsUserLocation = true
        mapView.showsBuildings = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .default)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPressGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
        mapView.showsUserLocation = showUserLocation
        mapView.mapType = mapType
        
        context.coordinator.updateDrawingMode(isDrawingMode)
        context.coordinator.updateSavedWorkAreas(areas: savedWorkAreas, mapView: mapView)
        context.coordinator.updatePolygon(points: polygonPoints, mapView: mapView)
        
        // Update last project size
        context.coordinator.lastProjectSize = selectedProjectSize
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class AreaLabelAnnotation: NSObject, MKAnnotation {
        let coordinate: CLLocationCoordinate2D
        let title: String?
        let workAreaId: UUID
        
        init(coordinate: CLLocationCoordinate2D, title: String, workAreaId: UUID) {
            self.coordinate = coordinate
            self.title = title
            self.workAreaId = workAreaId
        }
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        var currentPolygon: MKPolygon?
        var currentPolyline: MKPolyline?
        var pointAnnotations: [MKPointAnnotation] = []
        var savedPolygons: [UUID: MKPolygon] = [:]
        var areaLabels: [UUID: AreaLabelAnnotation] = [:]
        var lastProjectSize: ProjectSize = .large
        
        init(_ parent: MapView) {
            self.parent = parent
            self.lastProjectSize = parent.selectedProjectSize
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let mapView = gesture.view as! MKMapView
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            if parent.isDrawingMode {
                DispatchQueue.main.async {
                    self.parent.polygonPoints.append(coordinate)
                    self.parent.onPointAdded?(coordinate)
                    
                    self.updatePolygon(points: self.parent.polygonPoints, mapView: mapView)
                    self.updateMeasurements()
                }
            } else {
                // Check if tap is on a saved work area
                if let tappedWorkArea = findWorkAreaAt(coordinate: coordinate) {
                    DispatchQueue.main.async {
                        self.parent.onWorkAreaTapped?(tappedWorkArea)
                    }
                }
            }
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }
            
            let mapView = gesture.view as! MKMapView
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            // Only handle long press when not in drawing mode
            if !parent.isDrawingMode {
                if let longPressedWorkArea = findWorkAreaAt(coordinate: coordinate) {
                    DispatchQueue.main.async {
                        self.parent.onWorkAreaLongPressed?(longPressedWorkArea)
                    }
                }
            }
        }
        
        func updateDrawingMode(_ isDrawing: Bool) {
            // Additional setup for drawing mode if needed
        }
        
        func refreshOverlays(mapView: MKMapView) {
            // Remove and re-add ONLY the current drawing polygon
            if let currentPolygon = currentPolygon {
                mapView.removeOverlay(currentPolygon)
                self.currentPolygon = nil
                
                let points = parent.polygonPoints
                if points.count >= 3 {
                    let newPolygon = MKPolygon(coordinates: points, count: points.count)
                    self.currentPolygon = newPolygon
                    mapView.addOverlay(newPolygon)
                }
            }
            
            // Remove and re-add current polyline
            if let currentPolyline = currentPolyline {
                mapView.removeOverlay(currentPolyline)
                self.currentPolyline = nil
                
                let points = parent.polygonPoints
                if points.count == 2 {
                    let newPolyline = MKPolyline(coordinates: points, count: points.count)
                    self.currentPolyline = newPolyline
                    mapView.addOverlay(newPolyline)
                }
            }
        }
        
        func updateSavedWorkAreas(areas: [WorkAreaDisplay], mapView: MKMapView) {
            // Remove old saved polygons and labels
            mapView.removeOverlays(Array(savedPolygons.values))
            mapView.removeAnnotations(Array(areaLabels.values))
            savedPolygons.removeAll()
            areaLabels.removeAll()
            
            // Add new saved work areas
            for area in areas {
                guard area.coordinates.count >= 3 else { continue }
                
                let polygon = MKPolygon(coordinates: area.coordinates, count: area.coordinates.count)
                polygon.title = area.name
                savedPolygons[area.id] = polygon
                mapView.addOverlay(polygon)
                
                // Add area label at polygon center
                let center = calculatePolygonCenter(coordinates: area.coordinates)
                let areaText = String(format: "%.2f acres", area.area)
                let label = AreaLabelAnnotation(coordinate: center, title: areaText, workAreaId: area.id)
                areaLabels[area.id] = label
                mapView.addAnnotation(label)
            }
            
            // Force refresh of all overlays to update colors
            DispatchQueue.main.async {
                for overlay in mapView.overlays {
                    if let renderer = mapView.renderer(for: overlay) {
                        renderer.setNeedsDisplay()
                    }
                }
            }
        }
        
        private func calculatePolygonCenter(coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
            guard !coordinates.isEmpty else { return CLLocationCoordinate2D() }
            
            let latitudes = coordinates.map { $0.latitude }
            let longitudes = coordinates.map { $0.longitude }
            
            let centerLat = (latitudes.min()! + latitudes.max()!) / 2
            let centerLng = (longitudes.min()! + longitudes.max()!) / 2
            
            return CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng)
        }
        
        private func findWorkAreaAt(coordinate: CLLocationCoordinate2D) -> WorkAreaDisplay? {
            for area in parent.savedWorkAreas {
                if isPointInPolygon(point: coordinate, polygon: area.coordinates) {
                    return area
                }
            }
            return nil
        }
        
        private func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
            guard polygon.count >= 3 else { return false }
            
            var inside = false
            var j = polygon.count - 1
            
            for i in 0..<polygon.count {
                let xi = polygon[i].longitude
                let yi = polygon[i].latitude
                let xj = polygon[j].longitude
                let yj = polygon[j].latitude
                
                if ((yi > point.latitude) != (yj > point.latitude)) &&
                   (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi) {
                    inside.toggle()
                }
                j = i
            }
            
            return inside
        }
        
        func updatePolygon(points: [CLLocationCoordinate2D], mapView: MKMapView) {
            mapView.removeAnnotations(pointAnnotations)
            pointAnnotations.removeAll()
            
            if let currentPolygon = currentPolygon {
                mapView.removeOverlay(currentPolygon)
                self.currentPolygon = nil
            }
            
            if let currentPolyline = currentPolyline {
                mapView.removeOverlay(currentPolyline)
                self.currentPolyline = nil
            }
            
            guard !points.isEmpty else { return }
            
            for (index, point) in points.enumerated() {
                let annotation = MKPointAnnotation()
                annotation.coordinate = point
                annotation.title = "Point \(index + 1)"
                pointAnnotations.append(annotation)
                mapView.addAnnotation(annotation)
            }
            
            if points.count >= 3 {
                let polygon = MKPolygon(coordinates: points, count: points.count)
                currentPolygon = polygon
                mapView.addOverlay(polygon)
            } else if points.count == 2 {
                let polyline = MKPolyline(coordinates: points, count: points.count)
                currentPolyline = polyline
                mapView.addOverlay(polyline)
            }
        }
        
        private func updateMeasurements() {
            let points = parent.polygonPoints
            guard points.count >= 3 else {
                DispatchQueue.main.async {
                    self.parent.currentArea = 0.0
                    self.parent.currentPerimeter = 0.0
                }
                return
            }
            
            let area = calculateArea(coordinates: points)
            let perimeter = calculatePerimeter(coordinates: points)
            
            DispatchQueue.main.async {
                self.parent.currentArea = area
                self.parent.currentPerimeter = perimeter
            }
        }
        
        private func calculateArea(coordinates: [CLLocationCoordinate2D]) -> Double {
            guard coordinates.count >= 3 else { return 0.0 }
            
            let earthRadius = 6371000.0
            var area = 0.0
            let coordCount = coordinates.count
            
            for i in 0..<coordCount {
                let j = (i + 1) % coordCount
                let xi = coordinates[i].longitude * .pi / 180
                let yi = coordinates[i].latitude * .pi / 180
                let xj = coordinates[j].longitude * .pi / 180
                let yj = coordinates[j].latitude * .pi / 180
                
                area += (xj - xi) * (2 + sin(yi) + sin(yj))
            }
            
            area = abs(area) * earthRadius * earthRadius / 2
            return area * 0.000247105
        }
        
        private func calculatePerimeter(coordinates: [CLLocationCoordinate2D]) -> Double {
            guard coordinates.count >= 2 else { return 0.0 }
            
            var perimeter = 0.0
            for i in 0..<coordinates.count {
                let nextIndex = (i + 1) % coordinates.count
                let location1 = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
                let location2 = CLLocation(latitude: coordinates[nextIndex].latitude, longitude: coordinates[nextIndex].longitude)
                perimeter += location1.distance(from: location2)
            }
            
            // Convert meters to feet
            return perimeter * 3.28084
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                
                // Calculate zoom-responsive line width
                let baseLineWidth: CGFloat = 3.0
                let zoomLevel = log2(360 / mapView.region.span.longitudeDelta)
                let scaleFactor = max(0.8, min(2.5, zoomLevel / 12.0))
                let adjustedLineWidth = baseLineWidth * scaleFactor
                
                // Check if this is the current drawing polygon or a saved polygon
                if polygon === currentPolygon {
                    // Current drawing polygon - always use green
                    let drawingColor = UIColor(red: 0.0, green: 0.9, blue: 0.0, alpha: 1.0)
                    renderer.fillColor = drawingColor.withAlphaComponent(0.3)
                    renderer.strokeColor = drawingColor
                    renderer.lineWidth = adjustedLineWidth
                } else {
                    // Find the work area for this polygon
                    let workAreaId = savedPolygons.first(where: { $0.value === polygon })?.key
                    let isSelected = parent.selectedWorkArea?.id == workAreaId
                    
                    // All saved polygons are also green
                    let color = UIColor(red: 0.0, green: 0.9, blue: 0.0, alpha: 1.0)
                    
                    if isSelected {
                        // Selected: brighter fill and thicker border
                        renderer.fillColor = color.withAlphaComponent(0.6)
                        renderer.strokeColor = color
                        renderer.lineWidth = adjustedLineWidth * 1.3
                    } else {
                        // Normal: visible fill and solid border
                        renderer.fillColor = color.withAlphaComponent(0.45)
                        renderer.strokeColor = color
                        renderer.lineWidth = adjustedLineWidth * 0.8
                    }
                }
                return renderer
            } else if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                // Use green for the drawing line
                renderer.strokeColor = UIColor(red: 0.0, green: 0.9, blue: 0.0, alpha: 1.0)
                renderer.lineWidth = 3
                renderer.lineDashPattern = [8, 4]
                return renderer
            }
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let areaLabel = annotation as? AreaLabelAnnotation {
                // Area label annotation
                let identifier = "AreaLabel"
                var labelView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if labelView == nil {
                    labelView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    labelView?.canShowCallout = false
                }
                
                // Create label view
                let label = UILabel()
                label.text = areaLabel.title
                label.font = UIFont.boldSystemFont(ofSize: 16)
                label.textColor = .white
                label.backgroundColor = UIColor.black.withAlphaComponent(0.8)
                label.textAlignment = .center
                label.layer.cornerRadius = 8
                label.layer.masksToBounds = true
                label.sizeToFit()
                label.frame.size.width += 16
                label.frame.size.height += 8
                
                labelView?.frame = label.frame
                labelView?.addSubview(label)
                
                return labelView
            } else if annotation is MKPointAnnotation {
                // Drawing point markers
                let identifier = "DrawingPoint"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = false
                } else {
                    annotationView?.annotation = annotation
                }
                
                annotationView?.markerTintColor = UIColor.systemBlue
                annotationView?.glyphText = "\(pointAnnotations.firstIndex(where: { $0 === annotation }) ?? 0 + 1)"
                
                return annotationView
            }
            
            return nil
        }
    }
}