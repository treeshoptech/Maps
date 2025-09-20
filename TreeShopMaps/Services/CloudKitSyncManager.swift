import Foundation
import CloudKit
import CoreData
import Combine

// MARK: - CloudKit Sync Manager
class CloudKitSyncManager: ObservableObject {
    static let shared = CloudKitSyncManager()
    
    // MARK: - Published Properties
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var syncProgress: Double = 0.0
    @Published var isSyncEnabled: Bool = true
    @Published var pendingOperations: Int = 0
    @Published var syncErrors: [SyncError] = []
    
    // MARK: - CloudKit Configuration
    private let container = CKContainer(identifier: "iCloud.com.treeshop.maps")
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    
    // Custom zones for different data types
    private let userDataZone = CKRecordZone(zoneName: "UserData")
    private let locationsZone = CKRecordZone(zoneName: "SavedLocations")
    private let offlineMapsZone = CKRecordZone(zoneName: "OfflineMaps")
    private let searchHistoryZone = CKRecordZone(zoneName: "SearchHistory")
    
    // Sync queue for offline operations
    private var syncQueue: [SyncOperation] = []
    private let syncQueueLock = NSLock()
    
    // Timers for sync
    private var criticalSyncTimer: Timer?
    private var batchSyncTimer: Timer?
    
    // Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        privateDatabase = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
        
