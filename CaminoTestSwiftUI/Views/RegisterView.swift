import SwiftUI
import Foundation
import Contacts
import PhoneNumberKit

// MARK: - Configuration
struct APIConfig {
    static let baseURL = "http://10.2.2.181:8081"
    static let timeout: TimeInterval = 30
    static let maxRetries = 3
}

// MARK: - Error Types
enum RegistrationError: Error, LocalizedError {
    case networkError
    case timeout
    case invalidCredentials
    case accountExists
    case invalidData
    case serverError
    case unknown
    
    var errorDescription: String? {
        // Messages génériques pour ne pas divulguer d'infos critiques
        switch self {
        case .networkError:
            return "Network connection failed"
        case .timeout:
            return "Request timeout"
        case .invalidCredentials, .accountExists:
            return "Registration failed. Please check your information."
        case .invalidData:
            return "Invalid data provided"
        case .serverError, .unknown:
            return "Registration temporarily unavailable. Please try again later."
        }
    }
}

// MARK: - Security Logger
class SecurityLogger {
    static func logAttempt(email: String, success: Bool, error: String? = nil) {
        let maskedEmail = maskEmail(email)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        if success {
            print("[\(timestamp)] Registration SUCCESS: \(maskedEmail)")
        } else {
            print("[\(timestamp)] Registration FAILED: \(maskedEmail) - \(error ?? "unknown")")
        }
    }
    
    private static func maskEmail(_ email: String) -> String {
        let components = email.split(separator: "@")
        guard components.count == 2 else { return "***" }
        let username = components[0]
        let domain = components[1]
        
        if username.count > 2 {
            let masked = username.prefix(2) + String(repeating: "*", count: username.count - 2)
            return "\(masked)@\(domain)"
        }
        return "**@\(domain)"
    }
}

// MARK: - Main View
struct RegisterView: View {
    @StateObject private var viewModel = RegisterViewModel()
    @Environment(\.presentationMode) var presentationMode
    
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
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text(viewModel.translations["registrationSuccess"] ?? "Registration successful!")
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
                Text(viewModel.translations["title"] ?? "Join Camino")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(viewModel.translations["subtitle"] ?? "Create your passenger account")
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
                // Name fields
                HStack(spacing: 12) {
                    SecureTextField(
                        text: $viewModel.firstName,
                        placeholder: viewModel.translations["firstName"] ?? "First Name",
                        keyboardType: .namePhonePad,
                        errorMessage: viewModel.firstNameError,
                        isSecure: false
                    )
                    
                    SecureTextField(
                        text: $viewModel.lastName,
                        placeholder: viewModel.translations["lastName"] ?? "Last Name",
                        keyboardType: .namePhonePad,
                        errorMessage: viewModel.lastNameError,
                        isSecure: false
                    )
                }
                
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
                
                // Phone and Date of Birth
                HStack(spacing: 12) {
                    SecureTextField(
                        text: $viewModel.phone,
                        placeholder: viewModel.translations["phone"] ?? "Phone",
                        keyboardType: .phonePad,
                        errorMessage: viewModel.phoneError,
                        isSecure: false
                    )
                    
                    DateOfBirthField(
                        selectedDate: $viewModel.dateOfBirth,
                        placeholder: viewModel.translations["dateOfBirth"] ?? "Date of Birth",
                        errorMessage: viewModel.dateOfBirthError
                    )
                }
                
                // Password fields
                HStack(spacing: 12) {
                    SecureTextField(
                        text: $viewModel.password,
                        placeholder: viewModel.translations["password"] ?? "Password",
                        errorMessage: viewModel.passwordError,
                        isSecure: true
                    )
                    
                    SecureTextField(
                        text: $viewModel.confirmPassword,
                        placeholder: viewModel.translations["confirmPassword"] ?? "Confirm Password",
                        errorMessage: viewModel.confirmPasswordError,
                        isSecure: true
                    )
                }
                
