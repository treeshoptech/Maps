import SwiftUI
import MapKit
import CoreData

struct SavedLocationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SavedLocation.updatedAt, ascending: false)],
        animation: .default
    )
    private var savedLocations: FetchedResults<SavedLocation>
    
    @State private var selectedCategory: LocationCategory?
    @State private var searchText = ""
    @State private var sortOption: SortOption = .recent
    @State private var showingAddLocation = false
    @State private var selectedLocation: SavedLocation?
    @State private var showingLocationDetail = false
    @State private var isGridView = false
    
    enum SortOption: String, CaseIterable {
        case recent = "Recent"
        case alphabetical = "A-Z"
        case distance = "Distance"
        case mostVisited = "Most Visited"
        
        var icon: String {
            switch self {
            case .recent: return "clock"
            case .alphabetical: return "textformat"
            case .distance: return "location"
            case .mostVisited: return "star"
            }
        }
    }
    
    var filteredLocations: [SavedLocation] {
        var locations = Array(savedLocations)
        
        // Filter by category
        if let category = selectedCategory {
            locations = locations.filter { $0.category == category.rawValue }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            locations = locations.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.address ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.notes ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort
        switch sortOption {
        case .recent:
            locations.sort { $0.updatedAt > $1.updatedAt }
        case .alphabetical:
            locations.sort { $0.name < $1.name }
        case .distance:
            // Would need current location for actual distance sorting
            break
        case .mostVisited:
            locations.sort { $0.visitCount > $1.visitCount }
        }
        
        return locations
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
                    
                    // Category Filter
                    categoryFilter
                        .padding(.vertical, 12)
                    
                    // Sort and View Options
                    sortAndViewOptions
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    
                    // Locations List/Grid
                    if filteredLocations.isEmpty {
                        emptyState
                    } else {
                        if isGridView {
                            locationsGrid
                        } else {
                            locationsList
                        }
                    }
                }
            }
            .navigationTitle("Saved Locations")
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
                        showingAddLocation = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAddLocation) {
            AddLocationView()
        }
        .sheet(item: $selectedLocation) { location in
            LocationDetailView(location: location)
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search saved locations", text: $searchText)
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
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All Category
                CategoryChip(
                    category: nil,
                    isSelected: selectedCategory == nil,
                    action: {
                        withAnimation {
                            selectedCategory = nil
                        }
                    }
                )
                
                // Specific Categories
                ForEach(LocationCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selectedCategory == category,
                        count: savedLocations.filter { $0.category == category.rawValue }.count,
                        action: {
                            withAnimation {
                                selectedCategory = selectedCategory == category ? nil : category
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var sortAndViewOptions: some View {
        HStack {
            // Sort Menu
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(action: {
                        withAnimation {
                            sortOption = option
                        }
                    }) {
                        Label(option.rawValue, systemImage: option.icon)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: sortOption.icon)
                    Text(sortOption.rawValue)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Stats
            Text("\(filteredLocations.count) places")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
            
            // View Toggle
            Button(action: {
                withAnimation {
                    isGridView.toggle()
                }
            }) {
                Image(systemName: isGridView ? "square.grid.2x2" : "list.bullet")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
        }
    }
    
    private var locationsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredLocations) { location in
                    LocationRowView(location: location) {
                        selectedLocation = location
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var locationsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(filteredLocations) { location in
                    LocationGridCard(location: location) {
                        selectedLocation = location
                    }
                }
            }
            .padding()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: selectedCategory?.icon ?? "bookmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Saved Locations")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(selectedCategory != nil ? 
                 "No locations in this category" : 
                 "Save your favorite places to access them quickly")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                showingAddLocation = true
            }) {
                Label("Add Location", systemImage: "plus.circle.fill")
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(25)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Views
struct CategoryChip: View {
    let category: LocationCategory?
    let isSelected: Bool
    var count: Int = 0
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let category = category {
                    Image(systemName: category.icon)
                        .font(.system(size: 14))
                    Text(category.displayName)
                    if count > 0 {
                        Text("(\(count))")
                            .font(.caption)
                    }
                } else {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 14))
                    Text("All")
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

struct LocationRowView: View {
    let location: SavedLocation
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: location.systemIconName)
                    .font(.system(size: 20))
                    .foregroundColor(Color(location.displayColor))
                    .frame(width: 44, height: 44)
                    .background(Color(location.displayColor).opacity(0.15))
                    .cornerRadius(12)
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(location.name)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        if location.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    if let address = location.address {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 12) {
                        if location.visitCount > 0 {
                            Label("\(location.visitCount) visits", systemImage: "arrow.triangle.turn.up.right.circle")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        if let tags = location.tags, !tags.isEmpty {
                            Label("\(tags.count) tags", systemImage: "tag")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Spacer()
                
                // Chevron
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

struct LocationGridCard: View {
    let location: SavedLocation
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Map Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 100)
                    
                    Image(systemName: location.systemIconName)
                        .font(.system(size: 30))
                        .foregroundColor(Color(location.displayColor))
                    
                    if location.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.red)
                            .cornerRadius(6)
                            .offset(x: -60, y: -35)
                    }
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(LocationCategory(rawValue: location.category)?.displayName ?? "Place")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color.gray.opacity(0.08))
            .cornerRadius(16)
        }
    }
}

