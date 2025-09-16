//
//  LoginView.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-14.
//

import SwiftUI
import Foundation

// MARK: - Login Errors
enum LoginError: Error, LocalizedError {
    case networkError
    case timeout
    case invalidCredentials
    case accountLocked
    case serverError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection failed"
        case .timeout:
            return "Request timeout"
        case .invalidCredentials:
            return "Invalid email or password"
        case .accountLocked:
            return "Account temporarily locked"
        case .serverError, .unknown:
            return "Login temporarily unavailable. Please try again later."
        }
    }
}

// MARK: - Login View
struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var showRegistration = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [.black, .gray, .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Form card
                        formCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                // Language toggle
                languageToggle
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.userFriendlyErrorMessage)
        }
        .alert("Success", isPresented: $viewModel.showSuccess) {
            Button("OK") {
                // Navigate to main app
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text(viewModel.translations["loginSuccess"] ?? "Welcome back!")
        }
        .sheet(isPresented: $showRegistration) {
            RegisterView()
        }
    }
    
    private var languageToggle: some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    Button("EN") {
                        viewModel.currentLanguage = "en"
                    }
                    .buttonStyle(LanguageButtonStyle(isSelected: viewModel.currentLanguage == "en"))
                    
                    Button("FR") {
                        viewModel.currentLanguage = "fr"
                    }
                    .buttonStyle(LanguageButtonStyle(isSelected: viewModel.currentLanguage == "fr"))
                }
                .padding(.trailing, 20)
            }
            Spacer()
        }
        .padding(.top, 50)
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.red)
                    .frame(width: 64, height: 64)
                    .shadow(radius: 8)
                
                Image(systemName: "mappin.and.ellipse")
                    .font(.title)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text(viewModel.translations["welcome"] ?? "Welcome to Camino")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(viewModel.translations["subtitle"] ?? "Sign in to continue")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var formCard: some View {
        VStack(spacing: 20) {
            if !viewModel.userFriendlyErrorMessage.isEmpty {
                Text(viewModel.userFriendlyErrorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            VStack(spacing: 16) {
                // Email
                SecureTextField(
                    text: $viewModel.email,
                    placeholder: viewModel.translations["email"] ?? "Email",
                    keyboardType: .emailAddress,
                    errorMessage: viewModel.emailError,
                    isSecure: false
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                
                // Password
                SecureTextField(
                    text: $viewModel.password,
                    placeholder: viewModel.translations["password"] ?? "Password",
                    errorMessage: viewModel.passwordError,
                    isSecure: true
                )
                
                // Forgot password link
                HStack {
                    Spacer()
                    Button(viewModel.translations["forgotPassword"] ?? "Forgot Password?") {
                        // TODO: Implement forgot password
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                }
            }
            
            // Login button
            Button(action: {
                Task {
                    await viewModel.login()
                }
            }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(viewModel.isLoading ?
                         (viewModel.translations["signingIn"] ?? "Signing in...") :
                         (viewModel.translations["signIn"] ?? "Sign In"))
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.isLoading)
            
            // Registration link
            Button(action: {
                showRegistration = true
            }) {
                HStack {
                    Text(viewModel.translations["noAccount"] ?? "Don't have an account?")
                        .foregroundColor(.secondary)
                    Text(viewModel.translations["register"] ?? "Sign up")
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
                .font(.subheadline)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Login View Model
@MainActor
class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    
    @Published var currentLanguage = "en" {
        didSet {
            clearErrors()
        }
    }
    
    @Published var isLoading = false
    @Published var showError = false
    @Published var showSuccess = false
    @Published var userFriendlyErrorMessage = ""
    
    // Field-specific errors
    @Published var emailError = ""
    @Published var passwordError = ""
    
    private var lastAttemptTime: Date?
    private var attemptCount = 0
    private let maxAttempts = 3
    private let lockoutDuration: TimeInterval = 300 // 5 minutes
    
    var translations: [String: String] {
        if currentLanguage == "fr" {
            return [
                "welcome": "Bienvenue sur Camino",
                "subtitle": "Connectez-vous pour continuer",
                "email": "Adresse courriel",
                "password": "Mot de passe",
                "signIn": "Se connecter",
                "signingIn": "Connexion...",
                "forgotPassword": "Mot de passe oublié?",
                "noAccount": "Vous n'avez pas de compte?",
                "register": "S'inscrire",
                "emailRequired": "Le courriel est requis",
                "invalidEmail": "Adresse courriel invalide",
                "passwordRequired": "Le mot de passe est requis",
                "passwordTooShort": "Le mot de passe doit contenir au moins 8 caractères",
                "loginError": "Connexion échouée. Vérifiez vos informations.",
                "loginSuccess": "Connexion réussie! Bienvenue.",
                "tooManyAttempts": "Trop de tentatives. Veuillez attendre avant de réessayer."
            ]
        } else {
            return [
                "welcome": "Welcome to Camino",
                "subtitle": "Sign in to continue",
                "email": "Email",
                "password": "Password",
                "signIn": "Sign In",
                "signingIn": "Signing in...",
                "forgotPassword": "Forgot Password?",
                "noAccount": "Don't have an account?",
                "register": "Sign up",
                "emailRequired": "Email is required",
                "invalidEmail": "Invalid email address",
                "passwordRequired": "Password is required",
                "passwordTooShort": "Password must be at least 8 characters",
                "loginError": "Login failed. Please check your credentials.",
                "loginSuccess": "Login successful! Welcome back.",
                "tooManyAttempts": "Too many attempts. Please wait before trying again."
            ]
        }
    }
    
    func login() async {
        // Rate limiting check
        if let lastTime = lastAttemptTime {
            let timeSinceLastAttempt = Date().timeIntervalSince(lastTime)
            if attemptCount >= maxAttempts && timeSinceLastAttempt < lockoutDuration {
                let remainingTime = Int(lockoutDuration - timeSinceLastAttempt)
                userFriendlyErrorMessage = "\(translations["tooManyAttempts"] ?? "Too many attempts") (\(remainingTime)s)"
                showError = true
                return
            } else if timeSinceLastAttempt >= lockoutDuration {
                attemptCount = 0 // Reset attempts after lockout period
            }
        }
        
        guard validateForm() else { return }
        
        guard let validatedData = validateAndPrepareData() else {
            return
        }
        
        lastAttemptTime = Date()
        attemptCount += 1
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await performLoginWithRetry(validatedData)
            SecurityLogger.logAttempt(email: email, success: true)
            attemptCount = 0 // Reset on success
            showSuccess = true
        } catch let error as LoginError {
            SecurityLogger.logAttempt(email: email, success: false, error: error.localizedDescription)
            userFriendlyErrorMessage = error.localizedDescription
            showError = true
        } catch {
            SecurityLogger.logAttempt(email: email, success: false, error: "Unknown error")
            userFriendlyErrorMessage = translations["loginError"] ?? "Login failed"
            showError = true
        }
    }
    
    private func validateAndPrepareData() -> [String: Any]? {
        let emailTrimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let passwordTrimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard isValidEmail(emailTrimmed) else {
            emailError = translations["invalidEmail"] ?? "Invalid email"
            return nil
        }
        
        return [
            "email": emailTrimmed,
            "password": passwordTrimmed
        ]
    }
    
    private func performLoginWithRetry(_ data: [String: Any]) async throws {
        var lastError: LoginError?
        
        for attempt in 1...APIConfig.maxRetries {
            do {
                try await performSecureLoginCall(data)
                return
            } catch let error as LoginError {
                lastError = error
                
                // Don't retry for certain errors
                if case .invalidCredentials = error, case .accountLocked = error {
                    throw error
                }
                
                if attempt < APIConfig.maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(attempt * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? LoginError.unknown
    }
    
    private func performSecureLoginCall(_ data: [String: Any]) async throws {
        guard let url = URL(string: "\(APIConfig.baseURL)/auth/api/auth/login") else {
            throw LoginError.networkError
        }
        
        var request = URLRequest(url: url, timeoutInterval: APIConfig.timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(currentLanguage, forHTTPHeaderField: "Accept-Language")
        request.setValue("Camino-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
        } catch {
            throw LoginError.networkError
        }
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LoginError.networkError
        }
        
        switch httpResponse.statusCode {
        case 200:
            // Parse and store tokens
            if let tokenData = parseTokenResponse(responseData) {
                await storeTokensSecurely(tokenData)
            }
            return
        case 401:
            throw LoginError.invalidCredentials
        case 423:
            throw LoginError.accountLocked
        case 408, 504:
            throw LoginError.timeout
        case 429:
            throw LoginError.accountLocked // Mask rate limiting as account locked
        case 500...599:
            throw LoginError.serverError
        default:
            throw LoginError.unknown
        }
    }
    
    private func parseTokenResponse(_ data: Data) -> [String: Any]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }
    
    private func storeTokensSecurely(_ tokenData: [String: Any]) async {
        // TODO: Store tokens in Keychain
        if let accessToken = tokenData["access_token"] as? String {
            UserDefaults.standard.set(accessToken, forKey: "access_token")
        }
        if let refreshToken = tokenData["refresh_token"] as? String {
            UserDefaults.standard.set(refreshToken, forKey: "refresh_token")
        }
    }
    
    private func validateForm() -> Bool {
        clearErrors()
        var isValid = true
        
        let emailTrimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if emailTrimmed.isEmpty {
            emailError = translations["emailRequired"] ?? "Required"
            isValid = false
        } else if !isValidEmail(emailTrimmed) {
            emailError = translations["invalidEmail"] ?? "Invalid email"
            isValid = false
        }
        
        if password.isEmpty {
            passwordError = translations["passwordRequired"] ?? "Required"
            isValid = false
        } else if password.count < 8 {
            passwordError = translations["passwordTooShort"] ?? "Too short"
            isValid = false
        }
        
        return isValid
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        guard email.count <= 254, !email.isEmpty else { return false }
        
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return false
        }
        
        let range = NSRange(location: 0, length: email.utf16.count)
        let matches = detector.matches(in: email, options: [], range: range)
        
        guard matches.count == 1,
              let match = matches.first,
              match.range.length == email.utf16.count,
              let url = match.url,
              url.scheme == "mailto" else {
            return false
        }
        
        return true
    }
    
    private func clearErrors() {
        emailError = ""
        passwordError = ""
        userFriendlyErrorMessage = ""
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
