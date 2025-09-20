import SwiftUI
import MapKit
import CoreLocation

struct WorkAreaDisplay: Identifiable, Hashable {
    let id: UUID
    let name: String
    let coordinates: [CLLocationCoordinate2D]
    let area: Double
    let perimeter: Double
    let isSelected: Bool
    
    init(id: UUID = UUID(), name: String, coordinates: [CLLocationCoordinate2D], area: Double, perimeter: Double, isSelected: Bool = false) {
        self.id = id
        self.name = name
        self.coordinates = coordinates
        self.area = area
        self.perimeter = perimeter
        self.isSelected = isSelected
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
    
    var onPointAdded: ((CLLocationCoordinate2D) -> Void)?
    var onPolygonCompleted: (([CLLocationCoordinate2D]) -> Void)?
    var onWorkAreaTapped: ((WorkAreaDisplay) -> Void)?
    var onWorkAreaLongPressed: ((WorkAreaDisplay) -> Void)?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        mapView.mapType = .standard
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
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
        mapView.showsUserLocation = showUserLocation
        
        context.coordinator.updateDrawingMode(isDrawingMode)
        context.coordinator.updatePolygon(points: polygonPoints, mapView: mapView)
        context.coordinator.updateSavedWorkAreas(areas: savedWorkAreas, mapView: mapView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        var currentPolygon: MKPolygon?
        var pointAnnotations: [MKPointAnnotation] = []
        var savedPolygons: [UUID: MKPolygon] = [:]
        var savedCornerPins: [UUID: [MKPointAnnotation]] = [:]
        
        init(_ parent: MapView) {
            self.parent = parent
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
        
        func updateDrawingMode(_ isDrawing: Bool) {
            // Additional setup for drawing mode if needed
        }
        
        func updateSavedWorkAreas(areas: [WorkAreaDisplay], mapView: MKMapView) {
            // Remove old saved polygons and pins
            for polygon in savedPolygons.values {
                mapView.removeOverlay(polygon)
            }
            for pins in savedCornerPins.values {
                mapView.removeAnnotations(pins)
            }
            savedPolygons.removeAll()
            savedCornerPins.removeAll()
            
            // Add new saved work areas
            for area in areas {
                guard area.coordinates.count >= 3 else { continue }
                
                let polygon = MKPolygon(coordinates: area.coordinates, count: area.coordinates.count)
                polygon.title = area.name
                savedPolygons[area.id] = polygon
                mapView.addOverlay(polygon)
                
                // Add small corner pins for saved polygons
                var cornerPins: [MKPointAnnotation] = []
                for (index, coordinate) in area.coordinates.enumerated() {
                    let pin = MKPointAnnotation()
                    pin.coordinate = coordinate
                    pin.title = area.name
                    pin.subtitle = "Corner \(index + 1)"
                    cornerPins.append(pin)
                }
                savedCornerPins[area.id] = cornerPins
                mapView.addAnnotations(cornerPins)
            }
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
            
            return perimeter
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                
                // Check if this is the current drawing polygon or a saved polygon
                if polygon === currentPolygon {
                    // Current drawing polygon - bright blue
                    renderer.fillColor = UIColor.blue.withAlphaComponent(0.3)
                    renderer.strokeColor = UIColor.blue
                    renderer.lineWidth = 3
                } else {
                    // Saved polygon - more subtle styling
                    let workAreaId = savedPolygons.first(where: { $0.value === polygon })?.key
                    let isSelected = workAreaId.map { id in
                        parent.selectedWorkArea?.id == id
                    } ?? false
                    
                    if isSelected {
                        renderer.fillColor = UIColor.green.withAlphaComponent(0.25)
                        renderer.strokeColor = UIColor.green
                        renderer.lineWidth = 2
                    } else {
                        renderer.fillColor = UIColor.gray.withAlphaComponent(0.15)
                        renderer.strokeColor = UIColor.gray
                        renderer.lineWidth = 1.5
                    }
                }
                return renderer
            } else if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.blue
                renderer.lineWidth = 2
                renderer.lineDashPattern = [5, 5]
                return renderer
            }
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let pointAnnotation = annotation as? MKPointAnnotation else { return nil }
            
            // Check if this is a drawing point or a saved corner pin
            let isDrawingPoint = pointAnnotations.contains(pointAnnotation)
            
            if isDrawingPoint {
                // Large markers for current drawing
                let identifier = "DrawingPoint"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = false
                } else {
                    annotationView?.annotation = annotation
                }
                
                annotationView?.markerTintColor = UIColor.blue
                annotationView?.glyphText = "\(pointAnnotations.firstIndex(where: { $0 === annotation }) ?? 0 + 1)"
                
                return annotationView
            } else {
                // Small corner pins for saved polygons
                let identifier = "CornerPin"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }
                
                // Small, subtle corner pins
                annotationView?.markerTintColor = UIColor.gray
                annotationView?.glyphText = ""
                annotationView?.frame.size = CGSize(width: 8, height: 8)
                
                return annotationView
            }
        }
    }
}