                // Terms checkbox
                HStack {
                    Button(action: {
                        viewModel.termsAccepted.toggle()
                    }) {
                        Image(systemName: viewModel.termsAccepted ? "checkmark.square.fill" : "square")
                            .foregroundColor(viewModel.termsAccepted ? .red : .gray)
                            .font(.title2)
                    }
                    
                    Text(viewModel.translations["terms"] ?? "I accept the Terms of Service")
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                
                if !viewModel.termsError.isEmpty {
                    Text(viewModel.termsError)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            // Register button
            Button(action: {
                Task {
                    await viewModel.register()
                }
            }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(viewModel.isLoading ?
                         (viewModel.translations["creating"] ?? "Creating...") :
                         (viewModel.translations["register"] ?? "Create Account"))
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.isLoading)
            
            // Login link
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Text(viewModel.translations["haveAccount"] ?? "Already have an account?")
                        .foregroundColor(.secondary)
                    Text(viewModel.translations["signIn"] ?? "Sign in")
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

// MARK: - Enhanced View Model
@MainActor
class RegisterViewModel: ObservableObject {
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var phone = ""
    @Published var dateOfBirth = Date()
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var termsAccepted = false
    
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
    @Published var firstNameError = ""
    @Published var lastNameError = ""
    @Published var emailError = ""
    @Published var phoneError = ""
    @Published var dateOfBirthError = ""
    @Published var passwordError = ""
    @Published var confirmPasswordError = ""
    @Published var termsError = ""
    
    private var lastAttemptTime: Date?
    private var attemptCount = 0
    private let phoneNumberUtility = PhoneNumberUtility()
    
    var translations: [String: String] {
        if currentLanguage == "fr" {
            return [
                "title": "Rejoignez Camino",
                "subtitle": "Créez votre compte passager pour réserver des trajets",
                "firstName": "Prénom",
                "lastName": "Nom de famille",
                "email": "Adresse courriel",
                "phone": "Numéro de téléphone",
                "dateOfBirth": "Date de naissance",
                "password": "Mot de passe",
                "confirmPassword": "Confirmer le mot de passe",
                "terms": "J'accepte les Conditions d'utilisation",
                "register": "Créer le compte",
                "signIn": "Se connecter",
                "haveAccount": "Vous avez déjà un compte?",
                "creating": "Création...",
                "firstNameRequired": "Le prénom est requis",
                "lastNameRequired": "Le nom de famille est requis",
                "emailRequired": "Le courriel est requis",
                "invalidEmail": "Adresse courriel invalide",
                "phoneRequired": "Le numéro de téléphone est requis",
                "invalidPhone": "Numéro de téléphone invalide",
                "passwordRequired": "Le mot de passe est requis",
                "passwordTooShort": "Le mot de passe doit contenir au moins 8 caractères",
                "passwordWeak": "Le mot de passe doit contenir une majuscule, une minuscule, un chiffre et un caractère spécial",
                "passwordsNotMatch": "Les mots de passe ne correspondent pas",
                "dateOfBirthRequired": "La date de naissance est requise",
                "mustBe18": "Vous devez avoir au moins 18 ans",
                "termsRequired": "Vous devez accepter les conditions",
                "registrationError": "L'inscription a échoué. Veuillez réessayer.",
                "registrationSuccess": "Inscription réussie! Veuillez vous connecter.",
                "tooManyAttempts": "Trop de tentatives. Veuillez attendre avant de réessayer."
            ]
        } else {
            return [
                "title": "Join Camino",
                "subtitle": "Create your passenger account to book rides",
                "firstName": "First Name",
                "lastName": "Last Name",
                "email": "Email Address",
                "phone": "Phone Number",
                "dateOfBirth": "Date of Birth",
                "password": "Password",
                "confirmPassword": "Confirm Password",
                "terms": "I accept the Terms of Service",
                "register": "Create Account",
                "signIn": "Sign in",
                "haveAccount": "Already have an account?",
                "creating": "Creating...",
                "firstNameRequired": "First name is required",
                "lastNameRequired": "Last name is required",
                "emailRequired": "Email is required",
                "invalidEmail": "Invalid email address",
                "phoneRequired": "Phone number is required",
                "invalidPhone": "Invalid phone number",
                "passwordRequired": "Password is required",
                "passwordTooShort": "Password must be at least 8 characters",
                "passwordWeak": "Password must contain uppercase, lowercase, number and special character",
                "passwordsNotMatch": "Passwords do not match",
                "dateOfBirthRequired": "Date of birth is required",
                "mustBe18": "You must be at least 18 years old",
                "termsRequired": "You must accept the terms",
                "registrationError": "Registration failed. Please try again.",
                "registrationSuccess": "Registration successful! Please login.",
                "tooManyAttempts": "Too many attempts. Please wait before trying again."
            ]
        }
    }
    
    func register() async {
        // Rate limiting côté client
        if let lastTime = lastAttemptTime, Date().timeIntervalSince(lastTime) < 2 {
            userFriendlyErrorMessage = translations["tooManyAttempts"] ?? "Too many attempts"
            showError = true
            return
        }
        
        guard validateForm() else { return }
        
        // Validation et préparation des données
        guard let validatedData = validateAndPrepareData() else {
            return // Les erreurs sont déjà définies dans validateAndPrepareData
        }
        
        lastAttemptTime = Date()
        attemptCount += 1
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await performRegistrationWithRetry(validatedData)
            SecurityLogger.logAttempt(email: email, success: true)
            showSuccess = true
        } catch let error as RegistrationError {
            SecurityLogger.logAttempt(email: email, success: false, error: error.localizedDescription)
            userFriendlyErrorMessage = error.localizedDescription
            showError = true
        } catch {
            SecurityLogger.logAttempt(email: email, success: false, error: "Unknown error")
            userFriendlyErrorMessage = translations["registrationError"] ?? "Registration failed"
            showError = true
        }
    }
    
    private func validateAndPrepareData() -> [String: Any]? {
        // Validation stricte - rejeter si invalide
        let emailTrimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let phoneTrimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstNameTrimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastNameTrimmed = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard isValidEmail(emailTrimmed) else {
            emailError = translations["invalidEmail"] ?? "Invalid email"
            return nil
        }
        
        // Validation phone avec PhoneNumberKit
        guard isValidPhone(phoneTrimmed) else {
            phoneError = translations["invalidPhone"] ?? "Invalid phone"
            return nil
        }
        
        // Formatage phone pour API
        guard let formattedPhone = formatPhoneForAPI(phoneTrimmed) else {
            phoneError = translations["invalidPhone"] ?? "Invalid phone"
            return nil
        }
        
        guard isValidName(firstNameTrimmed) else {
            firstNameError = translations["firstNameRequired"] ?? "Invalid name"
            return nil
        }
        
        guard isValidName(lastNameTrimmed) else {
            lastNameError = translations["lastNameRequired"] ?? "Invalid name"
            return nil
        }
        
        return [
            "email": emailTrimmed,
            "password": password,
            "phone": formattedPhone, // Format E164 pour l'API
            "first_name": firstNameTrimmed,
            "last_name": lastNameTrimmed,
            "date_of_birth": formatDateForAPI(dateOfBirth),
            "user_type": "CLIENT",
            "terms_accepted": termsAccepted
        ]
    }
    
    private func performRegistrationWithRetry(_ data: [String: Any]) async throws {
        var lastError: RegistrationError?
        
        for attempt in 1...APIConfig.maxRetries {
            do {
                try await performSecureAPICall(data)
                return
            } catch let error as RegistrationError {
                lastError = error
                
                // Ne pas retry pour certaines erreurs
                if case .accountExists = error, case .invalidCredentials = error {
                    throw error
                }
                
                // Attendre avant retry
                if attempt < APIConfig.maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(attempt * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? RegistrationError.unknown
    }
    
    private func performSecureAPICall(_ data: [String: Any]) async throws {
        guard let url = URL(string: "\(APIConfig.baseURL)/api/auth/register") else {
            throw RegistrationError.invalidData
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
            throw RegistrationError.invalidData
        }
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RegistrationError.networkError
        }
        
        switch httpResponse.statusCode {
        case 201:
            return
        case 400:
            if let errorData = parseErrorResponse(responseData),
               errorData.contains("already exists") {
                throw RegistrationError.accountExists
            }
            throw RegistrationError.invalidCredentials
        case 408, 504:
            throw RegistrationError.timeout
        case 429:
            throw RegistrationError.invalidCredentials // Masquer rate limiting
        case 500...599:
            throw RegistrationError.serverError
        default:
            throw RegistrationError.unknown
        }
    }
    
    private func parseErrorResponse(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let details = json["details"] as? [String],
              let firstDetail = details.first else {
            return nil
        }
        return firstDetail
    }
    
    private func validateForm() -> Bool {
        clearErrors()
        var isValid = true
        
        // Validation nom/prénom
        if !isValidName(firstName.trimmingCharacters(in: .whitespacesAndNewlines)) {
            firstNameError = translations["firstNameRequired"] ?? "Required"
            isValid = false
        }
        
        if !isValidName(lastName.trimmingCharacters(in: .whitespacesAndNewlines)) {
            lastNameError = translations["lastNameRequired"] ?? "Required"
            isValid = false
        }
        
        // Validation email renforcée
        let emailTrimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if emailTrimmed.isEmpty {
            emailError = translations["emailRequired"] ?? "Required"
            isValid = false
        } else if !isValidEmail(emailTrimmed) {
            emailError = translations["invalidEmail"] ?? "Invalid email"
            isValid = false
        }
        
        // Validation téléphone avec PhoneNumberKit
        let phoneTrimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        if phoneTrimmed.isEmpty {
            phoneError = translations["phoneRequired"] ?? "Required"
            isValid = false
        } else if !isValidPhone(phoneTrimmed) {
            phoneError = translations["invalidPhone"] ?? "Invalid phone"
            isValid = false
        }
        
        // Validation mot de passe renforcée
        if password.isEmpty {
            passwordError = translations["passwordRequired"] ?? "Required"
            isValid = false
        } else if password.count < 8 {
            passwordError = translations["passwordTooShort"] ?? "Too short"
            isValid = false
        } else if !isStrongPassword(password) {
            passwordError = translations["passwordWeak"] ?? "Weak password"
            isValid = false
        }
        
        if password != confirmPassword {
            confirmPasswordError = translations["passwordsNotMatch"] ?? "Passwords don't match"
            isValid = false
        }
        
        if !isAtLeast18YearsOld(dateOfBirth) {
            dateOfBirthError = translations["mustBe18"] ?? "Must be 18+"
            isValid = false
        }
        
        if !termsAccepted {
            termsError = translations["termsRequired"] ?? "Accept terms required"
            isValid = false
        }
        
        return isValid
    }
    
    // MARK: - PhoneNumberKit Integration
    private func isValidPhone(_ phoneNumber: String) -> Bool {
        guard !phoneNumber.isEmpty else { return false }
        
        do {
            _ = try phoneNumberUtility.parse(phoneNumber)
            return true  // If parsing succeeds, the number is valid
        } catch {
            return false  // If parsing fails, the number is invalid
        }
    }
    
    private func formatPhoneForAPI(_ phoneNumber: String) -> String? {
        do {
            let parsedNumber = try phoneNumberUtility.parse(phoneNumber)
            // Format E164 pour l'API (ex: +14155552671)
            return phoneNumberUtility.format(parsedNumber, toType: PhoneNumberFormat.e164)
        } catch {
            return nil
        }
    }
    
    private func formatPhoneForDisplay(_ phoneNumber: String) -> String {
        do {
            let parsedNumber = try phoneNumberUtility.parse(phoneNumber)
            // Format national pour l'affichage (ex: (415) 555-2671)
            return phoneNumberUtility.format(parsedNumber, toType: PhoneNumberFormat.national)
        } catch {
            return phoneNumber // Retourner tel quel si parsing échoue
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        guard email.count <= 254, !email.isEmpty else { return false }
        
        // Utiliser NSDataDetector pour validation email
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return false
        }
        
        let range = NSRange(location: 0, length: email.utf16.count)
        let matches = detector.matches(in: email, options: [], range: range)
        
        // Vérifier qu'il y a exactement une correspondance et que c'est un email
        guard matches.count == 1,
              let match = matches.first,
              match.range.length == email.utf16.count,
              let url = match.url,
              url.scheme == "mailto" else {
            return false
        }
        
        return true
    }
    
    private func isValidName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 50 else { return false }
        
        // Caractères autorisés : lettres, espaces, apostrophes, tirets
        let allowedCharacters = CharacterSet.letters
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "'-"))
        
        // Vérifier que tous les caractères sont autorisés
        let hasInvalidChars = name.rangeOfCharacter(from: allowedCharacters.inverted) != nil
        
        // Vérifier que ce n'est pas que des espaces ou caractères spéciaux
        let hasValidContent = name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 1
        
        return !hasInvalidChars && hasValidContent
    }
    
    private func isStrongPassword(_ password: String) -> Bool {
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecialChar = password.range(of: "[!@#$%^&*()_+\\-=\\[\\]{};':\"\\\\|,.<>\\/?]", options: .regularExpression) != nil
        
        return hasUppercase && hasLowercase && hasNumber && hasSpecialChar
    }
    
    private func isAtLeast18YearsOld(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: date, to: now)
        return (ageComponents.year ?? 0) >= 18
    }
    
