import SwiftUI
import AuthenticationServices
import CoreData
import UIKit

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
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        self.context = container.viewContext
        
        super.init()
        checkExistingUser()
    }
    
    func signInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    private func checkExistingUser() {
        if let appleUserID = UserDefaults.standard.string(forKey: "appleUserID") {
            fetchUserProfile(appleID: appleUserID)
        }
    }
    
    private func fetchUserProfile(appleID: String) {
        let request: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        request.predicate = NSPredicate(format: "appleID == %@", appleID)
        
        do {
            let users = try context.fetch(request)
            if let user = users.first {
                self.currentUser = user
                self.isAuthenticated = true
                self.userEmail = user.email ?? ""
                self.userFullName = "\(user.firstName ?? "") \(user.lastName ?? "")"
            }
        } catch {
            print("Failed to fetch user: \(error)")
        }
    }
    
    private func createOrUpdateUser(appleID: String, email: String?, fullName: PersonNameComponents?) {
        let request: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        request.predicate = NSPredicate(format: "appleID == %@", appleID)
        
        do {
            let users = try context.fetch(request)
            let user = users.first ?? UserProfile(context: context)
            
            user.appleID = appleID
            user.email = email ?? user.email
            user.firstName = fullName?.givenName ?? user.firstName
            user.lastName = fullName?.familyName ?? user.lastName
            user.updatedAt = Date()
            
            if user.createdAt == nil {
                user.createdAt = Date()
                user.id = UUID()
                
                let preferences = UserPreferences(context: context)
                preferences.themeMode = "dark"
                preferences.syncWithiCloud = true
                preferences.enableNotifications = true
                user.preferences = preferences
            }
            
            try context.save()
            
            self.currentUser = user
            self.isAuthenticated = true
            self.userEmail = user.email ?? ""
            self.userFullName = "\(user.firstName ?? "") \(user.lastName ?? "")"
            
            UserDefaults.standard.set(appleID, forKey: "appleUserID")
            
        } catch {
            print("Failed to save user: \(error)")
        }
    }
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        userEmail = ""
        userFullName = ""
        UserDefaults.standard.removeObject(forKey: "appleUserID")
    }
}

extension AuthenticationManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }
        
        let appleID = appleIDCredential.user
        let email = appleIDCredential.email
        let fullName = appleIDCredential.fullName
        
        createOrUpdateUser(appleID: appleID, email: email, fullName: fullName)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Sign in with Apple failed: \(error.localizedDescription)")
    }
}

extension AuthenticationManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}