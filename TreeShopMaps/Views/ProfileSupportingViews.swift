import SwiftUI
import Charts
import MapKit

// MARK: - Enhanced Settings View
struct EnhancedSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = SettingsManager.shared
    @State private var selectedCategory: SettingsCategory = .map
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Category List
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(SettingsCategory.allCases, id: \.self) { category in
                                SettingsCategoryRow(
                                    category: category,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(item: $selectedCategory) { category in
                SettingsCategoryDetailView(category: category)
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct SettingsCategoryRow: View {
    let category: SettingsCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.rawValue)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text(category.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.gray.opacity(0.08))
            .cornerRadius(16)
        }
    }
}

struct SettingsCategoryDetailView: View {
    let category: SettingsCategory
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = SettingsManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        settingsContent
                    }
                    .padding()
                }
            }
            .navigationTitle(category.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    @ViewBuilder
    private var settingsContent: some View {
        switch category {
        case .map:
            MapSettingsContent()
        case .navigation:
            NavigationSettingsContent()
        case .units:
            UnitsSettingsContent()
        case .privacy:
            PrivacySettingsContent()
        case .notifications:
            NotificationSettingsContent()
        case .display:
            DisplaySettingsContent()
        case .dataManagement:
            DataManagementSettingsContent()
        case .advanced:
            AdvancedSettingsContent()
        }
    }
}

// MARK: - Offline Maps View
struct OfflineMapsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var downloadedMaps: [OfflineMapRegion] = []
    @State private var showingAddMap = false
    @State private var selectedMap: OfflineMapRegion?
    
    var totalSize: String {
        let bytes = downloadedMaps.reduce(0) { $0 + $1.sizeInBytes }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Storage Overview
                    StorageCard(
                        used: totalSize,
                        available: "2.3 GB",
                        total: "10 GB"
                    )
                    .padding()
                    
                    // Downloaded Maps List
                    if downloadedMaps.isEmpty {
                        emptyState
                    } else {
                        mapsList
                    }
                }
            }
            .navigationTitle("Offline Maps")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddMap = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAddMap) {
            AddOfflineMapView()
        }
        .sheet(item: $selectedMap) { map in
            OfflineMapDetailView(map: map)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "map.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Offline Maps")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Download maps to use them without an internet connection")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                showingAddMap = true
            }) {
                Label("Download Map", systemImage: "arrow.down.circle.fill")
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(25)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var mapsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(downloadedMaps) { map in
                    OfflineMapRow(map: map) {
                        selectedMap = map
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Statistics View
struct StatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeriod: StatsPeriod = .week
    @StateObject private var statsManager = StatsManager()
    
    enum StatsPeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All Time"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Period Selector
                        Picker("Period", selection: $selectedPeriod) {
                            ForEach(StatsPeriod.allCases, id: \.self) { period in
                                Text(period.rawValue).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        // Overview Cards
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatCard(
                                title: "Total Searches",
                                value: "1,247",
                                change: "+12%",
                                icon: "magnifyingglass",
                                color: .blue
                            )
                            
                            StatCard(
                                title: "Places Saved",
                                value: "127",
                                change: "+8",
                                icon: "bookmark.fill",
                                color: .orange
                            )
                            
                            StatCard(
                                title: "Distance",
                                value: "842 km",
                                change: "+124 km",
                                icon: "location.fill",
                                color: .green
                            )
                            
                            StatCard(
                                title: "Active Days",
                                value: "23",
                                change: "7 streak",
                                icon: "flame.fill",
                                color: .red
                            )
                        }
                        .padding(.horizontal)
                        
                        // Activity Chart
                        ActivityChartView(period: selectedPeriod)
                            .padding(.horizontal)
                        
                        // Category Breakdown
                        CategoryBreakdownView()
                            .padding(.horizontal)
                        
                        // Travel Insights
                        TravelInsightsView()
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Achievements View
struct AchievementsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var unlockedAchievements: Set<String> = ["first_search", "saved_10", "streak_7"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Progress Overview
                        AchievementProgressCard(
                            unlocked: unlockedAchievements.count,
                            total: Achievement.allAchievements.count
                        )
                        
                        // Achievements Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(Achievement.allAchievements) { achievement in
                                AchievementCard(
                                    achievement: achievement,
                                    isUnlocked: unlockedAchievements.contains(achievement.id)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Supporting Components
struct StorageCard: View {
    let used: String
    let available: String
    let total: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Storage", systemImage: "externaldrive")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(used) of \(total)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * 0.3, height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(available) available")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let change: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Spacer()
                Text(change)
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    let isUnlocked: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: achievement.icon)
                    .font(.title2)
                    .foregroundColor(isUnlocked ? .yellow : .gray)
            }
            
            VStack(spacing: 4) {
                Text(achievement.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isUnlocked ? .white : .gray)
                    .lineLimit(1)
                
                Text(achievement.description)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(isUnlocked ? 0.1 : 0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isUnlocked ? Color.yellow.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Additional Supporting Views
struct SignInPromptView: View {
    let authManager: AuthenticationManager
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
                
                Text("Sign in to TreeShop Maps")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Sync your favorites and preferences across all your devices")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            SignInWithAppleButton()
                .frame(width: 280, height: 50)
                .onTapGesture {
                    authManager.signInWithApple()
                }
        }
    }
}

struct SignInWithAppleButton: UIViewRepresentable {
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(
            authorizationButtonType: .signIn,
            authorizationButtonStyle: .white
        )
        button.cornerRadius = 10
        return button
    }
    
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
}

struct SyncStatusCard: View {
    @ObservedObject var syncManager: CloudKitSyncManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: syncManager.syncStatus.icon)
                            .font(.title3)
                            .foregroundColor(syncStatusColor)
                        
                        Text(syncManager.syncStatus.rawValue)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    if let lastSync = syncManager.lastSyncDate {
                        Text("Last synced \(formatRelativeTime(lastSync))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                if syncManager.syncStatus == .syncing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
            }
            
            if syncManager.syncStatus == .syncing {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * syncManager.syncProgress)
                    }
                }
                .frame(height: 4)
            }
            
            if syncManager.pendingOperations > 0 {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("\(syncManager.pendingOperations) operations pending")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    private var syncStatusColor: Color {
        switch syncManager.syncStatus {
        case .idle: return .green
        case .syncing, .uploading, .downloading: return .blue
        case .conflict: return .orange
        case .error: return .red
        case .offline: return .gray
        }
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Helper Classes
class StatsManager: ObservableObject {
    @Published var searchCount = 1247
    @Published var savedPlaces = 127
    @Published var totalDistance = 842.0
    @Published var activeDays = 23
    @Published var currentStreak = 7
}