    private func formatDateForAPI(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
    
    private func clearErrors() {
        firstNameError = ""
        lastNameError = ""
        emailError = ""
        phoneError = ""
        dateOfBirthError = ""
        passwordError = ""
        confirmPasswordError = ""
        termsError = ""
        userFriendlyErrorMessage = ""
    }
}

// MARK: - Enhanced UI Components
struct SecureTextField: View {
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    let errorMessage: String
    let isSecure: Bool
    @State private var showSecure = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if isSecure && !showSecure {
                    SecureField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .onChange(of: text) { oldValue, newValue in
                            // Apply input filtering based on keyboard type
                            let filteredInput = applyInputFilter(newValue, for: keyboardType)
                            if filteredInput != newValue {
                                text = filteredInput
                            }
                            
                            // Apply specific formatting for phone numbers
                            if keyboardType == .phonePad {
                                formatPhoneInput(filteredInput)
                            }
                        }
                }
                
                if isSecure {
                    Button(action: { showSecure.toggle() }) {
                        Image(systemName: showSecure ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(errorMessage.isEmpty ? Color.gray.opacity(0.3) : Color.red, lineWidth: 1)
            )
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Input Filtering Methods
    private func applyInputFilter(_ input: String, for keyboardType: UIKeyboardType) -> String {
        switch keyboardType {
        case .phonePad:
            return filterPhoneInput(input)
        case .namePhonePad:
            return filterNameInput(input)
        case .emailAddress:
            return filterEmailInput(input)
        default:
            return input
        }
    }
    
    private func filterPhoneInput(_ input: String) -> String {
        // Allow only digits, spaces, +, -, (, ), and common separators
        let allowedCharacters = CharacterSet(charactersIn: "0123456789 +()-.")
        let filtered = input.unicodeScalars.filter { allowedCharacters.contains($0) }.map(String.init).joined()
        
        // Limit to reasonable phone number length (international numbers can be up to ~15 digits + formatting)
        return String(filtered.prefix(25))
    }
    
    private func filterNameInput(_ input: String) -> String {
        // Allow letters, spaces, apostrophes, hyphens, and dots (for initials)
        let allowedCharacters = CharacterSet.letters
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "'-. "))
        
        let filtered = input.unicodeScalars.filter { allowedCharacters.contains($0) }.map(String.init).joined()
        
        // Limit name length to 50 characters
        return String(filtered.prefix(50))
    }
    
