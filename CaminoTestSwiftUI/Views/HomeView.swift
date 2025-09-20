import SwiftUI
import Foundation
import MapKit
import Combine

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

// MARK: - Enum pour identifier le champ actif
enum ActiveLocationField {
    case none
    case pickup
    case destination
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

// MARK: - Vue principale de recherche avec EnvironmentObject
struct RideSearchView: View {
    private static let maxSuggestions = 7
    @StateObject private var viewModel = RideSearchViewModel()
    @StateObject private var locationService = LocationService()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    // Carte MapKit (65-70% de l'écran)
                    mapSection
                        .frame(height: geometry.size.height * 0.30)
                    
                    // Formulaire de recherche (35% de l'écran)
                    searchFormSection
                        .frame(height: geometry.size.height * 0.70)
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
        .environmentObject(locationService)
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
        .sheet(isPresented: $viewModel.showLocationPermission) {
            LocationPermissionView(
                onPermissionGranted: {
                    viewModel.onLocationPermissionGranted()
                },
                onCancel: {
                    viewModel.showLocationPermission = false
                }
            )
            .environmentObject(locationService)
        }
        .onAppear {
            viewModel.setLocationService(locationService)
            viewModel.onViewAppear()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            viewModel.recheckLocationPermissions()
        }
    }
    
