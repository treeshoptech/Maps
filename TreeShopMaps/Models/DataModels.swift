import Foundation
import CoreData
import CoreLocation
import CloudKit

// MARK: - Core Data Stack Manager
class DataStackManager {
    static let shared = DataStackManager()
    
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "TreeShopMaps")
        
        // Configure for CloudKit sync
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Configure CloudKit container
            storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.treeshop.maps"
            )
        }
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load persistent stores: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    func save() {
        guard viewContext.hasChanges else { return }
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }
}

// MARK: - User Profile Extensions
extension UserProfile {
    var displayName: String {
        if let firstName = firstName, let lastName = lastName {
            return "\(firstName) \(lastName)"
        } else if let firstName = firstName {
            return firstName
        } else if let email = email {
            return email
        } else {
            return "TreeShop User"
        }
    }
    
    var initials: String {
        let components = displayName.components(separatedBy: " ")
        let firstInitial = components.first?.first ?? "T"
        let lastInitial = components.count > 1 ? components.last?.first ?? "U" : "U"
        return "\(firstInitial)\(lastInitial)".uppercased()
    }
    
    static func current(in context: NSManagedObjectContext) -> UserProfile? {
        guard let appleID = UserDefaults.standard.string(forKey: "appleUserID") else { return nil }
        
        let request: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        request.predicate = NSPredicate(format: "appleID == %@", appleID)
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
}

// MARK: - Saved Location Model
@objc(SavedLocation)
public class SavedLocation: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var address: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var category: String
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var isFavorite: Bool
    @NSManaged public var visitCount: Int32
    @NSManaged public var lastVisitedAt: Date?
    @NSManaged public var customIcon: String?
    @NSManaged public var color: String?
    @NSManaged public var tags: Set<String>?
    @NSManaged public var user: UserProfile?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var systemIconName: String {
        customIcon ?? LocationCategory(rawValue: category)?.icon ?? "mappin.circle.fill"
    }
    
    var displayColor: String {
        color ?? LocationCategory(rawValue: category)?.color ?? "blue"
    }
}

// MARK: - Location Categories
enum LocationCategory: String, CaseIterable {
    case home = "home"
    case work = "work"
    case favorite = "favorite"
    case restaurant = "restaurant"
    case shopping = "shopping"
    case entertainment = "entertainment"
    case travel = "travel"
    case parking = "parking"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .home: return "Home"
        case .work: return "Work"
        case .favorite: return "Favorite"
        case .restaurant: return "Restaurant"
        case .shopping: return "Shopping"
        case .entertainment: return "Entertainment"
        case .travel: return "Travel"
        case .parking: return "Parking"
        case .custom: return "Custom"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        case .favorite: return "heart.fill"
        case .restaurant: return "fork.knife"
        case .shopping: return "bag.fill"
        case .entertainment: return "star.fill"
        case .travel: return "airplane"
        case .parking: return "car.fill"
        case .custom: return "mappin.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .home: return "blue"
        case .work: return "purple"
        case .favorite: return "red"
        case .restaurant: return "orange"
        case .shopping: return "green"
        case .entertainment: return "yellow"
        case .travel: return "cyan"
        case .parking: return "gray"
        case .custom: return "indigo"
        }
    }
}

// MARK: - Search History Model
@objc(SearchHistory)
public class SearchHistory: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var query: String
    @NSManaged public var timestamp: Date
    @NSManaged public var resultCount: Int32
    @NSManaged public var selectedResultIndex: Int32
    @NSManaged public var searchType: String // text, voice, suggestion
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var user: UserProfile?
}

// MARK: - Offline Map Region
@objc(OfflineMapRegion)
public class OfflineMapRegion: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var minLatitude: Double
    @NSManaged public var maxLatitude: Double
    @NSManaged public var minLongitude: Double
    @NSManaged public var maxLongitude: Double
    @NSManaged public var zoomLevelMin: Int16
    @NSManaged public var zoomLevelMax: Int16
    @NSManaged public var downloadedAt: Date
    @NSManaged public var lastUpdatedAt: Date
    @NSManaged public var sizeInBytes: Int64
    @NSManaged public var tileCount: Int32
    @NSManaged public var downloadProgress: Float
    @NSManaged public var isDownloading: Bool
    @NSManaged public var expiresAt: Date?
    @NSManaged public var user: UserProfile?
    
    var region: MKCoordinateRegion {
        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: maxLatitude - minLatitude,
            longitudeDelta: maxLongitude - minLongitude
        )
        return MKCoordinateRegion(center: center, span: span)
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeInBytes)
    }
}

