import SwiftUI
import CoreData
import MapKit

struct SearchHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SearchHistory.timestamp, ascending: false)],
        animation: .default
    )
    private var searchHistory: FetchedResults<SearchHistory>
    
    @State private var searchText = ""
    @State private var selectedTimeRange: TimeRange = .all
    @State private var showingSmartSuggestions = true
    @StateObject private var searchManager = SearchManager()
    
    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
        
        var predicate: NSPredicate? {
            let now = Date()
            switch self {
            case .today:
                let startOfDay = Calendar.current.startOfDay(for: now)
                return NSPredicate(format: "timestamp >= %@", startOfDay as NSDate)
            case .week:
                let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
                return NSPredicate(format: "timestamp >= %@", weekAgo as NSDate)
            case .month:
                let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now)!
                return NSPredicate(format: "timestamp >= %@", monthAgo as NSDate)
            case .all:
                return nil
            }
        }
    }
    
    var filteredHistory: [SearchHistory] {
        var history = Array(searchHistory)
        
        // Filter by search text
        if !searchText.isEmpty {
            history = history.filter {
                $0.query.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by time range
        if let predicate = selectedTimeRange.predicate {
            history = history.filter { predicate.evaluate(with: $0) }
        }
        
        return history
    }
    
    var groupedHistory: [(String, [SearchHistory])] {
        let grouped = Dictionary(grouping: filteredHistory) { item in
            formatDateSection(item.timestamp)
        }
        
        return grouped.sorted { $0.value.first?.timestamp ?? Date() > $1.value.first?.timestamp ?? Date() }
            .map { ($0.key, $0.value) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar
                    searchBar
                        .padding(.horizontal)
                        .padding(.top, 10)
                    
                    // Time Range Filter
                    timeRangeFilter
                        .padding(.vertical, 12)
                    
                    // Smart Suggestions Toggle
                    if showingSmartSuggestions {
                        smartSuggestionsSection
                    }
                    
                    // History List
                    if filteredHistory.isEmpty {
                        emptyState
                    } else {
                        historyList
                    }
                }
            }
            .navigationTitle("Search History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            clearRecentHistory()
                        }) {
                            Label("Clear Today", systemImage: "trash")
                        }
                        
                        Button(action: {
                            clearAllHistory()
                        }) {
                            Label("Clear All History", systemImage: "trash.fill")
                        }
                        .foregroundColor(.red)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search history", text: $searchText)
                .foregroundColor(.white)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
    
    private var timeRangeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    TimeRangeChip(
                        range: range,
                        isSelected: selectedTimeRange == range,
                        count: countForTimeRange(range),
                        action: {
                            withAnimation {
                                selectedTimeRange = range
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var smartSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Smart Suggestions", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        showingSmartSuggestions.toggle()
                    }
                }) {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(searchManager.smartSuggestions, id: \.self) { suggestion in
                        SuggestionChip(suggestion: suggestion) {
                            performSearch(suggestion)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.05))
    }
    
    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(groupedHistory, id: \.0) { section, items in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            ForEach(items) { item in
                                SearchHistoryRow(item: item) {
                                    performSearch(item.query)
                                }
                                
                                if item != items.last {
                                    Divider()
                                        .background(Color.gray.opacity(0.2))
                                        .padding(.leading, 60)
                                }
                            }
                        }
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Search History")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Your recent searches will appear here")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    private func formatDateSection(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if date > Date().addingTimeInterval(-7 * 24 * 60 * 60) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
    
    private func countForTimeRange(_ range: TimeRange) -> Int {
        if let predicate = range.predicate {
            return searchHistory.filter { predicate.evaluate(with: $0) }.count
        }
        return searchHistory.count
    }
    
    private func performSearch(_ query: String) {
        // Record new search
        let newSearch = SearchHistory(context: viewContext)
        newSearch.id = UUID()
        newSearch.query = query
        newSearch.timestamp = Date()
        newSearch.searchType = "repeat"
        newSearch.user = UserProfile.current(in: viewContext)
        
        DataStackManager.shared.save()
        
        // Trigger actual search
        dismiss()
    }
    
    private func clearRecentHistory() {
        let today = Calendar.current.startOfDay(for: Date())
        let request: NSFetchRequest<SearchHistory> = SearchHistory.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp >= %@", today as NSDate)
        
        do {
            let items = try viewContext.fetch(request)
            items.forEach { viewContext.delete($0) }
            DataStackManager.shared.save()
        } catch {
            print("Failed to clear recent history: \(error)")
        }
    }
    
    private func clearAllHistory() {
        searchHistory.forEach { viewContext.delete($0) }
        DataStackManager.shared.save()
    }
}

// MARK: - Supporting Views
struct TimeRangeChip: View {
    let range: SearchHistoryView.TimeRange
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(range.rawValue)
                if count > 0 {
                    Text("(\(count))")
                        .font(.caption)
                }
            }
            .foregroundColor(isSelected ? .white : .gray)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.15))
            )
        }
    }
}

struct SuggestionChip: View {
    let suggestion: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption)
                Text(suggestion)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(20)
        }
    }
}

struct SearchHistoryRow: View {
    let item: SearchHistory
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: searchTypeIcon)
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.query)
                        .font(.body)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Text(formatTime(item.timestamp))
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        if item.resultCount > 0 {
                            Text("•")
                                .foregroundColor(.gray)
                            Text("\(item.resultCount) results")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.backward")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
        }
    }
    
    private var searchTypeIcon: String {
        switch item.searchType {
        case "voice":
            return "mic.fill"
        case "suggestion":
            return "sparkles"
        default:
            return "magnifyingglass"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Search Manager
class SearchManager: ObservableObject {
    @Published var smartSuggestions: [String] = []
    
    init() {
        generateSmartSuggestions()
    }
    
    private func generateSmartSuggestions() {
        // In a real app, these would be ML-generated based on context
        let timeBasedSuggestions = getTimeBasedSuggestions()
        let locationBasedSuggestions = getLocationBasedSuggestions()
        let behaviorBasedSuggestions = getBehaviorBasedSuggestions()
        
        smartSuggestions = Array(Set(timeBasedSuggestions + locationBasedSuggestions + behaviorBasedSuggestions))
            .prefix(6)
            .map { String($0) }
    }
    
    private func getTimeBasedSuggestions() -> [String] {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5...10:
            return ["Coffee near me", "Breakfast spots", "Gyms nearby"]
        case 11...14:
            return ["Lunch restaurants", "Fast food nearby", "Cafes"]
        case 17...20:
            return ["Dinner restaurants", "Bars nearby", "Takeout"]
        case 20...24, 0...5:
            return ["24 hour stores", "Gas stations", "Pharmacies"]
        default:
            return ["Restaurants", "Shopping", "Entertainment"]
        }
    }
    
    private func getLocationBasedSuggestions() -> [String] {
        // Would use actual location in production
        return ["Parking nearby", "Public transit", "ATMs"]
    }
    
    private func getBehaviorBasedSuggestions() -> [String] {
        // Would analyze user behavior patterns
        return ["Work", "Home", "Grocery stores"]
    }
}