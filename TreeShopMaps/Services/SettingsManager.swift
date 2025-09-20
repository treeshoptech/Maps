import SwiftUI
import Combine
import MapKit

// MARK: - Settings Manager
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // MARK: - Map Settings
    @AppStorage("mapType") var mapType: String = "standard" {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("showTraffic") var showTraffic: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("show3DBuildings") var show3DBuildings: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("showPointsOfInterest") var showPointsOfInterest: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("showCompass") var showCompass: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("showScale") var showScale: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("mapPitchEnabled") var mapPitchEnabled: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    // MARK: - Navigation Settings
    @AppStorage("avoidTolls") var avoidTolls: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("avoidHighways") var avoidHighways: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("avoidFerries") var avoidFerries: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("preferredTransportMode") var preferredTransportMode: String = "automobile" {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("voiceNavigation") var voiceNavigation: String = "default" {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("voiceVolume") var voiceVolume: Double = 0.8 {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("pauseSpokenAudioDuringNavigation") var pauseSpokenAudioDuringNavigation: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    // MARK: - Units & Formats
    @AppStorage("distanceUnit") var distanceUnit: String = "automatic" {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("temperatureUnit") var temperatureUnit: String = "celsius" {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("timeFormat") var timeFormat: String = "12hour" {
        didSet { objectWillChange.send() }
    }
    
    // MARK: - Privacy Settings
    @AppStorage("locationServices") var locationServices: Bool = true {
        didSet { 
            objectWillChange.send()
            updateLocationServices()
        }
    }
    
    @AppStorage("preciseLocation") var preciseLocation: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("syncWithiCloud") var syncWithiCloud: Bool = true {
        didSet { 
            objectWillChange.send()
            updateCloudKitSync()
        }
    }
    
    @AppStorage("shareAnalytics") var shareAnalytics: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("personalizedAds") var personalizedAds: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("significantLocations") var significantLocations: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    // MARK: - Notification Settings
    @AppStorage("enableNotifications") var enableNotifications: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("trafficAlerts") var trafficAlerts: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("timeToLeaveAlerts") var timeToLeaveAlerts: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("parkingReminders") var parkingReminders: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("speedLimitWarnings") var speedLimitWarnings: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("notificationSound") var notificationSound: String = "default" {
        didSet { objectWillChange.send() }
    }
    
    // MARK: - Display Settings
    @AppStorage("themeMode") var themeMode: String = "dark" {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("autoNightMode") var autoNightMode: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("reducedMotion") var reducedMotion: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("highContrastMode") var highContrastMode: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("largeFonts") var largeFonts: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    // MARK: - Data Management
    @AppStorage("offlineMapQuality") var offlineMapQuality: String = "standard" {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("offlineMapAutoUpdate") var offlineMapAutoUpdate: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("offlineMapUpdateOnWiFiOnly") var offlineMapUpdateOnWiFiOnly: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("searchHistoryEnabled") var searchHistoryEnabled: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("searchHistoryDuration") var searchHistoryDuration: Int = 30 {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("cacheSize") var cacheSize: Int = 500 {
        didSet { objectWillChange.send() }
    }
    
    // MARK: - Advanced Settings
    @AppStorage("developerMode") var developerMode: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("showDebugInfo") var showDebugInfo: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("experimentalFeatures") var experimentalFeatures: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("betaFeatures") var betaFeatures: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    // MARK: - Computed Properties
    var mapStyleType: MKMapType {
        switch mapType {
        case "satellite":
            return .satellite
        case "hybrid":
            return .hybrid
        case "satelliteFlyover":
            return .satelliteFlyover
        case "hybridFlyover":
            return .hybridFlyover
        case "mutedStandard":
            return .mutedStandard
        default:
            return .standard
        }
    }
    
    var transportType: MKDirectionsTransportType {
        switch preferredTransportMode {
        case "walking":
            return .walking
        case "transit":
            return .transit
        default:
            return .automobile
        }
    }
    
    var distanceFormatter: MeasurementFormatter {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        
        switch distanceUnit {
        case "miles":
            formatter.locale = Locale(identifier: "en_US")
        case "kilometers":
            formatter.locale = Locale(identifier: "en_GB")
        default:
            formatter.locale = Locale.current
        }
        
        return formatter
    }
    
    // MARK: - Methods
    private init() {
        setupDefaults()
    }
    
    private func setupDefaults() {
        // Set default values if first launch
        if UserDefaults.standard.object(forKey: "hasLaunchedBefore") == nil {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            resetToDefaults()
        }
    }
    
    func resetToDefaults() {
        // Map Settings
        mapType = "standard"
        showTraffic = false
        show3DBuildings = true
        showPointsOfInterest = true
        showCompass = true
        showScale = true
        mapPitchEnabled = true
        
        // Navigation
        avoidTolls = false
        avoidHighways = false
        avoidFerries = false
        preferredTransportMode = "automobile"
        voiceNavigation = "default"
        voiceVolume = 0.8
        
        // Units
        distanceUnit = "automatic"
        temperatureUnit = "celsius"
        timeFormat = "12hour"
        
        // Privacy
        locationServices = true
        preciseLocation = true
        syncWithiCloud = true
        shareAnalytics = false
        personalizedAds = false
        
        // Notifications
        enableNotifications = true
        trafficAlerts = true
        timeToLeaveAlerts = true
        parkingReminders = true
        speedLimitWarnings = false
        
        // Display
        themeMode = "dark"
        autoNightMode = false
        reducedMotion = false
        highContrastMode = false
        largeFonts = false
        
        // Data Management
        offlineMapQuality = "standard"
        offlineMapAutoUpdate = true
        offlineMapUpdateOnWiFiOnly = true
        searchHistoryEnabled = true
        searchHistoryDuration = 30
        cacheSize = 500
        
        // Advanced
        developerMode = false
        showDebugInfo = false
        experimentalFeatures = false
        betaFeatures = false
    }
    
    private func updateLocationServices() {
        if !locationServices {
            // Disable location-dependent features
            preciseLocation = false
            significantLocations = false
        }
    }
    
    private func updateCloudKitSync() {
        if syncWithiCloud {
            CloudKitSyncManager.shared.enableSync()
        } else {
            CloudKitSyncManager.shared.disableSync()
        }
    }
    
    func clearCache() {
        // Clear map cache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear image cache
        if let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            try? FileManager.default.removeItem(at: cacheURL)
        }
    }
    
    func clearSearchHistory() {
        let context = DataStackManager.shared.viewContext
        let request: NSFetchRequest<NSFetchRequest<NSFetchRequestResult>> = SearchHistory.fetchRequest() as! NSFetchRequest<NSFetchRequestResult>
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Failed to clear search history: \(error)")
        }
    }
    
    func exportSettings() -> Data? {
        let settings: [String: Any] = [
            "mapType": mapType,
            "showTraffic": showTraffic,
            "show3DBuildings": show3DBuildings,
            "distanceUnit": distanceUnit,
            "voiceNavigation": voiceNavigation,
            "themeMode": themeMode,
            "enableNotifications": enableNotifications,
            "syncWithiCloud": syncWithiCloud
        ]
        
        return try? JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
    }
    
    func importSettings(from data: Data) {
        guard let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        if let value = settings["mapType"] as? String { mapType = value }
        if let value = settings["showTraffic"] as? Bool { showTraffic = value }
        if let value = settings["show3DBuildings"] as? Bool { show3DBuildings = value }
        if let value = settings["distanceUnit"] as? String { distanceUnit = value }
        if let value = settings["voiceNavigation"] as? String { voiceNavigation = value }
        if let value = settings["themeMode"] as? String { themeMode = value }
        if let value = settings["enableNotifications"] as? Bool { enableNotifications = value }
        if let value = settings["syncWithiCloud"] as? Bool { syncWithiCloud = value }
    }
}

// MARK: - Settings Categories
enum SettingsCategory: String, CaseIterable {
    case map = "Map"
    case navigation = "Navigation"
    case units = "Units & Formats"
    case privacy = "Privacy"
    case notifications = "Notifications"
    case display = "Display"
    case dataManagement = "Data Management"
    case advanced = "Advanced"
    
    var icon: String {
        switch self {
        case .map: return "map"
        case .navigation: return "location.north.line"
        case .units: return "ruler"
        case .privacy: return "lock.shield"
        case .notifications: return "bell"
        case .display: return "paintbrush"
        case .dataManagement: return "externaldrive"
        case .advanced: return "gearshape.2"
        }
    }
    
    var description: String {
        switch self {
        case .map: return "Configure map appearance and behavior"
        case .navigation: return "Set navigation preferences and voice guidance"
        case .units: return "Choose measurement units and formats"
        case .privacy: return "Manage location and data privacy"
        case .notifications: return "Control alerts and reminders"
        case .display: return "Customize visual appearance"
        case .dataManagement: return "Manage storage and sync settings"
        case .advanced: return "Developer and experimental features"
        }
    }
}