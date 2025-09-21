import SwiftUI
import CoreData
import UIKit
import AuthenticationServices

class AuthenticationManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: UserProfile?
    @Published var userEmail: String = ""
    @Published var userFullName: String = ""
    
    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext
    
    override init() {
        container = NSPersistentContainer(name: "TreeShopMaps")
        
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        context = container.viewContext
        super.init()
        
        // Check if user is already authenticated
        checkExistingAuthentication()
    }
    
    func checkExistingAuthentication() {
        // Always auto-authenticate - one simple profile system
        createLocalUser()
    }
    
    func createLocalUser() {
        DispatchQueue.main.async {
            self.isAuthenticated = true
            self.userEmail = "user@treeshop.tech"
            self.userFullName = "TreeShop User"
            
            // Create local user profile
            self.createOrUpdateUser(appleID: "local-user", email: self.userEmail, fullName: nil)
        }
    }
    
    func signInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    func signIn() {
        signInWithApple()
    }
    
    func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential) {
        let appleID = credential.user
        let email = credential.email
        let fullName = credential.fullName
        
        DispatchQueue.main.async {
            self.isAuthenticated = true
            self.userEmail = email ?? self.userEmail
            
            if let fullName = fullName {
                self.userFullName = "\(fullName.givenName ?? "") \(fullName.familyName ?? "")".trimmingCharacters(in: .whitespaces)
            }
            
            self.createOrUpdateUser(appleID: appleID, email: email, fullName: fullName)
        }
    }
    
    func signOut() {
        isAuthenticated = false
        currentUser = nil
        userEmail = ""
        userFullName = ""
        UserDefaults.standard.removeObject(forKey: "appleUserID")
    }
    
    private func fetchUserProfile(appleID: String) {
        let request: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        request.predicate = NSPredicate(format: "appleID == %@", appleID)
        
        do {
            let users = try context.fetch(request)
            currentUser = users.first
            
            if let user = currentUser {
                isAuthenticated = true
                userEmail = user.email ?? ""
                userFullName = "\(user.firstName ?? "") \(user.lastName ?? "")".trimmingCharacters(in: .whitespaces)
            }
        } catch {
            print("Failed to fetch user profile: \(error)")
        }
    }
    
    private func createOrUpdateUser(appleID: String, email: String?, fullName: PersonNameComponents?) {
        let request: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        request.predicate = NSPredicate(format: "appleID == %@", appleID)
        
        do {
            let users = try context.fetch(request)
            let user = users.first ?? UserProfile(context: context)
            
            user.appleID = appleID
            user.email = email
            
            if let fullName = fullName {
                user.firstName = fullName.givenName
                user.lastName = fullName.familyName
            }
            
            if user.id == nil {
                user.id = UUID()
                user.createdAt = Date()
                
                let preferences = UserPreferences(context: context)
                preferences.themeMode = "dark"
                preferences.syncWithiCloud = true
                preferences.enableNotifications = true
                preferences.showTraffic = false
                preferences.defaultMapType = "standard"
                preferences.preferredUnits = "imperial"
                user.preferences = preferences
            }
            
            user.updatedAt = Date()
            
            try context.save()
            currentUser = user
            
            UserDefaults.standard.set(appleID, forKey: "appleUserID")
            
        } catch {
            print("Failed to save user: \(error)")
        }
    }
}

// MARK: - Apple Sign In Delegate
extension AuthenticationManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }
        
        let appleID = appleIDCredential.user
        let email = appleIDCredential.email
        let fullName = appleIDCredential.fullName
        
        DispatchQueue.main.async {
            self.isAuthenticated = true
            self.userEmail = email ?? self.userEmail
            
            if let fullName = fullName {
                self.userFullName = "\(fullName.givenName ?? "") \(fullName.familyName ?? "")".trimmingCharacters(in: .whitespaces)
            }
            
            self.createOrUpdateUser(appleID: appleID, email: email, fullName: fullName)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple Sign In failed: \(error.localizedDescription)")
    }
}

// MARK: - Presentation Context Provider
extension AuthenticationManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}