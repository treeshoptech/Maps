import SwiftUI
import Charts
import MapKit

// MARK: - Activity Chart View
struct ActivityChartView: View {
    let period: StatisticsView.StatsPeriod
    @State private var chartData: [ActivityData] = []
    
    struct ActivityData: Identifiable {
        let id = UUID()
        let date: Date
        let searches: Int
        let navigations: Int
        let saves: Int
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Overview")
                .font(.headline)
                .foregroundColor(.white)
            
            Chart(chartData) { data in
                BarMark(
                    x: .value("Date", data.date, unit: periodUnit),
                    y: .value("Count", data.searches)
                )
                .foregroundStyle(Color.blue.gradient)
                .cornerRadius(4)
                
                BarMark(
                    x: .value("Date", data.date, unit: periodUnit),
                    y: .value("Count", data.navigations)
                )
                .foregroundStyle(Color.green.gradient)
                .cornerRadius(4)
                
                BarMark(
                    x: .value("Date", data.date, unit: periodUnit),
                    y: .value("Count", data.saves)
                )
                .foregroundStyle(Color.orange.gradient)
                .cornerRadius(4)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.2))
                    AxisValueLabel()
                        .foregroundStyle(Color.gray)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.2))
                    AxisValueLabel()
                        .foregroundStyle(Color.gray)
                }
            }
            
            // Legend
            HStack(spacing: 20) {
                LegendItem(color: .blue, title: "Searches")
                LegendItem(color: .green, title: "Navigation")
                LegendItem(color: .orange, title: "Saved")
            }
            .font(.caption)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
        .onAppear {
            generateChartData()
        }
    }
    
    private var periodUnit: Calendar.Component {
        switch period {
        case .week:
            return .day
        case .month:
            return .day
        case .year:
            return .month
        case .all:
            return .month
        }
    }
    
    private func generateChartData() {
        let calendar = Calendar.current
        let now = Date()
        
        switch period {
        case .week:
            chartData = (0..<7).map { dayOffset in
                let date = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
                return ActivityData(
                    date: date,
                    searches: Int.random(in: 5...30),
                    navigations: Int.random(in: 1...10),
                    saves: Int.random(in: 0...5)
                )
            }.reversed()
            
        case .month:
            chartData = (0..<30).map { dayOffset in
                let date = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
                return ActivityData(
                    date: date,
                    searches: Int.random(in: 5...30),
                    navigations: Int.random(in: 1...10),
                    saves: Int.random(in: 0...5)
                )
            }.reversed()
            
        case .year:
            chartData = (0..<12).map { monthOffset in
                let date = calendar.date(byAdding: .month, value: -monthOffset, to: now)!
                return ActivityData(
                    date: date,
                    searches: Int.random(in: 100...500),
                    navigations: Int.random(in: 20...100),
                    saves: Int.random(in: 5...30)
                )
            }.reversed()
            
        case .all:
            chartData = (0..<24).map { monthOffset in
                let date = calendar.date(byAdding: .month, value: -monthOffset, to: now)!
                return ActivityData(
                    date: date,
                    searches: Int.random(in: 100...500),
                    navigations: Int.random(in: 20...100),
                    saves: Int.random(in: 5...30)
                )
            }.reversed()
        }
    }
}

// MARK: - Category Breakdown View
struct CategoryBreakdownView: View {
    @State private var categoryData: [CategoryData] = []
    
    struct CategoryData: Identifiable {
        let id = UUID()
        let category: LocationCategory
        let count: Int
        let percentage: Double
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Places by Category")
                .font(.headline)
                .foregroundColor(.white)
            
            Chart(categoryData) { data in
                SectorMark(
                    angle: .value("Count", data.count),
                    innerRadius: .ratio(0.6),
                    outerRadius: .ratio(1.0)
                )
                .foregroundStyle(Color(data.category.color).gradient)
                .cornerRadius(4)
            }
            .frame(height: 200)
            