// MARK: - User Statistics
@objc(UserStatistics)
public class UserStatistics: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var totalSearches: Int32
    @NSManaged public var totalSavedLocations: Int32
    @NSManaged public var totalDistance: Double // in meters
    @NSManaged public var totalNavigations: Int32
    @NSManaged public var favoriteCategory: String?
    @NSManaged public var mostVisitedLocationID: UUID?
    @NSManaged public var streakDays: Int32
    @NSManaged public var lastActiveDate: Date
    @NSManaged public var achievementsUnlocked: Set<String>?
    @NSManaged public var user: UserProfile?
    
    func incrementSearch() {
        totalSearches += 1
    }
    
    func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastActive = calendar.startOfDay(for: lastActiveDate)
        
        let daysBetween = calendar.dateComponents([.day], from: lastActive, to: today).day ?? 0
        
        if daysBetween == 1 {
            streakDays += 1
        } else if daysBetween > 1 {
            streakDays = 1
        }
        
        lastActiveDate = Date()
    }
}

// MARK: - User Preferences (Extended)
extension UserPreferences {
    enum MapType: String {
        case standard = "standard"
        case satellite = "satellite"
        case hybrid = "hybrid"
        case terrain = "terrain"
    }
    
    enum DistanceUnit: String {
        case kilometers = "km"
        case miles = "mi"
    }
    
    enum NavigationVoice: String {
        case default = "default"
        case male = "male"
        case female = "female"
        case disabled = "disabled"
    }
    
    var mapTypeEnum: MapType {
        get { MapType(rawValue: defaultMapType ?? "standard") ?? .standard }
        set { defaultMapType = newValue.rawValue }
    }
    
    var distanceUnitEnum: DistanceUnit {
        get { DistanceUnit(rawValue: distanceUnit ?? "km") ?? .kilometers }
        set { distanceUnit = newValue.rawValue }
    }
    
    var navigationVoiceEnum: NavigationVoice {
        get { NavigationVoice(rawValue: navigationVoice ?? "default") ?? .default }
        set { navigationVoice = newValue.rawValue }
    }
}

// MARK: - Sync Metadata
@objc(SyncMetadata)
public class SyncMetadata: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var entityName: String
    @NSManaged public var recordID: String
    @NSManaged public var lastSyncedAt: Date
    @NSManaged public var syncStatus: String // pending, synced, conflict, error
    @NSManaged public var conflictData: Data?
    @NSManaged public var errorMessage: String?
    @NSManaged public var retryCount: Int16
    @NSManaged public var user: UserProfile?
}

// MARK: - Achievement Model
struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let requiredValue: Int
    let category: AchievementCategory
    
    enum AchievementCategory {
        case exploration
        case navigation
        case social
        case collection
    }
}

// Achievement definitions
extension Achievement {
    static let allAchievements: [Achievement] = [
        Achievement(id: "first_search", title: "First Steps", description: "Perform your first search", icon: "magnifyingglass.circle.fill", requiredValue: 1, category: .exploration),
        Achievement(id: "saved_10", title: "Collector", description: "Save 10 locations", icon: "bookmark.fill", requiredValue: 10, category: .collection),
        Achievement(id: "saved_50", title: "Explorer", description: "Save 50 locations", icon: "map.fill", requiredValue: 50, category: .collection),
        Achievement(id: "streak_7", title: "Week Warrior", description: "Use the app 7 days in a row", icon: "flame.fill", requiredValue: 7, category: .exploration),
        Achievement(id: "streak_30", title: "Monthly Master", description: "Use the app 30 days in a row", icon: "star.circle.fill", requiredValue: 30, category: .exploration),
        Achievement(id: "distance_100km", title: "Century", description: "Travel 100km using navigation", icon: "location.fill", requiredValue: 100000, category: .navigation),
        Achievement(id: "offline_maps_5", title: "Offline Explorer", description: "Download 5 offline map regions", icon: "arrow.down.circle.fill", requiredValue: 5, category: .collection)
    ]
}