    private func filterEmailInput(_ input: String) -> String {
        // Allow alphanumeric, @, ., -, _, +
        let allowedCharacters = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "@.-_+"))
        
        let filtered = input.unicodeScalars.filter { allowedCharacters.contains($0) }.map(String.init).joined()
        
        // Limit email length to 254 characters (RFC standard)
        return String(filtered.prefix(254))
    }
    
    private func formatPhoneInput(_ input: String) {
        // Only proceed if input is not empty
        guard !input.isEmpty else { return }
        
        // Create a single PhoneNumberUtility instance for better performance
        let phoneNumberUtility = PhoneNumberUtility()
        
        do {
            // Try to parse and format the phone number
            let parsed = try phoneNumberUtility.parse(input)
            let formatted = phoneNumberUtility.format(parsed, toType: PhoneNumberFormat.national)
            
            // Only update if the formatted version is different
            if formatted != text {
                text = formatted
            }
        } catch {
            // If parsing fails, keep the filtered input as-is
            // This allows users to continue typing partial numbers
            if input != text && input.count <= 25 {
                text = input
            }
        }
    }
}
struct DateOfBirthField: View {
    @Binding var selectedDate: Date
    let placeholder: String
    let errorMessage: String
    @State private var showDatePicker = false
    @State private var tempDate: Date = Date()
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    private var maxDate: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: {
                tempDate = selectedDate
                showDatePicker = true
            }) {
                HStack {
                    Text(dateFormatter.string(from: selectedDate))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "calendar")
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(errorMessage.isEmpty ? Color.gray.opacity(0.3) : Color.red, lineWidth: 1)
                )
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationView {
                    DatePicker("", selection: $tempDate, in: Date.distantPast...maxDate, displayedComponents: .date)
                        .datePickerStyle(WheelDatePickerStyle())
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Cancel") { showDatePicker = false }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    selectedDate = tempDate
                                    showDatePicker = false
                                }
                                .fontWeight(.semibold)
                            }
                        }
                }
                .presentationDetents([.height(300)])
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.red.opacity(0.8) : Color.red)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct LanguageButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.red : Color.white)
            )
            .foregroundColor(isSelected ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView()
    }
}
