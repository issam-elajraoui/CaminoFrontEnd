//
//  LocationPermissionView.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-16.
//
import SwiftUI
import CoreLocation

// MARK: - Vue de demande de permissions GPS
struct LocationPermissionView: View {
    @StateObject private var locationService = LocationService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentLanguage = "en"
    @State private var showSettings = false
    
    let onPermissionGranted: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background canadien
                canadianBackground
                
                VStack(spacing: 0) {
                    // Header avec toggle langue
                    headerSection
                    
                    // Contenu principal
                    ScrollView {
                        VStack(spacing: 24) {
                            // Icône et titre
                            titleSection
                            
                            // Explication
                            explanationSection
                            
                            // Boutons d'action
                            actionButtonsSection
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .alert("Paramètres", isPresented: $showSettings) {
            Button("Ouvrir Paramètres") {
                openSettings()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text(translations["settingsMessage"] ?? "Please enable location services in Settings")
        }
        .onAppear {
            checkInitialPermissionStatus()
        }
        .onChange(of: locationService.authorizationStatus) { _, newStatus in
            handlePermissionChange(newStatus)
        }
    }
    
    // MARK: - Background canadien
    private var canadianBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.white,
                Color.gray.opacity(0.1)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Header avec toggle langue
    private var headerSection: some View {
        HStack {
            // Logo/Titre Camino
            Text("Camino")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.red)
            
            Spacer()
            
            // Toggle langue
            languageToggleButtons
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
    
    // MARK: - Toggle de langue (réutilisé)
    private var languageToggleButtons: some View {
        HStack(spacing: 0) {
            Button(action: {
                currentLanguage = "en"
            }) {
                Text("EN")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(currentLanguage == "en" ? .white : .gray)
                    .frame(width: 40, height: 28)
                    .background(currentLanguage == "en" ? Color.red : Color.clear)
            }
            
            Button(action: {
                currentLanguage = "fr"
            }) {
                Text("FR")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(currentLanguage == "fr" ? .white : .gray)
                    .frame(width: 40, height: 28)
                    .background(currentLanguage == "fr" ? Color.red : Color.clear)
            }
        }
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Section titre et icône
    private var titleSection: some View {
        VStack(spacing: 20) {
            // Icône géolocalisation
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
            }
            
            // Titre principal
            VStack(spacing: 8) {
                Text(translations["title"] ?? "Location Access Required")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(translations["subtitle"] ?? "To find nearby drivers")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Section explication
    private var explanationSection: some View {
        VStack(spacing: 16) {
            // Points clés
            featureRow(
                icon: "car.circle.fill",
                title: translations["feature1Title"] ?? "Find nearby drivers",
                description: translations["feature1Desc"] ?? "We need your location to match you with available drivers in your area"
            )
            
            featureRow(
                icon: "map.circle.fill",
                title: translations["feature2Title"] ?? "Accurate pickup",
                description: translations["feature2Desc"] ?? "Your location helps us provide precise pickup coordinates"
            )
            
            featureRow(
                icon: "shield.circle.fill",
                title: translations["feature3Title"] ?? "Privacy protected",
                description: translations["feature3Desc"] ?? "Your location is only used during ride booking and never stored permanently"
            )
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Ligne de fonctionnalité
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.red)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Section boutons d'action
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Bouton principal selon le statut
            primaryActionButton
            
            // Bouton secondaire
            secondaryActionButton
        }
    }
    
    // MARK: - Bouton principal dynamique
    private var primaryActionButton: some View {
        Button(action: {
            handlePrimaryAction()
        }) {
            HStack {
                Image(systemName: primaryButtonIcon)
                    .font(.system(size: 16, weight: .medium))
                
                Text(primaryButtonText)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color.red)
        .foregroundColor(.white)
        .cornerRadius(12)
    }
    
    // MARK: - Bouton secondaire
    private var secondaryActionButton: some View {
        Button(action: {
            onCancel()
        }) {
            Text(translations["cancel"] ?? "Cancel")
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .frame(height: 44)
    }
    
    // MARK: - Propriétés calculées pour boutons
    private var primaryButtonText: String {
        switch locationService.authorizationStatus {
        case .notDetermined:
            return translations["allowLocation"] ?? "Allow Location Access"
        case .denied, .restricted:
            return translations["openSettings"] ?? "Open Settings"
        case .authorizedWhenInUse, .authorizedAlways:
            return translations["continue"] ?? "Continue"
        @unknown default:
            return translations["allowLocation"] ?? "Allow Location Access"
        }
    }
    
    private var primaryButtonIcon: String {
        switch locationService.authorizationStatus {
        case .notDetermined:
            return "location.fill"
        case .denied, .restricted:
            return "gearshape.fill"
        case .authorizedWhenInUse, .authorizedAlways:
            return "checkmark.circle.fill"
        @unknown default:
            return "location.fill"
        }
    }
    
    // MARK: - Traductions
    private var translations: [String: String] {
        if currentLanguage == "fr" {
            return [
                "title": "Accès à la localisation requis",
                "subtitle": "Pour trouver des conducteurs à proximité",
                "feature1Title": "Trouver des conducteurs",
                "feature1Desc": "Nous avons besoin de votre localisation pour vous connecter avec des conducteurs disponibles dans votre région",
                "feature2Title": "Prise en charge précise",
                "feature2Desc": "Votre localisation nous aide à fournir des coordonnées de prise en charge précises",
                "feature3Title": "Confidentialité protégée",
                "feature3Desc": "Votre localisation n'est utilisée que pendant la réservation et jamais stockée de façon permanente",
                "allowLocation": "Autoriser la localisation",
                "openSettings": "Ouvrir les paramètres",
                "continue": "Continuer",
                "cancel": "Annuler",
                "settingsMessage": "Veuillez activer les services de localisation dans les paramètres pour utiliser cette fonctionnalité."
            ]
        } else {
            return [
                "title": "Location Access Required",
                "subtitle": "To find nearby drivers",
                "feature1Title": "Find nearby drivers",
                "feature1Desc": "We need your location to match you with available drivers in your area",
                "feature2Title": "Accurate pickup",
                "feature2Desc": "Your location helps us provide precise pickup coordinates",
                "feature3Title": "Privacy protected",
                "feature3Desc": "Your location is only used during ride booking and never stored permanently",
                "allowLocation": "Allow Location Access",
                "openSettings": "Open Settings",
                "continue": "Continue",
                "cancel": "Cancel",
                "settingsMessage": "Please enable location services in Settings to use this feature."
            ]
        }
    }
    
    // MARK: - Méthodes d'action
    
    private func handlePrimaryAction() {
        switch locationService.authorizationStatus {
        case .notDetermined:
            locationService.requestLocationPermission()
        case .denied, .restricted:
            showSettings = true
        case .authorizedWhenInUse, .authorizedAlways:
            onPermissionGranted()
        @unknown default:
            locationService.requestLocationPermission()
        }
    }
    
    private func openSettings() {
        Task { @MainActor in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                await UIApplication.shared.open(settingsUrl)
            }
        }
    }
    
    private func checkInitialPermissionStatus() {
        // Si déjà autorisé, continuer automatiquement
        if locationService.authorizationStatus == .authorizedWhenInUse ||
           locationService.authorizationStatus == .authorizedAlways {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onPermissionGranted()
            }
        }
    }
    
    private func handlePermissionChange(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission accordée, continuer
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onPermissionGranted()
            }
        case .denied, .restricted:
            // Permission refusée, ne rien faire (utilisateur doit aller aux paramètres)
            break
        case .notDetermined:
            // En attente de décision
            break
        @unknown default:
            break
        }
    }
}

// MARK: - Preview Provider
struct LocationPermissionView_Previews: PreviewProvider {
    static var previews: some View {
        LocationPermissionView(
            onPermissionGranted: {
                print("Permission granted")
            },
            onCancel: {
                print("Cancelled")
            }
        )
    }
}
