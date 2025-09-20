import SwiftUI
import PhotosUI
import AuthenticationServices
import MapKit
import Charts

struct EnhancedProfileView: View {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var syncManager = CloudKitSyncManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var showingSettings = false
    @State private var showingSavedLocations = false
    @State private var showingSearchHistory = false
    @State private var showingOfflineMaps = false
    @State private var showingStatistics = false
    @State private var showingAchievements = false
    @State private var profileTab: ProfileTab = .overview
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    enum ProfileTab: String, CaseIterable {
        case overview = "Overview"
        case data = "My Data"
        case sync = "Sync"
        case privacy = "Privacy"
        
        var icon: String {
            switch self {
            case .overview: return "person.crop.circle"
            case .data: return "folder"
            case .sync: return "icloud"
            case .privacy: return "lock.shield"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if authManager.isAuthenticated {
                    authenticatedView
                } else {
                    SignInPromptView(authManager: authManager)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var authenticatedView: some View {
        VStack(spacing: 0) {
            // Profile Header
            profileHeader
                .padding(.bottom, 20)
            
            // Tab Selection
            tabSelector
                .padding(.horizontal)
                .padding(.bottom, 20)
            
            // Tab Content
            ScrollView {
                VStack(spacing: 20) {
                    switch profileTab {
                    case .overview:
                        overviewContent
                    case .data:
                        dataContent
                    case .sync:
                        syncContent
                    case .privacy:
                        privacyContent
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showingSettings) {
            EnhancedSettingsView()
        }
        .sheet(isPresented: $showingSavedLocations) {
            SavedLocationsView()
        }
        .sheet(isPresented: $showingSearchHistory) {
            SearchHistoryView()
        }
        .sheet(isPresented: $showingOfflineMaps) {
            OfflineMapsView()
        }
        .sheet(isPresented: $showingStatistics) {
            StatisticsView()
        }
        .sheet(isPresented: $showingAchievements) {
            AchievementsView()
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Profile Photo
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack {
                    if let profileImage = profileImage {
                        profileImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Text(authManager.currentUser?.initials ?? "TU")
                                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            )
                    }
                    
                    // Edit Badge
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        )
                        .offset(x: 35, y: 35)
                }
            }
            .onChange(of: selectedPhoto) { _ in
                loadImage()
            }
            
            // User Info
            VStack(spacing: 4) {
                Text(authManager.currentUser?.displayName ?? "TreeShop User")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                if !authManager.userEmail.isEmpty {
                    Text(authManager.userEmail)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // Quick Stats
                HStack(spacing: 20) {
                    StatBadge(value: "127", label: "Places", color: .blue)
                    StatBadge(value: "23", label: "Routes", color: .green)
                    StatBadge(value: "5", label: "Maps", color: .orange)
                }
                .padding(.top, 12)
            }
        }
        .padding(.top, 20)
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        profileTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))
                            .foregroundColor(profileTab == tab ? .white : .gray)
                        
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(profileTab == tab ? .semibold : .regular)
                            .foregroundColor(profileTab == tab ? .white : .gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(profileTab == tab ? Color.white.opacity(0.1) : Color.clear)
                    )
                }
            }
        }
        .padding(4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    private var overviewContent: some View {
        VStack(spacing: 16) {
            // Quick Actions
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickActionCard(
                    icon: "heart.fill",
                    title: "Saved Places",
                    count: "127",
                    color: .red,
                    action: { showingSavedLocations = true }
                )
                
                QuickActionCard(
                    icon: "clock.fill",
                    title: "Recent",
                    count: "48",
                    color: .blue,
                    action: { showingSearchHistory = true }
                )
                
                QuickActionCard(
                    icon: "map.fill",
                    title: "Offline Maps",
                    count: "5",
                    color: .green,
                    action: { showingOfflineMaps = true }
                )
                
                QuickActionCard(
                    icon: "chart.bar.fill",
                    title: "Statistics",
                    count: nil,
                    color: .purple,
                    action: { showingStatistics = true }
                )
            }
            
            // Recent Activity
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent Activity")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button("See All") {
                        showingSearchHistory = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                VStack(spacing: 8) {
                    RecentActivityRow(
                        icon: "magnifyingglass",
                        title: "Coffee shops near me",
                        subtitle: "2 hours ago",
                        color: .blue
                    )
                    
                    RecentActivityRow(
                        icon: "location.fill",
                        title: "Navigated to Work",
                        subtitle: "This morning",
                        color: .green
                    )
                    
                    RecentActivityRow(
                        icon: "bookmark.fill",
                        title: "Saved Central Park",
                        subtitle: "Yesterday",
                        color: .orange
                    )
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(16)
            
            // Achievements Preview
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Achievements")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button("View All") {
                        showingAchievements = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                HStack(spacing: 16) {
                    AchievementBadge(icon: "star.fill", title: "Explorer", progress: 0.7, color: .yellow)
                    AchievementBadge(icon: "flame.fill", title: "7 Day Streak", progress: 1.0, color: .orange)
                    AchievementBadge(icon: "map.fill", title: "Cartographer", progress: 0.4, color: .green)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(16)
        }
    }
    
    private var dataContent: some View {
        VStack(spacing: 16) {
            // Storage Overview
            StorageOverview()
            
            // Data Categories
            VStack(spacing: 12) {
                DataCategoryRow(
                    icon: "heart.fill",
                    title: "Saved Locations",
                    count: "127 places",
                    size: "2.3 MB",
                    color: .red,
                    action: { showingSavedLocations = true }
                )
                
                DataCategoryRow(
                    icon: "clock.fill",
                    title: "Search History",
                    count: "Last 30 days",
                    size: "512 KB",
                    color: .blue,
                    action: { showingSearchHistory = true }
                )
                
                DataCategoryRow(
                    icon: "map.fill",
                    title: "Offline Maps",
                    count: "5 regions",
                    size: "847 MB",
                    color: .green,
                    action: { showingOfflineMaps = true }
                )
                
                DataCategoryRow(
                    icon: "photo.fill",
                    title: "Photos & Media",
                    count: "23 items",
                    size: "124 MB",
                    color: .purple,
                    action: {}
                )
            }
            
            // Data Management Actions
            VStack(spacing: 12) {
                Button(action: {
                    // Export data
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export My Data")
                        Spacer()
                    }
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Button(action: {
                    // Clear cache
                    settingsManager.clearCache()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Cache")
                        Spacer()
                        Text("124 MB")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .foregroundColor(.orange)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var syncContent: some View {
        VStack(spacing: 16) {
            // Sync Status Card
            SyncStatusCard(syncManager: syncManager)
            
            // Sync Settings
            VStack(spacing: 12) {
                Toggle(isOn: $settingsManager.syncWithiCloud) {
                    HStack {
                        Image(systemName: "icloud")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("iCloud Sync")
                                .foregroundColor(.white)
                            Text("Sync data across all devices")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                if settingsManager.syncWithiCloud {
                    // Sync Options
                    VStack(spacing: 12) {
                        SyncOptionRow(
                            title: "Saved Locations",
                            isEnabled: true,
                            lastSync: Date().addingTimeInterval(-300)
                        )
                        
                        SyncOptionRow(
                            title: "Search History",
                            isEnabled: true,
                            lastSync: Date().addingTimeInterval(-1800)
                        )
                        
                        SyncOptionRow(
                            title: "Preferences",
                            isEnabled: true,
                            lastSync: Date().addingTimeInterval(-86400)
                        )
                        
                        SyncOptionRow(
                            title: "Offline Maps",
                            isEnabled: false,
                            lastSync: nil
                        )
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(16)
            
            // Manual Sync
            Button(action: {
                Task {
                    await syncManager.performFullSync()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Sync Now")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .disabled(syncManager.syncStatus == .syncing)
        }
    }
    
    private var privacyContent: some View {
        VStack(spacing: 16) {
            // Location Services
            VStack(alignment: .leading, spacing: 12) {
                Label("Location Services", systemImage: "location.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Toggle(isOn: $settingsManager.locationServices) {
                    Text("Enable Location Services")
                        .foregroundColor(.white)
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                if settingsManager.locationServices {
                    Toggle(isOn: $settingsManager.preciseLocation) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Precise Location")
                                .foregroundColor(.white)
                            Text("For accurate navigation and search")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    
                    Toggle(isOn: $settingsManager.significantLocations) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Significant Locations")
                                .foregroundColor(.white)
                            Text("Learn places you visit frequently")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(16)
            
            // Data & Analytics
            VStack(alignment: .leading, spacing: 12) {
                Label("Data & Analytics", systemImage: "chart.bar.xaxis")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Toggle(isOn: $settingsManager.shareAnalytics) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share Analytics")
                            .foregroundColor(.white)
                        Text("Help improve TreeShop Maps")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                Toggle(isOn: $settingsManager.personalizedAds) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Personalized Ads")
                            .foregroundColor(.white)
                        Text("Show relevant ads based on usage")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(16)
            
            // Privacy Actions
            VStack(spacing: 12) {
                Button(action: {
                    // Show privacy policy
                }) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Button(action: {
                    // Delete account
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Delete Account & Data")
                        Spacer()
                    }
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func loadImage() {
        Task {
            if let data = try? await selectedPhoto?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                profileImage = Image(uiImage: uiImage)
                
                // Save to Core Data
                authManager.currentUser?.profileImageData = data
                DataStackManager.shared.save()
            }
        }
    }
}

// MARK: - Supporting Views
struct StatBadge: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let count: String?
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                if let count = count {
                    Text(count)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(16)
        }
    }
}

struct RecentActivityRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct AchievementBadge: View {
    let icon: String
    let title: String
    let progress: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}