// MARK: - Add Location View
struct AddLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var locationName = ""
    @State private var address = ""
    @State private var selectedCategory: LocationCategory = .favorite
    @State private var notes = ""
    @State private var isFavorite = false
    @State private var coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                Form {
                    Section("Location Details") {
                        TextField("Name", text: $locationName)
                        TextField("Address (optional)", text: $address)
                        
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(LocationCategory.allCases, id: \.self) { category in
                                Label(category.displayName, systemImage: category.icon)
                                    .tag(category)
                            }
                        }
                    }
                    
                    Section("Additional Info") {
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                        
                        Toggle("Mark as Favorite", isOn: $isFavorite)
                    }
                    
                    Section("Location") {
                        // Map picker would go here
                        Text("Tap to set location on map")
                            .foregroundColor(.blue)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveLocation()
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                    .disabled(locationName.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func saveLocation() {
        let context = DataStackManager.shared.viewContext
        let location = SavedLocation(context: context)
        
        location.id = UUID()
        location.name = locationName
        location.address = address.isEmpty ? nil : address
        location.category = selectedCategory.rawValue
        location.notes = notes.isEmpty ? nil : notes
        location.latitude = coordinate.latitude
        location.longitude = coordinate.longitude
        location.isFavorite = isFavorite
        location.createdAt = Date()
        location.updatedAt = Date()
        location.visitCount = 0
        location.user = UserProfile.current(in: context)
        
        DataStackManager.shared.save()
        dismiss()
    }
}

// MARK: - Location Detail View
struct LocationDetailView: View {
    let location: SavedLocation
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Map Preview
                        MapPreviewCard(coordinate: location.coordinate)
                        
                        // Details
                        VStack(alignment: .leading, spacing: 16) {
                            Label(location.name, systemImage: location.systemIconName)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            if let address = location.address {
                                Label(address, systemImage: "location")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            if let notes = location.notes {
                                Text(notes)
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Actions
                        VStack(spacing: 12) {
                            ActionButton(title: "Get Directions", icon: "arrow.triangle.turn.up.right.diamond", color: .blue) {
                                // Open in maps
                            }
                            
                            ActionButton(title: "Share Location", icon: "square.and.arrow.up", color: .green) {
                                // Share
                            }
                            
                            ActionButton(title: "Edit", icon: "pencil", color: .orange) {
                                // Edit
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Location Details")
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
}

struct MapPreviewCard: View {
    let coordinate: CLLocationCoordinate2D
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 200)
            
            // Map would go here
            VStack {
                Image(systemName: "map")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                Text("\(coordinate.latitude), \(coordinate.longitude)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
            }
            .foregroundColor(color)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
    }
}