        setupCloudKitSubscriptions()
        setupTimers()
        loadSyncState()
    }
    
    // MARK: - Zone Setup
    func setupCustomZones() async throws {
        let zones = [userDataZone, locationsZone, offlineMapsZone, searchHistoryZone]
        
        for zone in zones {
            do {
                try await privateDatabase.save(zone)
            } catch let error as CKError where error.code == .zoneNotFound {
                // Zone doesn't exist, create it
                try await createZone(zone)
            }
        }
    }
    
    private func createZone(_ zone: CKRecordZone) async throws {
        _ = try await privateDatabase.save(zone)
    }
    
    // MARK: - Sync Status
    enum SyncStatus: String {
        case idle = "Idle"
        case syncing = "Syncing"
        case uploading = "Uploading"
        case downloading = "Downloading"
        case conflict = "Resolving Conflicts"
        case error = "Error"
        case offline = "Offline"
        
        var icon: String {
            switch self {
            case .idle: return "checkmark.circle.fill"
            case .syncing: return "arrow.triangle.2.circlepath"
            case .uploading: return "icloud.and.arrow.up"
            case .downloading: return "icloud.and.arrow.down"
            case .conflict: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .offline: return "icloud.slash"
            }
        }
    }
    
    // MARK: - Sync Operations
    struct SyncOperation: Identifiable {
        let id = UUID()
        let type: OperationType
        let recordType: String
        let recordID: String
        let data: Data
        let timestamp: Date
        var retryCount: Int = 0
        
        enum OperationType {
            case create, update, delete
        }
    }
    
    // MARK: - Sync Errors
    struct SyncError: Identifiable {
        let id = UUID()
        let message: String
        let timestamp: Date
        let recordType: String?
        let isRecoverable: Bool
    }
    
    // MARK: - Timer Setup
    private func setupTimers() {
        // Critical data sync every 5 seconds
        criticalSyncTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await self.syncCriticalData()
            }
        }
        
        // Batch sync every 30 seconds
        batchSyncTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await self.performBatchSync()
            }
        }
    }
    
    // MARK: - CloudKit Subscriptions
    private func setupCloudKitSubscriptions() {
        Task {
            await setupSubscription(for: "SavedLocation", in: locationsZone)
            await setupSubscription(for: "UserProfile", in: userDataZone)
            await setupSubscription(for: "OfflineMapRegion", in: offlineMapsZone)
        }
    }
    
    private func setupSubscription(for recordType: String, in zone: CKRecordZone) async {
        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: NSPredicate(value: true),
            subscriptionID: "\(recordType)_subscription",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        subscription.zoneID = zone.zoneID
        
        do {
            _ = try await privateDatabase.save(subscription)
        } catch {
            print("Failed to setup subscription for \(recordType): \(error)")
        }
    }
    
    // MARK: - Sync Methods
    func performFullSync() async {
        guard isSyncEnabled else { return }
        
        syncStatus = .syncing
        syncProgress = 0.0
        
        do {
            // Setup zones if needed
            try await setupCustomZones()
            
            // Sync each data type
            syncProgress = 0.2
            await syncUserProfile()
            
            syncProgress = 0.4
            await syncSavedLocations()
            
            syncProgress = 0.6
            await syncSearchHistory()
            
            syncProgress = 0.8
            await syncOfflineMaps()
            
            syncProgress = 1.0
            lastSyncDate = Date()
            syncStatus = .idle
            
            // Save sync state
            saveSyncState()
            
        } catch {
            handleSyncError(error)
        }
    }
    
    private func syncCriticalData() async {
        guard isSyncEnabled else { return }
        
        // Sync only critical data like recent changes
        await syncRecentChanges()
    }
    
    private func performBatchSync() async {
        guard isSyncEnabled else { return }
        
        // Process queued operations
        await processSyncQueue()
    }
    
    // MARK: - Data Type Specific Sync
    private func syncUserProfile() async {
        let context = DataStackManager.shared.viewContext
        
        guard let currentUser = UserProfile.current(in: context) else { return }
        
        let record = CKRecord(recordType: "UserProfile", recordID: CKRecord.ID(recordName: currentUser.id?.uuidString ?? UUID().uuidString, zoneID: userDataZone.zoneID))
        
        // Map Core Data to CloudKit
        record["firstName"] = currentUser.firstName
        record["lastName"] = currentUser.lastName
        record["email"] = currentUser.email
        record["profileImageData"] = currentUser.profileImageData
        record["updatedAt"] = currentUser.updatedAt
        
        do {
            _ = try await privateDatabase.save(record)
        } catch {
            queueOperation(.update, recordType: "UserProfile", record: record)
        }
    }
    
    private func syncSavedLocations() async {
        let context = DataStackManager.shared.viewContext
        let request: NSFetchRequest<SavedLocation> = SavedLocation.fetchRequest()
        
        do {
            let locations = try context.fetch(request)
            
            for location in locations {
                let record = locationToRecord(location)
                
                do {
                    _ = try await privateDatabase.save(record)
                } catch {
                    queueOperation(.update, recordType: "SavedLocation", record: record)
                }
            }
        } catch {
            print("Failed to fetch saved locations: \(error)")
        }
    }
    
    private func syncSearchHistory() async {
        let context = DataStackManager.shared.viewContext
        let request: NSFetchRequest<SearchHistory> = SearchHistory.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp >= %@", Date().addingTimeInterval(-7 * 24 * 60 * 60) as NSDate)
        
        do {
            let searches = try context.fetch(request)
            
            for search in searches {
                let record = searchToRecord(search)
                
                do {
                    _ = try await privateDatabase.save(record)
                } catch {
                    queueOperation(.update, recordType: "SearchHistory", record: record)
                }
            }
        } catch {
            print("Failed to fetch search history: \(error)")
        }
    }
    
    private func syncOfflineMaps() async {
        let context = DataStackManager.shared.viewContext
        let request: NSFetchRequest<OfflineMapRegion> = OfflineMapRegion.fetchRequest()
        
        do {
            let maps = try context.fetch(request)
            
            for map in maps {
                let record = offlineMapToRecord(map)
                
                do {
                    _ = try await privateDatabase.save(record)
                } catch {
                    queueOperation(.update, recordType: "OfflineMapRegion", record: record)
                }
            }
        } catch {
            print("Failed to fetch offline maps: \(error)")
        }
    }
    
    // MARK: - Record Conversion
    private func locationToRecord(_ location: SavedLocation) -> CKRecord {
        let record = CKRecord(recordType: "SavedLocation", recordID: CKRecord.ID(recordName: location.id.uuidString, zoneID: locationsZone.zoneID))
        
        record["name"] = location.name
        record["address"] = location.address
        record["latitude"] = location.latitude
        record["longitude"] = location.longitude
        record["category"] = location.category
        record["notes"] = location.notes
        record["isFavorite"] = location.isFavorite
        record["visitCount"] = Int(location.visitCount)
        record["customIcon"] = location.customIcon
        record["color"] = location.color
        record["updatedAt"] = location.updatedAt
        
        if let tags = location.tags {
            record["tags"] = Array(tags)
        }
        
        return record
    }
    
    private func searchToRecord(_ search: SearchHistory) -> CKRecord {
        let record = CKRecord(recordType: "SearchHistory", recordID: CKRecord.ID(recordName: search.id.uuidString, zoneID: searchHistoryZone.zoneID))
        
        record["query"] = search.query
        record["timestamp"] = search.timestamp
        record["resultCount"] = Int(search.resultCount)
        record["searchType"] = search.searchType
        record["latitude"] = search.latitude
        record["longitude"] = search.longitude
        
        return record
    }
    
    private func offlineMapToRecord(_ map: OfflineMapRegion) -> CKRecord {
        let record = CKRecord(recordType: "OfflineMapRegion", recordID: CKRecord.ID(recordName: map.id.uuidString, zoneID: offlineMapsZone.zoneID))
        
        record["name"] = map.name
        record["minLatitude"] = map.minLatitude
        record["maxLatitude"] = map.maxLatitude
        record["minLongitude"] = map.minLongitude
        record["maxLongitude"] = map.maxLongitude
        record["zoomLevelMin"] = Int(map.zoomLevelMin)
        record["zoomLevelMax"] = Int(map.zoomLevelMax)
        record["sizeInBytes"] = Int(map.sizeInBytes)
        record["lastUpdatedAt"] = map.lastUpdatedAt
        
        return record
    }
    
    // MARK: - Conflict Resolution
    func resolveConflict(local: NSManagedObject, remote: CKRecord) -> NSManagedObject {
        // Implement last-writer-wins strategy with field-level merge
        guard let localUpdatedAt = local.value(forKey: "updatedAt") as? Date,
              let remoteUpdatedAt = remote["updatedAt"] as? Date else {
            return local
        }
        
        if remoteUpdatedAt > localUpdatedAt {
            // Remote is newer, update local
            updateLocalFromRemote(local: local, remote: remote)
        }
        
        return local
    }
    
    private func updateLocalFromRemote(local: NSManagedObject, remote: CKRecord) {
        // Map CloudKit fields back to Core Data
        switch remote.recordType {
        case "SavedLocation":
            if let location = local as? SavedLocation {
                location.name = remote["name"] as? String ?? location.name
                location.address = remote["address"] as? String
                location.notes = remote["notes"] as? String
                location.isFavorite = remote["isFavorite"] as? Bool ?? false
                location.updatedAt = remote["updatedAt"] as? Date ?? Date()
            }
        default:
            break
        }
        
        DataStackManager.shared.save()
    }
    
    // MARK: - Queue Management
    private func queueOperation(_ type: SyncOperation.OperationType, recordType: String, record: CKRecord) {
        syncQueueLock.lock()
        defer { syncQueueLock.unlock() }
        
        let operation = SyncOperation(
            type: type,
            recordType: recordType,
            recordID: record.recordID.recordName,
            data: try! NSKeyedArchiver.archivedData(withRootObject: record, requiringSecureCoding: true),
            timestamp: Date()
        )
        
        syncQueue.append(operation)
        pendingOperations = syncQueue.count
    }
    
    private func processSyncQueue() async {
        syncQueueLock.lock()
        let operations = syncQueue
        syncQueue.removeAll()
        syncQueueLock.unlock()
        
        for operation in operations {
            await processOperation(operation)
        }
        
        pendingOperations = syncQueue.count
    }
    
    private func processOperation(_ operation: SyncOperation) async {
        guard let record = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKRecord.self, from: operation.data) else {
            return
        }
        
        do {
            switch operation.type {
            case .create, .update:
                _ = try await privateDatabase.save(record)
            case .delete:
                _ = try await privateDatabase.deleteRecord(withID: record.recordID)
            }
        } catch {
            // Re-queue with increased retry count
            if operation.retryCount < 3 {
                var retryOperation = operation
                retryOperation.retryCount += 1
                
                syncQueueLock.lock()
                syncQueue.append(retryOperation)
                syncQueueLock.unlock()
            } else {
                // Log permanent failure
                let syncError = SyncError(
                    message: "Failed to sync \(operation.recordType) after 3 retries",
                    timestamp: Date(),
                    recordType: operation.recordType,
                    isRecoverable: false
                )
                syncErrors.append(syncError)
            }
        }
    }
    
    // MARK: - Recent Changes Sync
    private func syncRecentChanges() async {
        let context = DataStackManager.shared.viewContext
        
        // Fetch recently modified objects
        let fiveSecondsAgo = Date().addingTimeInterval(-5)
        
        // Sync recently modified saved locations
        let locationRequest: NSFetchRequest<SavedLocation> = SavedLocation.fetchRequest()
        locationRequest.predicate = NSPredicate(format: "updatedAt >= %@", fiveSecondsAgo as NSDate)
        
        if let locations = try? context.fetch(locationRequest) {
            for location in locations {
                let record = locationToRecord(location)
                do {
                    _ = try await privateDatabase.save(record)
                } catch {
                    queueOperation(.update, recordType: "SavedLocation", record: record)
                }
            }
        }
    }
    
    // MARK: - State Persistence
    private func saveSyncState() {
        UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
        UserDefaults.standard.set(isSyncEnabled, forKey: "isSyncEnabled")
    }
    
    private func loadSyncState() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
        isSyncEnabled = UserDefaults.standard.bool(forKey: "isSyncEnabled")
    }
    
    // MARK: - Error Handling
    private func handleSyncError(_ error: Error) {
        syncStatus = .error
        
        let syncError = SyncError(
            message: error.localizedDescription,
            timestamp: Date(),
            recordType: nil,
            isRecoverable: true
        )
        
        syncErrors.append(syncError)
        
        // Attempt recovery after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.syncStatus = .idle
        }
    }
    
    // MARK: - Public Methods
    func enableSync() {
        isSyncEnabled = true
        saveSyncState()
        
        Task {
            await performFullSync()
        }
    }
    
    func disableSync() {
        isSyncEnabled = false
        syncStatus = .offline
        saveSyncState()
    }
    
    func clearSyncErrors() {
        syncErrors.removeAll()
    }
    
    deinit {
        criticalSyncTimer?.invalidate()
        batchSyncTimer?.invalidate()
    }
}