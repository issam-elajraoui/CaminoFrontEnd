import SwiftUI
import Foundation
import MapKit
import Combine
import CoreLocation

// MARK: - ViewModel de recherche de course avec pickup GPS automatique
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
    @Published var activeField: ActiveLocationField = .destination //  Destination par défaut
    @Published var showSuggestions = false
    @Published var isLoadingSuggestions = false
    @Published var suggestionError: String? = nil
    
    // MARK: -  NOUVEAU - Gestion pickup GPS automatique
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
    
    // MARK: -  Computed Properties modifiées
    var canSearch: Bool {
        let hasValidPickup = isPickupFromGPS ?
            (pickupCoordinate != nil) :
            (!customPickupAddress.isEmpty && pickupCoordinate != nil)
        
        return hasValidPickup &&
               !destinationAddress.isEmpty &&
               destinationCoordinate != nil
    }
    
    //  Propriété calculée pour affichage pickup
    var displayPickupAddress: String {
        return useCustomPickup ? customPickupAddress : gpsPickupAddress
    }
    
    // MARK: - Injection du service
    func setLocationService(_ service: LocationService) {
        self.locationService = service
        setupLocationObservers()
    }
    
    private func setupLocationObservers() {
        guard let locationService = locationService else { return }
        
        //  Observer la position GPS pour pickup automatique
        locationService.$currentLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.handleGPSLocationUpdate(location)
            }
            .store(in: &cancellables)
    }
    
    // MARK: -  NOUVEAU - Gestion pickup GPS automatique
    private func handleGPSLocationUpdate(_ location: CLLocationCoordinate2D?) {
        showUserLocation = (location != nil)
        
        guard let location = location,
              isValidCoordinate(location) else {
            handleGPSUnavailable()
            return
        }
        
        // Si mode GPS actif, mettre à jour pickup automatiquement
        if !useCustomPickup {
            updateGPSPickup(location)
        }
    }
    
    private func updateGPSPickup(_ coordinate: CLLocationCoordinate2D) {
        pickupCoordinate = coordinate
        isPickupFromGPS = true
        
        // Géocodage inverse pour affichage
        Task {
            do {
                let address = try await locationService?.reverseGeocode(coordinate) ?? ""
                await MainActor.run {
                    gpsPickupAddress = address.isEmpty ?
                        translations["currentLocation"] ?? "Current Location" :
                        address
                    pickupAddress = gpsPickupAddress
                }
            } catch {
                await MainActor.run {
                    gpsPickupAddress = translations["currentLocation"] ?? "Current Location"
                    pickupAddress = gpsPickupAddress
                }
            }
        }
        
        updateMapAnnotations()
        
        // Si on a déjà une destination, calculer la route
        if destinationCoordinate != nil {
            Task { await calculateRoute() }
        }
    }
    
    private func handleGPSUnavailable() {
        // Fallback Ottawa si GPS indisponible
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
            // Passer en mode pickup custom
            isPickupFromGPS = false
            pickupAddress = customPickupAddress
            
            // Si le champ custom est vide, nettoyer pickup
            if customPickupAddress.isEmpty {
                pickupCoordinate = nil
                updateMapAnnotations()
            }
        } else {
            // Retour au mode GPS
            isPickupFromGPS = true
            pickupAddress = gpsPickupAddress
            
            // Restaurer coordonnée GPS si disponible
            if let locationService = locationService,
               let gpsLocation = locationService.currentLocation {
                updateGPSPickup(gpsLocation)
            } else {
                handleGPSUnavailable()
            }
        }
        
        clearErrors()
    }
    
    // MARK: -  Méthode pour activer pickup custom (tap long)
    func enableCustomPickup() {
        useCustomPickup = true
        customPickupAddress = gpsPickupAddress // Pré-remplir avec adresse GPS
        activeField = .pickup
    }
    
    func disableCustomPickup() {
        useCustomPickup = false
        customPickupAddress = ""
        activeField = .destination
    }
    
    func onViewAppear() {
        checkLocationPermissions()
        
        //  Focus automatique sur destination au démarrage
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
    
    // MARK: -  Gestion centralisée des suggestions modifiée
    func onLocationTextChanged(_ newText: String, for field: ActiveLocationField) {
        //  Gérer les changements selon le type de champ
        switch field {
        case .pickup:
            if useCustomPickup {
                customPickupAddress = newText
                pickupAddress = newText
                performSuggestionSearch(newText, for: field)
            }
            // Si GPS mode, ignorer les changements de texte
            
        case .destination:
            destinationAddress = newText
            performSuggestionSearch(newText, for: field)
            
        case .none:
            break
        }
    }
    
    private func performSuggestionSearch(_ newText: String, for field: ActiveLocationField) {
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
    
    // MARK: - Recherche d'adresses (inchangée)
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
    
    // MARK: -  Application de la sélection de suggestion modifiée
    private func applySuggestionSelection(_ suggestion: AddressSuggestion) {
        switch activeField {
        case .pickup:
            if useCustomPickup {
                customPickupAddress = suggestion.displayText
                pickupAddress = suggestion.displayText
                setPickupLocation(suggestion.coordinate)
                isPickupFromGPS = false
            }
            // Si GPS mode, ignorer la sélection
            
        case .destination:
            destinationAddress = suggestion.displayText
            setDestinationLocation(suggestion.coordinate)
            
        case .none:
            break
        }
        
        // Fermer les suggestions
        showSuggestions = false
        suggestions = []
        activeField = .destination //  Retour focus destination après sélection pickup
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
    
    // MARK: -  Traductions complètes avec nouveaux termes
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
                "enableGps": "Activer",
                //  Nouveaux termes
                "currentLocation": "Position actuelle",
                "fallbackLocation": "Ottawa, ON",
                "tapToCustomize": "Appui long pour modifier",
                "usingGpsLocation": "Position GPS utilisée",
                "customPickupEnabled": "Départ personnalisé activé"
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
                "enableGps": "Enable",
                //  Nouveaux termes
                "currentLocation": "Current Location",
                "fallbackLocation": "Ottawa, ON",
                "tapToCustomize": "Long press to customize",
                "usingGpsLocation": "Using GPS location",
                "customPickupEnabled": "Custom pickup enabled"
            ]
        }
    }
    
    // MARK: - Méthodes d'interaction avec la carte
    func handleMapTap(at location: CGPoint) {
        // Fermer les suggestions lors du tap sur la carte
        activeField = .destination //  Retour destination par défaut
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
    
    // MARK: - Recherche de conducteurs
    func searchDrivers() async {
        // Fermer les suggestions lors de la recherche
        activeField = .destination //  Reset focus destination
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
    
    // MARK: -  Validation formulaire modifiée
    private func validateForm() -> Bool {
        clearErrors()
        var isValid = true
        
        // Validation pickup selon le mode
        if useCustomPickup {
            if customPickupAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pickupError = translations["pickupRequired"] ?? "Required"
                isValid = false
            }
        } else {
            // Mode GPS - vérifier que la coordonnée existe
            if pickupCoordinate == nil {
                pickupError = translations["locationError"] ?? "GPS location required"
                isValid = false
            }
        }
        
        // Validation destination (inchangée)
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
    
    // MARK: - Calculs et estimations (inchangées)
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
        
        // Calcul du prix basé sur la distance réelle
        let km = route.distance / 1000
        let basePrice = 5.0
        let pricePerKm = serviceType == "premium" ? 2.5 : serviceType == "standard" ? 2.0 : 1.5
        let total = basePrice + (km * pricePerKm)
        
        estimatedFare = String(format: "$%.2f", total)
        showEstimate = true
    }
}