// MARK: - Project Extensions
extension Project {
    enum ServiceType: String, CaseIterable {
        case forestryMulching = "forestry_mulching"
        case landClearing = "land_clearing"
        case lotClearing = "lot_clearing"
        
        var displayName: String {
            switch self {
            case .forestryMulching: return "Forestry Mulching"
            case .landClearing: return "Land Clearing"
            case .lotClearing: return "Lot Clearing"
            }
        }
    }
    
    enum ProjectStatus: String, CaseIterable {
        case draft = "draft"
        case active = "active"
        case complete = "complete"
        case paused = "paused"
        
        var displayName: String {
            switch self {
            case .draft: return "Draft"
            case .active: return "Active"
            case .complete: return "Complete"
            case .paused: return "Paused"
            }
        }
        
        var color: String {
            switch self {
            case .draft: return "gray"
            case .active: return "blue"
            case .complete: return "green"
            case .paused: return "orange"
            }
        }
    }
    
    enum TerrainType: String, CaseIterable {
        case flat = "flat"
        case rolling = "rolling"
        case hilly = "hilly"
        case steep = "steep"
        
        var displayName: String {
            switch self {
            case .flat: return "Flat"
            case .rolling: return "Rolling"
            case .hilly: return "Hilly"
            case .steep: return "Steep"
            }
        }
        
        var difficultyMultiplier: Double {
            switch self {
            case .flat: return 1.0
            case .rolling: return 1.2
            case .hilly: return 1.5
            case .steep: return 2.0
            }
        }
    }
    
    var serviceTypeEnum: ServiceType {
        get { ServiceType(rawValue: serviceType ?? "forestry_mulching") ?? .forestryMulching }
        set { serviceType = newValue.rawValue }
    }
    
    var statusEnum: ProjectStatus {
        get { ProjectStatus(rawValue: projectStatus ?? "draft") ?? .draft }
        set { projectStatus = newValue.rawValue }
    }
    
    var terrainEnum: TerrainType {
        get { TerrainType(rawValue: terrainType ?? "flat") ?? .flat }
        set { terrainType = newValue.rawValue }
    }
    
    func calculateInchAcres() -> Double {
        guard totalAcres > 0, averageDBH > 0 else { return 0.0 }
        return totalAcres * averageDBH * terrainEnum.difficultyMultiplier
    }
}

// MARK: - Work Area Extensions
extension WorkArea {
    var coordinates: [CLLocationCoordinate2D] {
        get {
            guard let data = polygonData else { return [] }
            return decodeCoordinates(from: data)
        }
        set {
            polygonData = encodeCoordinates(newValue)
            updateCalculatedValues(for: newValue)
        }
    }
    
    var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }
    
    private func encodeCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> Data? {
        let coordinateData = coordinates.map { ["lat": $0.latitude, "lng": $0.longitude] }
        return try? JSONSerialization.data(withJSONObject: coordinateData)
    }
    
    private func decodeCoordinates(from data: Data) -> [CLLocationCoordinate2D] {
        guard let coordinateData = try? JSONSerialization.jsonObject(with: data) as? [[String: Double]] else {
            return []
        }
        
        return coordinateData.compactMap { dict in
            guard let lat = dict["lat"], let lng = dict["lng"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
    }
    
    private func updateCalculatedValues(for coordinates: [CLLocationCoordinate2D]) {
        guard coordinates.count >= 3 else {
            areaAcres = 0.0
            perimeterMeters = 0.0
            return
        }
        
        areaAcres = calculateArea(coordinates: coordinates)
        perimeterMeters = calculatePerimeter(coordinates: coordinates)
        
        let bounds = calculateBounds(coordinates: coordinates)
        centerLatitude = bounds.center.latitude
        centerLongitude = bounds.center.longitude
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
    
    private func calculateBounds(coordinates: [CLLocationCoordinate2D]) -> (center: CLLocationCoordinate2D, span: MKCoordinateSpan) {
        guard !coordinates.isEmpty else {
            return (CLLocationCoordinate2D(), MKCoordinateSpan())
        }
        
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLng = longitudes.min() ?? 0
        let maxLng = longitudes.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.1,
            longitudeDelta: (maxLng - minLng) * 1.1
        )
        
        return (center, span)
    }
}