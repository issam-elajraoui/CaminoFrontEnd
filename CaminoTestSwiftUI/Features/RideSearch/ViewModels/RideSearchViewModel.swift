import SwiftUI
import Foundation
import MapKit
import Combine
import CoreLocation

// MARK: - ViewModel de recherche avec mode pinpoint
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

    // MARK: - NOUVEAU - Mode Pinpoint
    @Published var isPinpointMode: Bool = false
    @Published var activeFieldForPinpoint: ActiveLocationField = .destination
    @Published var mapCenterCoordinate: CLLocationCoordinate2D?
    @Published var isResolvingAddress: Bool = false
    @Published var pinpointAddress: String = ""
    
    // Mode de sélection d'adresse
//    enum LocationSelectionMode {
//        case search    // Mode recherche textuelle
//        case pinpoint  // Mode pinpoint visuel
//    }
//    @Published var selectionMode: LocationSelectionMode = .search

    // MARK: - Published Properties - Suggestions centralisées (existant)
    @Published var suggestions: [AddressSuggestion] = []
    @Published var activeField: ActiveLocationField = .destination
    @Published var showSuggestions = false
    @Published var isLoadingSuggestions = false
    @Published var suggestionError: String? = nil

    // MARK: - Gestion pickup GPS automatique (existant)
    @Published var useCustomPickup: Bool = false {
        didSet {
            handlePickupModeChange()
        }
    }
    @Published var isPickupFromGPS: Bool = true
    @Published var gpsPickupAddress: String = ""
    @Published var customPickupAddress: String = ""

    // MARK: - Propriétés pour l'itinéraire
    @Published var currentRoute: RouteResult?
    @Published var isCalculatingRoute = false

    // MARK: - Services et données privées
    private var locationService: LocationService?
    private var pickupCoordinate: CLLocationCoordinate2D?
    private var destinationCoordinate: CLLocationCoordinate2D?
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
//    private var resolveTask: Task<Void, Never>? // Pour le géocodage inverse pinpoint
    
    // Debug
    private var gpsReverseTask: Task<Void, Never>?
    
    private lazy var searchCompleter: MKLocalSearchCompleter = {
        let completer = MKLocalSearchCompleter()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        
        if let locationService = locationService,
           let userLocation = locationService.currentLocation {
            let region = MKCoordinateRegion(
                center: userLocation,
                latitudinalMeters: 50000,
                longitudinalMeters: 50000
            )
            completer.region = region
        }
        
        return completer
    }()
    
    override init() {
        super.init()
    }
    
    // MARK: - NOUVEAU - Méthodes mode pinpoint
    func enablePinpointMode(for field: ActiveLocationField) {
        print("🟢 ViewModel: enablePinpointMode called for field: \(field)")
//        selectionMode = .pinpoint
        isPinpointMode = true
        activeFieldForPinpoint = field
        print("🟢 ViewModel: isPinpointMode set to \(isPinpointMode)")

        
        // Fermer les suggestions du mode recherche
        showSuggestions = false
        suggestions = []
        searchTask?.cancel()
        
        // Initialiser le centre selon le champ et les coordonnées existantes
        var initialCenter: CLLocationCoordinate2D?
        
        switch field {
        case .destination:
            // Si destination déjà définie, utiliser ses coordonnées
            if let destCoord = destinationCoordinate {
                initialCenter = destCoord
            }
            
        case .pickup:
            // Si pickup custom déjà défini, utiliser ses coordonnées
            if useCustomPickup, let pickupCoord = pickupCoordinate {
                initialCenter = pickupCoord
            }
            
        case .none:
            break
        }
        
        // Sinon utiliser position GPS ou fallback Ottawa
        if initialCenter == nil {
            if let userLocation = locationService?.currentLocation {
                initialCenter = userLocation
            } else {
                initialCenter = CLLocationCoordinate2D(latitude: 45.4215, longitude: -75.6972)
            }
        }
        
        mapCenterCoordinate = initialCenter
        
        // Démarrer la résolution d'adresse immédiatement
//        if let center = initialCenter {
////            onMapCenterChanged(coordinate: center)
//        }
    }

    func disablePinpointMode() {
//        selectionMode = .search
        isPinpointMode = false
        isResolvingAddress = false
        pinpointAddress = ""
        
        // Annuler les tâches en cours
//        resolveTask?.cancel()
        
        // Retour au focus destination par défaut
        activeField = .destination
    }

    private var isUpdatingFromMap: Bool = false


    // Méthode d'auto-update du champ destination
    private func autoUpdateDestinationField(_ address: String) async {
        guard !isUpdatingFromMap else { return } // Éviter boucles
        
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            
            switch self.activeFieldForPinpoint {
            case .destination:
                // Vérifier si address vraiment différente
                if self.destinationAddress != address {
                    self.destinationAddress = address
                    
                    // Déclencher route calculation avec debounce
                    if self.pickupCoordinate != nil {
                        self.scheduleRouteCalculation()
                    }
                }
                
            case .pickup:
                if self.useCustomPickup {
                    if self.customPickupAddress != address {
                        self.customPickupAddress = address
                        self.pickupAddress = address
                        self.isPickupFromGPS = false
                        
                        // Déclencher route calculation avec debounce
                        if self.destinationCoordinate != nil {
                            self.scheduleRouteCalculation()
                        }
                    }
                }
                
            case .none:
                break
            }
        }
    }
    
    private func updatePinpointAddress(_ address: String) async {
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            
            self.pinpointAddress = address
            self.isResolvingAddress = false
        }
    }
    
    
    private var routeCalculationTask: Task<Void, Never>?

    private func scheduleRouteCalculation() {
        routeCalculationTask?.cancel()
        
        routeCalculationTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(1000)) // 1 seconde de debounce
                guard !Task.isCancelled else { return }
                await self?.calculateRoute()
            } catch {
                // Task annulé
            }
        }
    }
    
    // MARK: - Computed Properties modifiées
    var canSearch: Bool {
        let hasValidPickup = isPickupFromGPS ?
            (pickupCoordinate != nil) :
            (!customPickupAddress.isEmpty && pickupCoordinate != nil)
        
        return hasValidPickup &&
               !destinationAddress.isEmpty &&
               destinationCoordinate != nil
    }
    
    var displayPickupAddress: String {
        return useCustomPickup ? customPickupAddress : gpsPickupAddress
    }
    
    // MARK: - Injection du service (existant)
    func setLocationService(_ service: LocationService) {
        self.locationService = service
        setupLocationObservers()
    }
    
    private func setupLocationObservers() {
        guard let locationService = locationService else { return }
        
        locationService.$currentLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.handleGPSLocationUpdate(location)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Gestion pickup GPS automatique (existant - inchangé)
    private func handleGPSLocationUpdate(_ location: CLLocationCoordinate2D?) {
        print("🌐 LocationService.handleGPSLocationUpdate called with: \(String(describing: location))")
        guard !isUpdatingFromMap else { return } // Éviter conflicts avec pinpoint
        
        showUserLocation = (location != nil)
        
        guard let location = location,
              isValidCoordinate(location) else {
            handleGPSUnavailable()
            return
        }
        
        if !useCustomPickup {
            print("🎯 LocationService will call updateGPSPickup...")
            updateGPSPickup(location)
        }
    }
    
    
    private func updateGPSPickup(_ coordinate: CLLocationCoordinate2D) {
        print("📍 LocationService.updateGPSPickup called for: \(coordinate)")
        pickupCoordinate = coordinate
        isPickupFromGPS = true
        
        Task {
            do {
                print("🔄 LocationService calling GeocodeManager...")
                
                // Utiliser le GeocodeManager global
                let address = try await GeocodeManager.shared.reverseGeocode(coordinate)
                
                await MainActor.run {
                    gpsPickupAddress = address.isEmpty ?
                        "Position actuelle" :
                        address
                    pickupAddress = gpsPickupAddress
                    print("✅ LocationService got address: '\(gpsPickupAddress)'")
                }
            } catch {
                print("❌ LocationService geocoding failed: \(error)")
                await MainActor.run {
                    gpsPickupAddress = "Position actuelle"
                    pickupAddress = gpsPickupAddress
                }
            }
        }
        
        updateMapAnnotations()
        
        if destinationCoordinate != nil {
            Task { await calculateRoute() }
        }
    }
    
    private func handleGPSUnavailable() {
        let ottawaCoordinate = CLLocationCoordinate2D(latitude: 45.4215, longitude: -75.6972)
        
        if !useCustomPickup {
            pickupCoordinate = ottawaCoordinate
            isPickupFromGPS = false
            gpsPickupAddress = translations["fallbackLocation"] ?? "Ottawa, ON"
            pickupAddress = gpsPickupAddress
            updateMapAnnotations()
        }
    }
    
    private func handlePickupModeChange() {
        if useCustomPickup {
            isPickupFromGPS = false
            pickupAddress = customPickupAddress
            
            if customPickupAddress.isEmpty {
                pickupCoordinate = nil
                updateMapAnnotations()
            }
        } else {
            isPickupFromGPS = true
            pickupAddress = gpsPickupAddress
            
            if let locationService = locationService,
               let gpsLocation = locationService.currentLocation {
                updateGPSPickup(gpsLocation)
            } else {
                handleGPSUnavailable()
            }
        }
        
        clearErrors()
    }
    
    func enableCustomPickup() {
        useCustomPickup = true
        customPickupAddress = gpsPickupAddress
        activeField = .pickup
    }
    
    func disableCustomPickup() {
        useCustomPickup = false
        customPickupAddress = ""
        activeField = .destination
    }
    
    // MARK: - Méthodes existantes (inchangées)
    func onViewAppear() {
        checkLocationPermissions()
        
        if activeField == .none {
            activeField = .destination
        }
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
            locationService.startLocationUpdates()
            if locationService.currentLocation != nil {
                showUserLocation = true
                centerOnUserLocationWithService()
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
    
    func handleAutocompleteError(_ error: Error) async {
        let locationError = LocationError.geocodingFailed
        await handleSearchError(locationError, for: activeField)
    }
    
    private func handleSearchError(_ error: LocationError, for field: ActiveLocationField) async {
        await MainActor.run { [weak self] in
            guard let self = self, self.activeField == field else { return }
            
            self.isLoadingSuggestions = false
            self.suggestions = []
            self.showSuggestions = false
            self.suggestionError = error.localizedDescription(language: currentLanguage)
            
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
    
    // MARK: - Gestion centralisée des suggestions (existant - inchangé)
    func onLocationTextChanged(_ newText: String, for field: ActiveLocationField) {
        switch field {
        case .pickup:
            if useCustomPickup {
                customPickupAddress = newText
                pickupAddress = newText
                performSuggestionSearch(newText, for: field)
            }
            
        case .destination:
            destinationAddress = newText
            performSuggestionSearch(newText, for: field)
            
        case .none:
            break
        }
    }
    
    private func performSuggestionSearch(_ newText: String, for field: ActiveLocationField) {
        searchTask?.cancel()
        
        suggestions = []
        showSuggestions = false
        suggestionError = nil
        
        let sanitizedQuery = sanitizeQuery(newText)
        guard sanitizedQuery.count >= 3 else {
            isLoadingSuggestions = false
            return
        }
        
        guard let locationService = locationService, locationService.isLocationAvailable else {
            suggestionError = currentLanguage == "fr" ?
                "Services de localisation indisponibles" :
                "Location services unavailable"
            return
        }
        
        isLoadingSuggestions = true
        
        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                await self?.performAddressSearch(query: sanitizedQuery, for: field)
            } catch {
                // Task annulé ou erreur de sleep
            }
        }
    }
    
    private func performAddressSearch(query: String, for field: ActiveLocationField) async {
        guard let locationService = locationService else { return }
        
        if let userLocation = locationService.currentLocation {
            let region = MKCoordinateRegion(
                center: userLocation,
                latitudinalMeters: 50000,
                longitudinalMeters: 50000
            )
            searchCompleter.region = region
        }
        
        searchCompleter.queryFragment = query
    }
    
    func selectSuggestion(_ suggestion: AddressSuggestion) {
        if let completion = suggestion.completion {
            Task {
                await resolveCompletionCoordinates(completion, suggestion: suggestion)
            }
        } else {
            applySuggestionSelection(suggestion)
        }
    }
    
    private func resolveCompletionCoordinates(_ completion: MKLocalSearchCompletion, suggestion: AddressSuggestion) async {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let localSearch = MKLocalSearch(request: searchRequest)
        
        do {
            let response = try await localSearch.start()
            
            if let mapItem = response.mapItems.first {
                let coordinate = mapItem.placemark.coordinate
                
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
    
    private func applySuggestionSelection(_ suggestion: AddressSuggestion) {
        switch activeField {
        case .pickup:
            if useCustomPickup {
                customPickupAddress = suggestion.displayText
                pickupAddress = suggestion.displayText
                setPickupLocation(suggestion.coordinate)
                isPickupFromGPS = false
            }
            
        case .destination:
            destinationAddress = suggestion.displayText
            setDestinationLocation(suggestion.coordinate)
            
        case .none:
            break
        }
        
        showSuggestions = false
        suggestions = []
        activeField = .destination
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
    
    // MARK: - Traductions complètes avec nouveaux termes pinpoint
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
                "invalidLocation": "Position invalide",
                "permissionDenied": "Permission de localisation refusée",
                "locationDisabled": "Services de localisation désactivés",
                "gpsEnabled": "GPS",
                "gpsDisabled": "Pas de GPS",
                "enableGpsMessage": "Activez le GPS pour de meilleurs services de localisation",
                "enableGps": "Activer",
                "currentLocation": "Position actuelle",
                "fallbackLocation": "Ottawa, ON",
                "tapToCustomize": "Appui long pour modifier",
                "usingGpsLocation": "Position GPS utilisée",
                "customPickupEnabled": "Départ personnalisé activé",
                "searchMode": "Recherche",
                "pinpointMode": "Sur la carte",
                "selectOnMap": "Choisir sur la carte",
                "confirmLocation": "Confirmer la position",
                "resolvingAddress": "Recherche de l'adresse...",
                "dragMapToChoose": "Déplacez la carte pour choisir"
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
                "invalidLocation": "Invalid location",
                "permissionDenied": "Location permission denied",
                "locationDisabled": "Location services disabled",
                "gpsEnabled": "GPS",
                "gpsDisabled": "No GPS",
                "enableGpsMessage": "Enable GPS for better location services",
                "enableGps": "Enable",
                "currentLocation": "Current Location",
                "fallbackLocation": "Ottawa, ON",
                "tapToCustomize": "Long press to customize",
                "usingGpsLocation": "Using GPS location",
                "customPickupEnabled": "Custom pickup enabled",
                "searchMode": "Search",
                "pinpointMode": "On map",
                "selectOnMap": "Select on map",
                "confirmLocation": "Confirm location",
                "resolvingAddress": "Finding address...",
                "dragMapToChoose": "Drag map to choose"
            ]
        }
    }
    
    // MARK: - Méthodes d'interaction avec la carte (existant)
    func handleMapTap(at location: CGPoint) {
        activeField = .destination
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
    
    // MARK: - Méthodes de gestion des locations (existant)
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
        Task {
            await calculateRoute()
        }
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
    
    // MARK: - Recherche de conducteurs (existant)
    func searchDrivers() async {
        activeField = .destination
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
        
        if useCustomPickup {
            if customPickupAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pickupError = translations["pickupRequired"] ?? "Required"
                isValid = false
            }
        } else {
            if pickupCoordinate == nil {
                pickupError = translations["locationError"] ?? "GPS location required"
                isValid = false
            }
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
        
        availableDrivers = [
            Driver(id: "1", name: "Jean Dupont", rating: 4.8, eta: "3 min", price: "$12.50"),
            Driver(id: "2", name: "Marie Tremblay", rating: 4.9, eta: "5 min", price: "$11.75")
        ]
    }
    
    // MARK: - Calculs et estimations (existant)
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
    
    // MARK: - Calcul d'itinéraire
    private func calculateRoute() async {
        guard let pickup = pickupCoordinate,
              let destination = destinationCoordinate else { return }
        
        isCalculatingRoute = true
        defer { isCalculatingRoute = false }
        
        do {
            let route = try await RouteService.calculateRoute(
                from: pickup,
                to: destination,
                transportType: .automobile
            )
            
            await MainActor.run {
                currentRoute = route
                updateEstimateFromRoute(route)
            }
            
        } catch {
            print("Route calculation error: \(error.localizedDescription)")
            currentRoute = nil
        }
    }
    
    private func updateEstimateFromRoute(_ route: RouteResult) {
        estimatedDistance = route.distanceFormatted
        
        let km = route.distance / 1000
        let basePrice = 5.0
        let pricePerKm = serviceType == "premium" ? 2.5 : serviceType == "standard" ? 2.0 : 1.5
        let total = basePrice + (km * pricePerKm)
        
        estimatedFare = String(format: "$%.2f", total)
        showEstimate = true
    }
    // MARK: - Ajouts au RideSearchViewModel pour pinpoint simple
    // Ajouter ces propriétés et méthodes à RideSearchViewModel.swift

    // MARK: - Nouvelles propriétés pour pinpoint simple
    private var pinpointTask: Task<Void, Never>?

    
    
    
    
    
    
    // MARK: - Méthode simplifiée pour le changement de centre de carte
    func onMapCenterChangedSimple(coordinate: CLLocationCoordinate2D) {
        guard isPinpointMode else { return }
        
        print("🗺️ Pinpoint center changed: \(coordinate)")
        
        // Mettre à jour la coordonnée destination
        destinationCoordinate = coordinate
        updateMapAnnotations()
        
        // Annuler la tâche précédente
        pinpointTask?.cancel()
        
        // Valider la coordonnée
        guard isValidCoordinate(coordinate) else {
            pinpointAddress = "Position invalide"
            isResolvingAddress = false
            return
        }
        
        // Démarrer la résolution avec debounce RÉDUIT
        isResolvingAddress = true
        
        pinpointTask = Task { [weak self] in
            do {
                // CORRECTION - Debounce réduit à 800ms (au lieu de 1000ms)
                try await Task.sleep(for: .milliseconds(800))
                
                guard !Task.isCancelled else { return }
                
                print("🔄 Pinpoint resolving address...")
                
                // Utiliser le GeocodeManager global
                let address = try await GeocodeManager.shared.reverseGeocode(coordinate)
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.pinpointAddress = address
                    self.isResolvingAddress = false
                    
                    // Auto-update du champ destination
                    self.destinationAddress = address
                    
                    print("✅ Pinpoint address resolved: \(address)")
                }
                
            } catch {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.pinpointAddress = "Adresse introuvable"
                    self.isResolvingAddress = false
                    
                    print("❌ Pinpoint resolution failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Méthode pour nettoyer les tâches
    func cleanupPinpointTasks() {
        pinpointTask?.cancel()
        pinpointTask = nil
        GeocodeManager.shared.clearQueue()
    }
}

// MARK: - Extension MKLocalSearchCompleterDelegate (existant - inchangé)
extension RideSearchViewModel: MKLocalSearchCompleterDelegate {
    
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            let newSuggestions = completer.results.compactMap { completion -> AddressSuggestion? in
                let displayText = formatCompletionForDisplay(completion)
                
                return AddressSuggestion(
                    id: UUID().uuidString,
                    displayText: displayText,
                    fullAddress: completion.title + ", " + completion.subtitle,
                    coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    completion: completion
                )
            }
            
            suggestions = Array(newSuggestions.prefix(7))
            showSuggestions = !suggestions.isEmpty
            isLoadingSuggestions = false
        }
    }
    
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            print("MKLocalSearchCompleter error: \(error.localizedDescription)")
            await handleAutocompleteError(error)
        }
    }
    
    private func formatCompletionForDisplay(_ completion: MKLocalSearchCompletion) -> String {
        let title = completion.title
        let subtitle = completion.subtitle
        
        if subtitle.isEmpty || title.contains(subtitle) {
            return title
        }
        
        return "\(title), \(subtitle)"
    }
    
}


