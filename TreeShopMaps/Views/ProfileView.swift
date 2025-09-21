import SwiftUI
import PhotosUI
import MapKit
import CoreData
import AuthenticationServices

// Local enums for UI (mirrors DataModels.swift)
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

struct ProfileView: View {
    @StateObject private var authManager = AuthenticationManager()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var showingSettings = false
    @State private var showingSavedLocations = false
    @State private var showingSearchHistory = false
    @State private var showingOfflineMaps = false
    @State private var showingProjects = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if authManager.isAuthenticated {
                    authenticatedView
                } else {
                    signInView
                }
            }
            .navigationTitle("Profile")
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
    
    private var signInView: some View {
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
            
            Button(action: {
                authManager.createLocalUser()
            }) {
                HStack {
                    Image(systemName: "person.fill")
                    Text("Continue to TreeShop Maps")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(width: 280, height: 50)
                .background(Color.green)
                .cornerRadius(10)
            }
        }
    }
    
    private var authenticatedView: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        if let profileImage = profileImage {
                            profileImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 100))
                                .foregroundColor(.gray)
                        }
                    }
                    .onChange(of: selectedPhoto) {
                        loadImage()
                    }
                    
                    VStack(spacing: 4) {
                        Text(authManager.userFullName.isEmpty ? "TreeShop User" : authManager.userFullName)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        if !authManager.userEmail.isEmpty {
                            Text(authManager.userEmail)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.top, 20)
                
                VStack(spacing: 12) {
                    ProfileMenuItem(
                        icon: "tree.fill",
                        title: "Forestry Projects",
                        color: .green
                    ) {
                        showingProjects = true
                    }
                    
                    ProfileMenuItem(
                        icon: "heart.fill",
                        title: "Saved Locations",
                        color: .red
                    ) {
                        showingSavedLocations = true
                    }
                    
                    ProfileMenuItem(
                        icon: "clock.fill",
                        title: "Recent Searches",
                        color: .blue
                    ) {
                        showingSearchHistory = true
                    }
                    
                    ProfileMenuItem(
                        icon: "map.fill",
                        title: "Offline Maps",
                        color: .orange
                    ) {
                        showingOfflineMaps = true
                    }
                    
                    ProfileMenuItem(
                        icon: "gearshape.fill",
                        title: "Settings",
                        color: .gray
                    ) {
                        showingSettings = true
                    }
                }
                .padding(.horizontal)
                
                Button(action: {
                    authManager.signOut()
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingSavedLocations) {
            PlaceholderView(title: "Saved Locations", icon: "heart.fill")
        }
        .sheet(isPresented: $showingSearchHistory) {
            PlaceholderView(title: "Search History", icon: "clock.fill")
        }
        .sheet(isPresented: $showingOfflineMaps) {
            PlaceholderView(title: "Offline Maps", icon: "map.fill")
        }
        .sheet(isPresented: $showingProjects) {
            ForestryProjectsView()
        }
    }
    
    private func loadImage() {
        Task {
            if let data = try? await selectedPhoto?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                profileImage = Image(uiImage: uiImage)
            }
        }
    }
}

struct ProfileMenuItem: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 30)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct ForestryProjectsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var projects: [MockProject] = []
    @State private var showingNewProject = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if projects.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "tree.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("No Forestry Projects")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Create your first forestry project to get started with land management and area calculations.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            showingNewProject = true
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Create Project")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(projects, id: \.id) { project in
                                ProjectCard(project: project)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Forestry Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                if !projects.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingNewProject = true
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingNewProject) {
            NewProjectView { project in
                projects.append(project)
            }
        }
        .onAppear {
            loadProjects()
        }
    }
    
    private func loadProjects() {
        // TODO: Load projects from Core Data
        // For now, create some sample projects
        projects = []
    }
}

