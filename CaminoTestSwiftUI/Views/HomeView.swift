import SwiftUI
import Foundation
import MapKit

// MARK: - Configuration de recherche
struct RideSearchConfig {
    static let baseURL = "http://10.2.2.181:8083/ride"
    static let matchingURL = "http://10.2.2.181:9002"
    static let timeout: TimeInterval = 20
    static let maxRetries = 2
    static let ottawaRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.4215, longitude: -75.6972),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    )
}

// MARK: - Erreurs de recherche
enum RideSearchError: Error, LocalizedError {
    case networkError
    case timeout
    case noDriversFound
    case invalidLocation
    case serviceUnavailable
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection failed"
        case .timeout:
            return "Search timeout"
        case .noDriversFound:
            return "No drivers available in your area"
        case .invalidLocation:
            return "Invalid pickup or destination"
        case .serviceUnavailable, .unknown:
            return "Service temporarily unavailable"
        }
    }
}

// MARK: - Annotation pour la carte
struct LocationAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType
    
    enum AnnotationType {
        case pickup
        case destination
        
        var color: Color {
            switch self {
            case .pickup: return .green
            case .destination: return .red
            }
        }
    }
}

// MARK: - Vue principale de recherche
struct RideSearchView: View {
    @StateObject private var viewModel = RideSearchViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    // Carte MapKit (65-70% de l'écran)
                    mapSection
                        .frame(height: geometry.size.height * 0.65)
                    
                    // Formulaire de recherche (35% de l'écran)
                    searchFormSection
                        .frame(height: geometry.size.height * 0.35)
                }
                
                // Toggle langue en overlay
                VStack {
                    HStack {
                        Spacer()
                        languageToggleButtons
                            .padding(.trailing, 20)
                            .padding(.top, 10)
                    }
                    Spacer()
                }
            }
        }