            // Category List
            VStack(spacing: 8) {
                ForEach(categoryData.prefix(5)) { data in
                    HStack {
                        Circle()
                            .fill(Color(data.category.color))
                            .frame(width: 8, height: 8)
                        
                        Image(systemName: data.category.icon)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(data.category.displayName)
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(data.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        
                        Text("(\(Int(data.percentage))%)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
        .onAppear {
            generateCategoryData()
        }
    }
    
    private func generateCategoryData() {
        let categories = LocationCategory.allCases
        let total = 127
        
        categoryData = categories.map { category in
            let count = Int.random(in: 5...40)
            return CategoryData(
                category: category,
                count: count,
                percentage: Double(count) / Double(total) * 100
            )
        }.sorted { $0.count > $1.count }
    }
}

// MARK: - Travel Insights View
struct TravelInsightsView: View {
    @State private var insights: [TravelInsight] = []
    
    struct TravelInsight: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let icon: String
        let color: Color
        let trend: String
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Travel Insights")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                ForEach(insights) { insight in
                    HStack {
                        Image(systemName: insight.icon)
                            .font(.title3)
                            .foregroundColor(insight.color)
                            .frame(width: 36, height: 36)
                            .background(insight.color.opacity(0.15))
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(insight.title)
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text(insight.value)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Text(insight.trend)
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
        .onAppear {
            generateInsights()
        }
    }
    
    private func generateInsights() {
        insights = [
            TravelInsight(
                title: "Most Visited",
                value: "Central Park",
                icon: "star.fill",
                color: .yellow,
                trend: "23 visits"
            ),
            TravelInsight(
                title: "Longest Journey",
                value: "San Francisco",
                icon: "airplane",
                color: .blue,
                trend: "2,847 km"
            ),
            TravelInsight(
                title: "Favorite Time",
                value: "Weekends",
                icon: "calendar",
                color: .purple,
                trend: "68%"
            ),
            TravelInsight(
                title: "Peak Activity",
                value: "6-8 PM",
                icon: "clock.fill",
                color: .orange,
                trend: "+15%"
            )
        ]
    }
}

// MARK: - Supporting Components
struct LegendItem: View {
    let color: Color
    let title: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .foregroundColor(.gray)
        }
    }
}

struct AchievementProgressCard: View {
    let unlocked: Int
    let total: Int
    
    var progress: Double {
        Double(unlocked) / Double(total)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Achievement Progress")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("\(unlocked) of \(total) unlocked")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 12)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

// MARK: - Settings Content Views
struct MapSettingsContent: View {
    @StateObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: "Map Type") {
                Picker("Map Type", selection: $settings.mapType) {
                    Text("Standard").tag("standard")
                    Text("Satellite").tag("satellite")
                    Text("Hybrid").tag("hybrid")
                    Text("Muted").tag("mutedStandard")
                }
                .pickerStyle(.segmented)
            }
            
            SettingsGroup(title: "Map Features") {
                Toggle("Show Traffic", isOn: $settings.showTraffic)
                Toggle("Show 3D Buildings", isOn: $settings.show3DBuildings)
                Toggle("Show Points of Interest", isOn: $settings.showPointsOfInterest)
                Toggle("Show Compass", isOn: $settings.showCompass)
                Toggle("Show Scale", isOn: $settings.showScale)
                Toggle("Enable Map Pitch", isOn: $settings.mapPitchEnabled)
            }
        }
    }
}

struct NavigationSettingsContent: View {
    @StateObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: "Route Options") {
                Toggle("Avoid Tolls", isOn: $settings.avoidTolls)
                Toggle("Avoid Highways", isOn: $settings.avoidHighways)
                Toggle("Avoid Ferries", isOn: $settings.avoidFerries)
            }
            
            SettingsGroup(title: "Voice Guidance") {
                Picker("Voice", selection: $settings.voiceNavigation) {
                    Text("Default").tag("default")
                    Text("Male").tag("male")
                    Text("Female").tag("female")
                    Text("Disabled").tag("disabled")
                }
                .pickerStyle(.segmented)
                
                if settings.voiceNavigation != "disabled" {
                    HStack {
                        Text("Volume")
                        Slider(value: $settings.voiceVolume, in: 0...1)
                    }
                    
                    Toggle("Pause Audio During Navigation", isOn: $settings.pauseSpokenAudioDuringNavigation)
                }
            }
        }
    }
}

