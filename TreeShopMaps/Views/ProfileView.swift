import SwiftUI
import PhotosUI
import AuthenticationServices

struct ProfileView: View {
    @StateObject private var authManager = AuthenticationManager()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var showingSettings = false
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
            
            SignInWithAppleButton()
                .frame(width: 280, height: 50)
                .onTapGesture {
                    authManager.signInWithApple()
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
                    .onChange(of: selectedPhoto) { _ in
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
                        icon: "heart.fill",
                        title: "Saved Locations",
                        color: .red
                    ) {
                    }
                    
                    ProfileMenuItem(
                        icon: "clock.fill",
                        title: "Recent Searches",
                        color: .blue
                    ) {
                    }
                    
                    ProfileMenuItem(
                        icon: "map.fill",
                        title: "Offline Maps",
                        color: .green
                    ) {
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

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List {
                    Section("Map Preferences") {
                        HStack {
                            Text("Default Map Type")
                            Spacer()
                            Text("Standard")
                                .foregroundColor(.gray)
                        }
                        
                        Toggle("Show Traffic", isOn: .constant(false))
                        Toggle("Enable 3D Maps", isOn: .constant(true))
                    }
                    
                    Section("Privacy") {
                        Toggle("Location Services", isOn: .constant(true))
                        Toggle("Sync with iCloud", isOn: .constant(true))
                    }
                    
                    Section("Notifications") {
                        Toggle("Enable Notifications", isOn: .constant(true))
                        Toggle("Traffic Alerts", isOn: .constant(false))
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
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}