//        .ignoresSafeArea(.keyboard)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.userFriendlyErrorMessage)
        }
        .sheet(isPresented: $viewModel.showDriverResults) {
            DriverResultsView(
                drivers: viewModel.availableDrivers,
                onDriverSelected: { driver in
                    viewModel.selectDriver(driver)
                }
            )
        }
    }
    
    // MARK: - Section Carte
    private var mapSection: some View {
        Map {
            // Annotations des lieux
            ForEach(viewModel.annotations) { annotation in
                Marker(coordinate: annotation.coordinate) {
                    Text("")
                }
                .tint(annotation.type.color)
            }
            
            // Position utilisateur
            UserAnnotation()
        }
        .mapStyle(.standard)
        .onTapGesture(coordinateSpace: .local) { location in
            viewModel.handleMapTap(at: location)
        }
        .overlay(
            VStack {
                HStack {
                    Button("My Location") {
                        viewModel.centerOnUserLocation()
                    }
                    .padding(.horizontal)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
                    Spacer()
                }
                Spacer()
            }
            .padding()
        )
    }
    
    // MARK: - Toggle de langue
    private var languageToggleButtons: some View {
        HStack(spacing: 0) {
            Button(action: {
                viewModel.currentLanguage = "en"
            }) {
                Text("EN")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(viewModel.currentLanguage == "en" ? .white : .gray)
                    .frame(width: 40, height: 28)
                    .background(viewModel.currentLanguage == "en" ? Color.red : Color.clear)
            }
            
            Button(action: {
                viewModel.currentLanguage = "fr"
            }) {
                Text("FR")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(viewModel.currentLanguage == "fr" ? .white : .gray)
                    .frame(width: 40, height: 28)
                    .background(viewModel.currentLanguage == "fr" ? Color.red : Color.clear)
            }
        }
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Section formulaire de recherche compacte
    private var searchFormSection: some View {
        VStack(spacing: 0) {
            // Indicateur de glissement
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
            
            ScrollView {
                VStack(spacing: 12) {
                    // Titre
                    Text(viewModel.translations["findRide"] ?? "Find a Ride")
                        .font(.title3)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    
                    // Champs de localisation compacts
                    VStack(spacing: 8) {
                        CompactLocationField(
                            text: $viewModel.pickupAddress,
                            placeholder: viewModel.translations["pickupLocation"] ?? "Pickup Location",
                            errorMessage: viewModel.pickupError,
                            isPickup: true,
                            onLocationSelected: { location in
                                viewModel.setPickupLocation(location)
                            }
                        )
                        
                        CompactLocationField(
                            text: $viewModel.destinationAddress,
                            placeholder: viewModel.translations["destination"] ?? "Destination",
                            errorMessage: viewModel.destinationError,
                            isPickup: false,
                            onLocationSelected: { location in
                                viewModel.setDestinationLocation(location)
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Options compactes sur une ligne
                    HStack(spacing: 16) {
                        // Passagers
                        HStack(spacing: 4) {
                            Text(viewModel.translations["passengers"] ?? "Passengers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 8) {
                                Button("-") {
                                    if viewModel.passengerCount > 1 {
                                        viewModel.passengerCount -= 1
                                    }
                                }
                                .frame(width: 24, height: 24)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                                .disabled(viewModel.passengerCount <= 1)
                                
                                Text("\(viewModel.passengerCount)")
                                    .font(.footnote)
                                    .fontWeight(.medium)
                                    .frame(minWidth: 16)
                                
                                Button("+") {
                                    if viewModel.passengerCount < 8 {
                                        viewModel.passengerCount += 1
                                    }
                                }
                                .frame(width: 24, height: 24)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                                .disabled(viewModel.passengerCount >= 8)
                            }
                        }
                        
                        Spacer()
                        
                        // Type de service compact
                        Picker("", selection: $viewModel.serviceType) {
                            Text(viewModel.translations["economy"] ?? "Eco").tag("economy")
                            Text(viewModel.translations["standard"] ?? "Std").tag("standard")
                            Text(viewModel.translations["premium"] ?? "Prem").tag("premium")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(maxWidth: 160)
                    }
                    .padding(.horizontal, 20)
                    
                    // Bouton de recherche
                    Button(action: {
                        Task {
                            await viewModel.searchDrivers()
                        }
                    }) {
                        HStack {
                            if viewModel.isSearching {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(viewModel.isSearching ?
                                 (viewModel.translations["searching"] ?? "Searching...") :
                                 (viewModel.translations["findDrivers"] ?? "Find Drivers"))
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(viewModel.canSearch ? Color.red : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(viewModel.isSearching || !viewModel.canSearch)
                    .padding(.horizontal, 20)
                    
                    // Estimation si disponible
                    if viewModel.showEstimate {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.translations["estimatedFare"] ?? "Est. Fare")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(viewModel.estimatedFare)
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(viewModel.translations["distance"] ?? "Distance")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(viewModel.estimatedDistance)
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(10)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
    }
}

// MARK: - Champ de localisation compact
struct CompactLocationField: View {
    @Binding var text: String
    let placeholder: String
    let errorMessage: String
    let isPickup: Bool
    let onLocationSelected: (CLLocationCoordinate2D) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isPickup ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                TextField(placeholder, text: $text)
                    .font(.system(size: 14))
                    .disableAutocorrection(true)
                    .onChange(of: text) { oldValue, newValue in
                        let sanitized = sanitizeLocationInput(newValue)
                        if sanitized != newValue {
                            text = sanitized
                        }
                    }
                
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(errorMessage.isEmpty ? Color.clear : Color.red, lineWidth: 1)
            )
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.leading, 18)
            }
        }
    }
    
    private func sanitizeLocationInput(_ input: String) -> String {
        let maxLength = 200
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: ",-./()#"))
        
        let filtered = input.unicodeScalars.filter { allowedCharacters.contains($0) }.map(String.init).joined()
        return String(filtered.prefix(maxLength))
    }
}


// MARK: - ViewModel de recherche de course
@MainActor
class RideSearchViewModel: ObservableObject {
    // MARK: - Published Properties - Interface
    @Published var mapRegion = RideSearchConfig.ottawaRegion
    @Published var annotations: [LocationAnnotation] = []
    
    @Published var currentLanguage = "en" {
        didSet {
            clearErrors()
        }
    }
    
    @Published var pickupAddress = ""
    @Published var destinationAddress = ""
    @Published var passengerCount = 1
    @Published var serviceType = "standard"
    
    // MARK: - Published Properties - États
    @Published var isSearching = false
    @Published var showError = false
    @Published var showDriverResults = false
    @Published var showLocationPermission = false
    @Published var userFriendlyErrorMessage = ""
    
    @Published var pickupError = ""
    @Published var destinationError = ""
    
    @Published var showEstimate = false
    @Published var estimatedFare = "$0.00"
    @Published var estimatedDistance = "0 km"
    
    @Published var availableDrivers: [Driver] = []
    
    // MARK: - Services et données privées
    @StateObject private var locationService = LocationService()
    private var pickupCoordinate: CLLocationCoordinate2D?
    private var destinationCoordinate: CLLocationCoordinate2D?
    
    // MARK: - Computed Properties
    var canSearch: Bool {
        !pickupAddress.isEmpty && !destinationAddress.isEmpty &&
        pickupCoordinate != nil && destinationCoordinate != nil
    }
    
    // Exposition du LocationService pour CompactLocationField
    var locationServiceProtocol: any LocationServiceProtocol {
        locationService
    }
    
    // MARK: - Initialisation et gestion permissions
    init() {
        // Ne pas accéder au locationService ici - sera fait via onAppear
    }
    
    func onViewAppear() {
        checkLocationPermissions()
    }
    
    private func checkLocationPermissions() {
        let status = locationService.authorizationStatus
        showLocationPermission = !(status == .authorizedWhenInUse || status == .authorizedAlways)
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            centerOnUserLocationWithService()
        }
    }
    
    func onLocationPermissionGranted() {
        showLocationPermission = false
        centerOnUserLocationWithService()
    }
    
    private func centerOnUserLocationWithService() {
        if let userLocation = locationService.currentLocation {
            mapRegion = MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        } else {
            locationService.startLocationUpdates()
        }
    }
    
    // MARK: - Traductions complètes
    var translations: [String: String] {
        if currentLanguage == "fr" {
            return [
                "findRide": "Trouver une course",
                "pickupLocation": "Lieu de départ",
                "destination": "Destination",
                "passengers": "Passagers",
                "serviceType": "Type",
                "economy": "Éco",
                "standard": "Std",
                "premium": "Prem",
                "searching": "Recherche...",
                "findDrivers": "Chercher",
                "estimatedFare": "Tarif est.",
                "distance": "Distance",
                "pickupRequired": "Lieu de départ requis",
                "destinationRequired": "Destination requise",
                "noDriversFound": "Aucun conducteur disponible",
                "searchError": "Erreur de recherche",
                "locationError": "Erreur de localisation",
                "addressNotFound": "Adresse introuvable",
                "invalidAddress": "Adresse invalide",
                "permissionDenied": "Permission de localisation refusée",
                "locationDisabled": "Services de localisation désactivés"
            ]
        } else {
            return [
                "findRide": "Find a Ride",
                "pickupLocation": "Pickup Location",
                "destination": "Destination",
                "passengers": "Passengers",
                "serviceType": "Type",
                "economy": "Eco",
                "standard": "Std",
                "premium": "Prem",
                "searching": "Searching...",
                "findDrivers": "Find Drivers",
                "estimatedFare": "Est. Fare",
                "distance": "Distance",
                "pickupRequired": "Pickup location required",
                "destinationRequired": "Destination required",
                "noDriversFound": "No drivers available",
                "searchError": "Search failed",
                "locationError": "Location error",
                "addressNotFound": "Address not found",
                "invalidAddress": "Invalid address",
                "permissionDenied": "Location permission denied",
                "locationDisabled": "Location services disabled"
            ]
        }
    }
    
    // MARK: - Méthodes d'interaction avec la carte
    func handleMapTap(at location: CGPoint) {
        // Pour l'instant, juste un log - développeras plus tard
        print("Map tapped at: \(location)")
        
        // Future fonctionnalité: convertir CGPoint en coordonnées géographiques
        // et placer une annotation pickup/destination selon l'état actuel
    }
    
    func centerOnUserLocation() {
        Task { @MainActor in
            do {
                if let userLocation = locationService.currentLocation {
                    // Utiliser la position actuelle
                    mapRegion = MKCoordinateRegion(
                        center: userLocation,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                } else {
                    // Demander la position actuelle sur un thread background
                    let userLocation = try await Task.detached {
                        try await self.locationService.getCurrentLocationOnce()
                    }.value
                    
                    mapRegion = MKCoordinateRegion(
                        center: userLocation,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                }
            } catch let error as LocationError {
                // Gérer les erreurs de localisation
                userFriendlyErrorMessage = error.localizedDescription(language: currentLanguage)
                showError = true
                
                // Revenir à la région d'Ottawa par défaut
                mapRegion = RideSearchConfig.ottawaRegion
            } catch {
                // Erreur inconnue
                userFriendlyErrorMessage = translations["locationError"] ?? "Location error"
                showError = true
                mapRegion = RideSearchConfig.ottawaRegion
            }
        }
    }
    
    // MARK: - Méthodes de gestion des locations
    func setPickupLocation(_ coordinate: CLLocationCoordinate2D) {
        // Validation sécurisée des coordonnées
        guard isValidCoordinate(coordinate) else { return }
        
        pickupCoordinate = coordinate
        updateMapAnnotations()
        clearErrors()
    }
    
    func setDestinationLocation(_ coordinate: CLLocationCoordinate2D) {
        // Validation sécurisée des coordonnées
        guard isValidCoordinate(coordinate) else { return }
        
        destinationCoordinate = coordinate
        updateMapAnnotations()
        clearErrors()
        calculateEstimate()
    }
    
    private func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // Validation des limites raisonnables (région Ottawa élargie)
        let validLatRange = 44.0...47.0
        let validLonRange = -77.0...(-74.0)
        
        return validLatRange.contains(coordinate.latitude) &&
               validLonRange.contains(coordinate.longitude)
    }
    
    private func updateMapAnnotations() {
        annotations.removeAll()
        
        if let pickup = pickupCoordinate {
            annotations.append(LocationAnnotation(coordinate: pickup, type: .pickup))
        }
        
        if let destination = destinationCoordinate {
            annotations.append(LocationAnnotation(coordinate: destination, type: .destination))
        }
        
        // Ajuster la région de la carte pour montrer les deux points
        if let pickup = pickupCoordinate, let destination = destinationCoordinate {
            let minLat = min(pickup.latitude, destination.latitude)
            let maxLat = max(pickup.latitude, destination.latitude)
            let minLon = min(pickup.longitude, destination.longitude)
            let maxLon = max(pickup.longitude, destination.longitude)
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            
            let span = MKCoordinateSpan(
                latitudeDelta: max(0.05, (maxLat - minLat) * 1.3),
                longitudeDelta: max(0.05, (maxLon - minLon) * 1.3)
            )
            
            mapRegion = MKCoordinateRegion(center: center, span: span)
        }
    }
    
    // MARK: - Recherche de conducteurs
    func searchDrivers() async {
        guard validateForm() else { return }
        
        isSearching = true
        defer { isSearching = false }
        
        do {
            try await performRideSearch()
            showDriverResults = true
        } catch let error as RideSearchError {
            userFriendlyErrorMessage = error.localizedDescription
            showError = true
        } catch {
            userFriendlyErrorMessage = translations["searchError"] ?? "Search failed"
            showError = true
        }
    }
    
    func selectDriver(_ driver: Driver) {
        // TODO: Navigation vers confirmation de réservation
        print("Driver selected: \(driver.id)")
    }
    
    private func validateForm() -> Bool {
        clearErrors()
        var isValid = true
        
        if pickupAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pickupError = translations["pickupRequired"] ?? "Required"
            isValid = false
        }
        
        if destinationAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            destinationError = translations["destinationRequired"] ?? "Required"
            isValid = false
        }
        
        return isValid
    }
    
    private func performRideSearch() async throws {
        guard let pickup = pickupCoordinate,
              let destination = destinationCoordinate else {
            throw RideSearchError.invalidLocation
        }
        
        // Validation finale avant envoi au backend
        guard isValidCoordinate(pickup) && isValidCoordinate(destination) else {
            throw RideSearchError.invalidLocation
        }
        
        // TODO: Implémenter appel API réel sécurisé
        // Les données seront sanitizées et validées côté backend
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Mock data pour test
        availableDrivers = [
            Driver(id: "1", name: "Jean Dupont", rating: 4.8, eta: "3 min", price: "$12.50"),
            Driver(id: "2", name: "Marie Tremblay", rating: 4.9, eta: "5 min", price: "$11.75")
        ]
    }
    
    // MARK: - Calculs et estimations
    private func calculateEstimate() {
        guard let pickup = pickupCoordinate,
              let destination = destinationCoordinate else {
            showEstimate = false
            return
        }
        
        let distance = CLLocation(latitude: pickup.latitude, longitude: pickup.longitude)
            .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
        
        let km = distance / 1000
        estimatedDistance = String(format: "%.1f km", km)
        
        let basePrice = 5.0
        let pricePerKm = serviceType == "premium" ? 2.5 : serviceType == "standard" ? 2.0 : 1.5
        let total = basePrice + (km * pricePerKm)
        
        estimatedFare = String(format: "$%.2f", total)
        showEstimate = true
    }
    
    // MARK: - Utilitaires
    private func clearErrors() {
        pickupError = ""
        destinationError = ""
        userFriendlyErrorMessage = ""
    }
}

// MARK: - Modèle Driver
struct Driver: Identifiable {
    let id: String
    let name: String
    let rating: Double
    let eta: String
    let price: String
}

// MARK: - Vue des résultats conducteurs
struct DriverResultsView: View {
    let drivers: [Driver]
    let onDriverSelected: (Driver) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List(drivers) { driver in
                DriverRowView(driver: driver) {
                    onDriverSelected(driver)
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .navigationTitle("Available Drivers")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - Vue ligne conducteur
struct DriverRowView: View {
    let driver: Driver
    let onSelect: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(driver.name)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text("★")
                        .foregroundColor(.orange)
                    Text("\(driver.rating, specifier: "%.1f")")
                        .font(.caption)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(driver.eta)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(driver.price)
                    .font(.headline)
                    .foregroundColor(.red)
                
                Button("Select") {
                    onSelect()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview Provider
struct RideSearchView_Previews: PreviewProvider {
    static var previews: some View {
        RideSearchView()
    }
}