struct UnitsSettingsContent: View {
    @StateObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: "Distance") {
                Picker("Distance Unit", selection: $settings.distanceUnit) {
                    Text("Automatic").tag("automatic")
                    Text("Kilometers").tag("kilometers")
                    Text("Miles").tag("miles")
                }
                .pickerStyle(.segmented)
            }
            
            SettingsGroup(title: "Temperature") {
                Picker("Temperature Unit", selection: $settings.temperatureUnit) {
                    Text("Celsius").tag("celsius")
                    Text("Fahrenheit").tag("fahrenheit")
                }
                .pickerStyle(.segmented)
            }
            
            SettingsGroup(title: "Time") {
                Picker("Time Format", selection: $settings.timeFormat) {
                    Text("12-hour").tag("12hour")
                    Text("24-hour").tag("24hour")
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

struct PrivacySettingsContent: View {
    @StateObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: "Location") {
                Toggle("Location Services", isOn: $settings.locationServices)
                if settings.locationServices {
                    Toggle("Precise Location", isOn: $settings.preciseLocation)
                    Toggle("Significant Locations", isOn: $settings.significantLocations)
                }
            }
            
            SettingsGroup(title: "Data & Analytics") {
                Toggle("Share Analytics", isOn: $settings.shareAnalytics)
                Toggle("Personalized Ads", isOn: $settings.personalizedAds)
            }
        }
    }
}

struct NotificationSettingsContent: View {
    @StateObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: "Notifications") {
                Toggle("Enable Notifications", isOn: $settings.enableNotifications)
                
                if settings.enableNotifications {
                    Toggle("Traffic Alerts", isOn: $settings.trafficAlerts)
                    Toggle("Time to Leave", isOn: $settings.timeToLeaveAlerts)
                    Toggle("Parking Reminders", isOn: $settings.parkingReminders)
                    Toggle("Speed Limit Warnings", isOn: $settings.speedLimitWarnings)
                }
            }
        }
    }
}

struct DisplaySettingsContent: View {
    @StateObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: "Appearance") {
                Picker("Theme", selection: $settings.themeMode) {
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                    Text("System").tag("system")
                }
                .pickerStyle(.segmented)
                
                Toggle("Auto Night Mode", isOn: $settings.autoNightMode)
            }
            
            SettingsGroup(title: "Accessibility") {
                Toggle("Reduced Motion", isOn: $settings.reducedMotion)
                Toggle("High Contrast", isOn: $settings.highContrastMode)
                Toggle("Large Fonts", isOn: $settings.largeFonts)
            }
        }
    }
}

struct DataManagementSettingsContent: View {
    @StateObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: "Offline Maps") {
                Picker("Quality", selection: $settings.offlineMapQuality) {
                    Text("Standard").tag("standard")
                    Text("High").tag("high")
                    Text("Maximum").tag("maximum")
                }
                .pickerStyle(.segmented)
                
                Toggle("Auto Update", isOn: $settings.offlineMapAutoUpdate)
                Toggle("Update on Wi-Fi Only", isOn: $settings.offlineMapUpdateOnWiFiOnly)
            }
            
            SettingsGroup(title: "Search History") {
                Toggle("Save Search History", isOn: $settings.searchHistoryEnabled)
                
                if settings.searchHistoryEnabled {
                    HStack {
                        Text("Keep for")
                        Spacer()
                        Picker("Duration", selection: $settings.searchHistoryDuration) {
                            Text("7 days").tag(7)
                            Text("30 days").tag(30)
                            Text("90 days").tag(90)
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            
            Button(action: {
                settings.clearCache()
            }) {
                HStack {
                    Text("Clear Cache")
                    Spacer()
                    Text("\(settings.cacheSize) MB")
                        .foregroundColor(.gray)
                }
            }
            .foregroundColor(.orange)
        }
    }
}

struct AdvancedSettingsContent: View {
    @StateObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: "Developer") {
                Toggle("Developer Mode", isOn: $settings.developerMode)
                if settings.developerMode {
                    Toggle("Show Debug Info", isOn: $settings.showDebugInfo)
                    Toggle("Experimental Features", isOn: $settings.experimentalFeatures)
                    Toggle("Beta Features", isOn: $settings.betaFeatures)
                }
            }
        }
    }
}

// MARK: - Settings Group
struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                content
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
    }
}