    // MARK: - Bouton GPS
    private var gpsLocationButton: some View {
        Button(action: {
            Task {
                await viewModel.centerOnUserLocation()
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                Image(systemName: locationService.isLocationAvailable ? "location.fill" : "location.slash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(locationService.isLocationAvailable ? .red : .gray)
            }
        }
        .disabled(!locationService.isLocationAvailable)
        .scaleEffect(locationService.isLocationAvailable ? 1.0 : 0.9)
        .animation(.easeInOut(duration: 0.2), value: locationService.isLocationAvailable)
    }
    
    // MARK: - Section Carte
    private var mapSection: some View {
        Map(position: $viewModel.mapPosition) {
            ForEach(viewModel.annotations) { annotation in
                Annotation("", coordinate: annotation.coordinate) {
                    Circle()
                        .fill(annotation.type.color)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
            }
            if viewModel.showUserLocation {
                UserAnnotation()
            }
        }
        .mapStyle(.standard)
        .mapControls {
            MapUserLocationButton()
                .hidden()
        }
        .onTapGesture(coordinateSpace: .local) { location in
            viewModel.handleMapTap(at: location)
        }
        .overlay(
            VStack {
                HStack {
                    gpsLocationButton
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
        .shadow(radius: 2)
    }
    
    // MARK: - Section formulaire de recherche compacte
    private var searchFormSection: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
            
            ScrollView {
                VStack(spacing: 12) {
                    // Titre avec indicateur GPS
                    HStack {
                        Text(viewModel.translations["findRide"] ?? "Find a Ride")
                            .font(.title3)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Message GPS si désactivé
                    if !locationService.isLocationAvailable {
                        HStack {
                            Image(systemName: "location.slash")
                                .foregroundColor(.orange)
                            Text(viewModel.translations["enableGpsMessage"] ?? "Enable GPS for better location services")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Spacer()
                            Button(viewModel.translations["enableGps"] ?? "Enable") {
                                viewModel.requestLocationPermission()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 20)
                    }
                    
                    // Container pour les champs et suggestions avec gestion du z-index
                    ZStack(alignment: .top) {
                        VStack(spacing: 8) {
                            // Champs de localisation compacts
                            CentralizedLocationField(
                                text: $viewModel.pickupAddress,
                                placeholder: viewModel.translations["pickupLocation"] ?? "Pickup Location",
                                errorMessage: viewModel.pickupError,
                                isPickup: true,
                                fieldType: .pickup,
                                activeField: $viewModel.activeField,
                                onTextChange: { newText in
                                    viewModel.onLocationTextChanged(newText, for: .pickup)
                                },
                                onLocationSelected: { location in
                                    viewModel.setPickupLocation(location)
                                }
                            )
                            
                            CentralizedLocationField(
                                text: $viewModel.destinationAddress,
                                placeholder: viewModel.translations["destination"] ?? "Destination",
                                errorMessage: viewModel.destinationError,
                                isPickup: false,
                                fieldType: .destination,
                                activeField: $viewModel.activeField,
                                onTextChange: { newText in
                                    viewModel.onLocationTextChanged(newText, for: .destination)
                                },
                                onLocationSelected: { location in
                                    viewModel.setDestinationLocation(location)
                                }
                            )
                        }
                        
                        // Suggestions centralisées avec positionnement intelligent
                        if viewModel.showSuggestions && !viewModel.suggestions.isEmpty {
                            suggestionsList
                        }
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
    
    // MARK: - Liste de suggestions centralisée
    private var suggestionsList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.suggestions.prefix(Self.maxSuggestions), id: \.id) { suggestion in
                Button(action: {
                    viewModel.selectSuggestion(suggestion)
                }) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        
                        Text(suggestion.displayText)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                
                if suggestion.id != viewModel.suggestions.prefix(Self.maxSuggestions).last?.id {
                    Divider()
                }
            }
        }
        .background(Color.white)
        .cornerRadius(6)
        .shadow(radius: 4)
        .padding(.top, viewModel.activeField == .pickup ? 44 : 96)
        .padding(.leading, 18)
        .zIndex(1000)
    }
}

// MARK: - Champ de localisation centralisé
struct CentralizedLocationField: View {
    @Binding var text: String
    let placeholder: String
    let errorMessage: String
    let isPickup: Bool
    let fieldType: ActiveLocationField
    @Binding var activeField: ActiveLocationField
    let onTextChange: (String) -> Void
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
                    .onChange(of: text) { _, newValue in
                        let sanitized = sanitizeLocationInput(newValue)
                        if sanitized != newValue {
                            text = sanitized
                        }
                        
                        // Mettre à jour le champ actif et déclencher la recherche
                        activeField = fieldType
                        onTextChange(sanitized)
                    }
                    .onTapGesture {
                        activeField = fieldType
                        if !text.isEmpty && text.count >= 3 {
                            onTextChange(text)
                        }
                    }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                        activeField = .none
                    }) {
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
            
            // Messages d'erreur
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

// MARK: - ViewModel de recherche de course amélioré avec gestion centralisée
@MainActor
class RideSearchViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties - Interface
    @Published var mapPosition = MapCameraPosition.region(RideSearchConfig.ottawaRegion)
    @Published var annotations: [LocationAnnotation] = []
    @Published var showUserLocation = false
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
    
    // MARK: - Published Properties - Suggestions centralisées
    @Published var suggestions: [AddressSuggestion] = []
    @Published var activeField: ActiveLocationField = .none
    @Published var showSuggestions = false
    @Published var isLoadingSuggestions = false
    @Published var suggestionError: String? = nil
    
    // MARK: - Services et données privées
    private var locationService: LocationService?
    private var pickupCoordinate: CLLocationCoordinate2D?
    private var destinationCoordinate: CLLocationCoordinate2D?
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
    private lazy var searchCompleter: MKLocalSearchCompleter = {
           let completer = MKLocalSearchCompleter()
           completer.delegate = self
           completer.resultTypes = [.address, .pointOfInterest]
        
    // Configurer la région de recherche si position GPS disponible
    if let locationService = locationService,
                   let userLocation = locationService.currentLocation {
                    let region = MKCoordinateRegion(
                        center: userLocation,
                        latitudinalMeters: 50000, // 50km de rayon
                        longitudinalMeters: 50000
                    )
                    completer.region = region
                }
                
                return completer
            }()
    
    
    override init() {
           super.init()
       }
    
    // MARK: - Computed Properties
    var canSearch: Bool {
        !pickupAddress.isEmpty && !destinationAddress.isEmpty &&
        pickupCoordinate != nil && destinationCoordinate != nil
    }
    
    // MARK: - Injection du service
    func setLocationService(_ service: LocationService) {
        self.locationService = service
        setupLocationObservers()
    }
    
    private func setupLocationObservers() {
        guard let locationService = locationService else { return }
        
        locationService.$currentLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.showUserLocation = (location != nil)
            }
            .store(in: &cancellables)
    }
    
    func onViewAppear() {
        checkLocationPermissions()
    }
    
    func recheckLocationPermissions() {
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            checkLocationPermissions()
        }
    }
    
    private func checkLocationPermissions() {
        guard let locationService = locationService else { return }
        
        let status = locationService.authorizationStatus
        
        switch status {
        case .notDetermined:
            locationService.requestLocationPermission()
            
        case .denied, .restricted:
            showLocationPermission = true
            
        case .authorizedWhenInUse, .authorizedAlways:
            if CLLocationManager.locationServicesEnabled() {
                locationService.startLocationUpdates()
                if locationService.currentLocation != nil {
                    showUserLocation = true
                    centerOnUserLocationWithService()
                }
            } else {
                showLocationPermission = true
            }
            
        @unknown default:
            locationService.requestLocationPermission()
        }
    }
    
    func requestLocationPermission() {
        locationService?.requestLocationPermission()
    }
    
    func onLocationPermissionGranted() {
        showLocationPermission = false
        showUserLocation = true
        centerOnUserLocationWithService()
    }
    
    private func centerOnUserLocationWithService() {
        guard let locationService = locationService,
              let userLocation = locationService.currentLocation else { return }
        
        mapPosition = .region(MKCoordinateRegion(
            center: userLocation,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }
    
    // MARK: - Gestion centralisée des suggestions
    func onLocationTextChanged(_ newText: String, for field: ActiveLocationField) {
        // Annuler la recherche précédente
        searchTask?.cancel()
        
        // Nettoyer les résultats précédents
        suggestions = []
        showSuggestions = false
        suggestionError = nil
        
        // Validation de base
        let sanitizedQuery = sanitizeQuery(newText)
        guard sanitizedQuery.count >= 3 else {
            isLoadingSuggestions = false
            return
        }
        
        // Vérifier si les services de localisation sont disponibles
        guard let locationService = locationService, locationService.isLocationAvailable else {
            suggestionError = currentLanguage == "fr" ?
                "Services de localisation indisponibles" :
                "Location services unavailable"
            return
        }
        
        isLoadingSuggestions = true
        
        // Nouvelle recherche avec debounce
        searchTask = Task { [weak self] in
            do {
                // Attendre le délai de debounce
                try await Task.sleep(for: .milliseconds(500))
                
                // Vérifier si la tâche n'a pas été annulée
                guard !Task.isCancelled else { return }
                
                await self?.performAddressSearch(query: sanitizedQuery, for: field)
            } catch {
                // Task annulé ou erreur de sleep
            }
        }
    }
    
    // MARK: - Nouvelle fonction de recherche avec MKLocalSearchCompleter
    private func performAddressSearch(query: String, for field: ActiveLocationField) async {
        guard let locationService = locationService else { return }
        
        // Mettre à jour la région de recherche avec la position actuelle
        if let userLocation = locationService.currentLocation {
            let region = MKCoordinateRegion(
                center: userLocation,
                latitudinalMeters: 50000, // 50km de rayon
                longitudinalMeters: 50000
            )
            searchCompleter.region = region
        }
        
        // Démarrer la recherche avec MKLocalSearchCompleter
        searchCompleter.queryFragment = query
        
        // Le délégué `completerDidUpdateResults` sera appelé automatiquement
    }
    


    private func handleSearchError(_ error: LocationError, for field: ActiveLocationField) async {
        await MainActor.run { [weak self] in
            guard let self = self, self.activeField == field else { return }
            
            self.isLoadingSuggestions = false
            self.suggestions = []
            self.showSuggestions = false
            self.suggestionError = error.localizedDescription(language: currentLanguage)
            
            // Effacer l'erreur après 3 secondes
            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run { [weak self] in
                    if !Task.isCancelled {
                        self?.suggestionError = nil
                    }
                }
            }
        }
    }
    
    func selectSuggestion(_ suggestion: AddressSuggestion) {
        // Si on a une completion, résoudre les coordonnées
        if let completion = suggestion.completion {
            Task {
                await resolveCompletionCoordinates(completion, suggestion: suggestion)
            }
        } else {
            // Utiliser les coordonnées existantes (fallback)
            applySuggestionSelection(suggestion)
        }
    }
    
    // MARK: - Résolution des coordonnées à partir de MKLocalSearchCompletion
    private func resolveCompletionCoordinates(_ completion: MKLocalSearchCompletion, suggestion: AddressSuggestion) async {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let localSearch = MKLocalSearch(request: searchRequest)
        
        do {
            let response = try await localSearch.start()
            
            if let mapItem = response.mapItems.first {
                let coordinate = mapItem.placemark.coordinate
                
                // Créer une nouvelle suggestion avec les vraies coordonnées
                let updatedSuggestion = AddressSuggestion(
                    id: suggestion.id,
                    displayText: suggestion.displayText,
                    fullAddress: suggestion.fullAddress,
                    coordinate: coordinate,
                    completion: completion
                )
                
                await MainActor.run {
                    applySuggestionSelection(updatedSuggestion)
                }
            } else {
                await MainActor.run {
                    applySuggestionSelection(suggestion)
                }
            }
        } catch {
            print("Error resolving completion coordinates: \(error.localizedDescription)")
            await MainActor.run {
                applySuggestionSelection(suggestion)
            }
        }
    }
    
    
    // MARK: - Application de la sélection de suggestion
    private func applySuggestionSelection(_ suggestion: AddressSuggestion) {
        switch activeField {
        case .pickup:
            pickupAddress = suggestion.displayText
            setPickupLocation(suggestion.coordinate)
        case .destination:
            destinationAddress = suggestion.displayText
            setDestinationLocation(suggestion.coordinate)
        case .none:
            break
        }
        
        // Fermer les suggestions
        showSuggestions = false
        suggestions = []
        activeField = .none
        searchTask?.cancel()
    }
    
    
    private func sanitizeQuery(_ query: String) -> String {
        let maxLength = 200
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: ",-./()#'\""))
        
        let filtered = query.unicodeScalars
            .filter { allowedCharacters.contains($0) }
            .map(String.init)
            .joined()
        
        return String(filtered.prefix(maxLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
                "locationDisabled": "Services de localisation désactivés",
                "gpsEnabled": "GPS",
                "gpsDisabled": "Pas de GPS",
                "enableGpsMessage": "Activez le GPS pour de meilleurs services de localisation",
                "enableGps": "Activer"
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
                "locationDisabled": "Location services disabled",
                "gpsEnabled": "GPS",
                "gpsDisabled": "No GPS",
                "enableGpsMessage": "Enable GPS for better location services",
                "enableGps": "Enable"
            ]
        }
    }
    
    // MARK: - Méthodes d'interaction avec la carte
    func handleMapTap(at location: CGPoint) {
        // Fermer les suggestions lors du tap sur la carte
        activeField = .none
        showSuggestions = false
        searchTask?.cancel()
        print("Map tapped at: \(location)")
    }
    
    func centerOnUserLocation() async {
        guard let locationService = locationService else {
            userFriendlyErrorMessage = translations["locationDisabled"] ?? "Location services disabled"
            showError = true
            return
        }
        
        guard locationService.isLocationAvailable else {
            userFriendlyErrorMessage = translations["locationDisabled"] ?? "Location services disabled"
            showError = true
            return
        }
        
        do {
            let userLocation: CLLocationCoordinate2D
            if let currentLoc = locationService.currentLocation {
                userLocation = currentLoc
            } else {
                userLocation = try await locationService.getCurrentLocationOnce()
            }
            
            let newRegion = MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 1.0)) {
                    mapPosition = .region(newRegion)
                }
            }
        } catch let locationError as LocationError {
            await MainActor.run {
                userFriendlyErrorMessage = locationError.localizedDescription(language: currentLanguage)
                showError = true
            }
        } catch {
            await MainActor.run {
                userFriendlyErrorMessage = translations["locationError"] ?? "Location error"
                showError = true
            }
        }
    }
    
    // MARK: - Méthodes de gestion des locations
    func setPickupLocation(_ coordinate: CLLocationCoordinate2D) {
        guard isValidCoordinate(coordinate) else { return }
        pickupCoordinate = coordinate
        updateMapAnnotations()
        clearErrors()
    }
    
    func setDestinationLocation(_ coordinate: CLLocationCoordinate2D) {
        guard isValidCoordinate(coordinate) else { return }
        destinationCoordinate = coordinate
        updateMapAnnotations()
        clearErrors()
        calculateEstimate()
    }
    
    private func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let validLatRange = 43.0...48.0
        let validLonRange = -78.0...(-73.0)
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
            
            let region = MKCoordinateRegion(center: center, span: span)
            mapPosition = .region(region)
        }
    }
    
    // MARK: - Recherche de conducteurs
    func searchDrivers() async {
        // Fermer les suggestions lors de la recherche
        activeField = .none
        showSuggestions = false
        searchTask?.cancel()
        
        guard validateForm() else { return }
        
        isSearching = true
        defer { isSearching = false }
        
        do {
            try await performRideSearch()
            showDriverResults = true
        } catch let rideSearchError as RideSearchError {
            userFriendlyErrorMessage = rideSearchError.localizedDescription
            showError = true
        } catch {
            userFriendlyErrorMessage = translations["searchError"] ?? "Search failed"
            showError = true
        }
    }
    
    func selectDriver(_ driver: Driver) {
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
        
        guard isValidCoordinate(pickup) && isValidCoordinate(destination) else {
            throw RideSearchError.invalidLocation
        }
        
        try await Task.sleep(for: .seconds(2))
        
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




// MARK: - Extension du ViewModel pour MKLocalSearchCompleterDelegate
extension RideSearchViewModel: MKLocalSearchCompleterDelegate {
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            // Convertir les résultats en AddressSuggestion
            let newSuggestions = completer.results.compactMap { completion -> AddressSuggestion? in
                // Créer l'affichage formaté
                let displayText = formatCompletionForDisplay(completion)
                
                return AddressSuggestion(
                    id: UUID().uuidString,
                    displayText: displayText,
                    fullAddress: completion.title + ", " + completion.subtitle,
                    coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), // Sera résolu plus tard
                    completion: completion // Stocker la completion pour résolution ultérieure
                )
            }
            
            // Limiter à 7 résultats comme Apple Maps
            suggestions = Array(newSuggestions.prefix(7))
            showSuggestions = !suggestions.isEmpty
            isLoadingSuggestions = false
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            print("MKLocalSearchCompleter error: \(error.localizedDescription)")
            
            let locationError = LocationError.geocodingFailed
            await handleSearchError(locationError, for: activeField)
        }
    }
    
    // MARK: - Formatage des résultats de completion
    private func formatCompletionForDisplay(_ completion: MKLocalSearchCompletion) -> String {
        let title = completion.title
        let subtitle = completion.subtitle
        
        // Si le subtitle est vide ou redondant, utiliser seulement le titre
        if subtitle.isEmpty || title.contains(subtitle) {
            return title
        }
        
        // Sinon, combiner titre et sous-titre
        return "\(title), \(subtitle)"
    }
}