struct ProjectCard: View {
    let project: MockProject
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let customer = project.customerName {
                        Text(customer)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(project.projectStatus.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(8)
                    
                    Text("\(project.totalAcres, specifier: "%.1f") acres")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if let address = project.address {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.gray)
                    Text(address)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            HStack {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                    Text(ServiceType(rawValue: project.serviceType)?.displayName ?? "Forestry Mulching")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.gray)
                    Text(project.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// Mock project for UI testing
struct MockProject {
    let id = UUID()
    let name: String
    let customerName: String?
    let address: String?
    let serviceType: String
    let notes: String?
    let createdAt = Date()
    let projectStatus = "draft"
    let totalAcres = 0.0
}

struct NewProjectView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (MockProject) -> Void
    
    @State private var projectName = ""
    @State private var customerName = ""
    @State private var address = ""
    @State private var serviceType = ServiceType.forestryMulching
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                Form {
                    Section("Project Details") {
                        TextField("Project Name", text: $projectName)
                        TextField("Customer Name", text: $customerName)
                        TextField("Address", text: $address)
                    }
                    
                    Section("Service Type") {
                        Picker("Service Type", selection: $serviceType) {
                            ForEach(ServiceType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Section("Notes") {
                        TextField("Additional notes...", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Project")
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
                        saveProject()
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .disabled(projectName.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func saveProject() {
        // For now, just simulate project creation
        // TODO: Implement Core Data saving
        print("Would save project: \(projectName)")
        
        // Create a mock project for the callback
        // In a real implementation, this would be a Core Data Project
        let mockProject = MockProject(
            name: projectName,
            customerName: customerName.isEmpty ? nil : customerName,
            address: address.isEmpty ? nil : address,
            serviceType: serviceType.rawValue,
            notes: notes.isEmpty ? nil : notes
        )
        
        onSave(mockProject)
    }
}


struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var defaultMapType: MKMapType = .standard
    @State private var showTraffic = false
    @State private var showUserLocation = true
    @State private var syncWithiCloud = true
    @State private var enableNotifications = true
    @State private var defaultProjectSize = ProjectSize.large
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List {
                    Section("Map Preferences") {
                        HStack {
                            Text("Default Map Type")
                            Spacer()
                            Picker("Map Type", selection: $defaultMapType) {
                                Text("Standard").tag(MKMapType.standard)
                                Text("Satellite").tag(MKMapType.satellite)
                                Text("Hybrid").tag(MKMapType.hybrid)
                            }
                            .pickerStyle(.menu)
                        }
                        
                        Toggle("Show Traffic", isOn: $showTraffic)
                        Toggle("Show User Location", isOn: $showUserLocation)
                    }
                    
                    Section("Forestry Settings") {
                        HStack {
                            Text("Default Project Size")
                            Spacer()
                            Picker("Project Size", selection: $defaultProjectSize) {
                                ForEach(ProjectSize.allCases, id: \.self) { size in
                                    HStack {
                                        Circle()
                                            .fill(size.swiftUIColor)
                                            .frame(width: 12, height: 12)
                                        Text(size.rawValue)
                                    }
                                    .tag(size)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        HStack {
                            Text("Preferred Units")
                            Spacer()
                            Text("Imperial (ft, acres)")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Section("Data & Privacy") {
                        Toggle("Sync with iCloud", isOn: $syncWithiCloud)
                        Toggle("Enable Location Services", isOn: $showUserLocation)
                            .disabled(true) // System controlled
                        
                        HStack {
                            Text("Data Storage")
                            Spacer()
                            Text("Local + iCloud")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Section("Notifications") {
                        Toggle("Enable Notifications", isOn: $enableNotifications)
                        Toggle("Project Updates", isOn: .constant(true))
                            .disabled(!enableNotifications)
                        Toggle("Sync Status", isOn: .constant(false))
                            .disabled(!enableNotifications)
                    }
                    
                    Section("About") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.gray)
                        }
                        
                        HStack {
                            Text("Developer")
                            Spacer()
                            Text("TreeShop Technologies")
                                .foregroundColor(.gray)
                        }
                        
                        Button(action: {
                            // Open privacy policy
                        }) {
                            HStack {
                                Text("Privacy Policy")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                        .foregroundColor(.white)
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        // Load settings from UserDefaults or Core Data
        defaultMapType = MKMapType(rawValue: UInt(UserDefaults.standard.integer(forKey: "defaultMapType"))) ?? .standard
        showTraffic = UserDefaults.standard.bool(forKey: "showTraffic")
        showUserLocation = UserDefaults.standard.bool(forKey: "showUserLocation")
        syncWithiCloud = UserDefaults.standard.bool(forKey: "syncWithiCloud")
        enableNotifications = UserDefaults.standard.bool(forKey: "enableNotifications")
        
        if let projectSizeRaw = UserDefaults.standard.string(forKey: "defaultProjectSize"),
           let projectSize = ProjectSize(rawValue: projectSizeRaw) {
            defaultProjectSize = projectSize
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(defaultMapType.rawValue, forKey: "defaultMapType")
        UserDefaults.standard.set(showTraffic, forKey: "showTraffic")
        UserDefaults.standard.set(showUserLocation, forKey: "showUserLocation")
        UserDefaults.standard.set(syncWithiCloud, forKey: "syncWithiCloud")
        UserDefaults.standard.set(enableNotifications, forKey: "enableNotifications")
        UserDefaults.standard.set(defaultProjectSize.rawValue, forKey: "defaultProjectSize")
    }
}

struct PlaceholderView: View {
    let title: String
    let icon: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: icon)
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("\(title) Coming Soon")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("This feature will be available in a future update.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .navigationTitle(title)
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