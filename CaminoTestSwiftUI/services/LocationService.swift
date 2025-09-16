import Foundation
import CoreLocation
import MapKit
import UIKit

// MARK: - Erreurs de géolocalisation
enum LocationError: Error, LocalizedError {
    case permissionDenied
    case locationDisabled
    case geocodingFailed
    case invalidAddress
    case outsideServiceArea
    case timeout
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission denied"
        case .locationDisabled:
            return "Location services disabled"
        case .geocodingFailed:
            return "Address not found"
        case .invalidAddress:
            return "Invalid address"
        case .outsideServiceArea:
            return "Address outside service area"
        case .timeout:
            return "Location request timeout"
        case .unknown:
            return "Location error"
        }
    }
    
    func localizedDescription(language: String) -> String {
        if language == "fr" {
            switch self {
            case .permissionDenied:
                return "Permission de localisation refusée"
            case .locationDisabled:
                return "Services de localisation désactivés"
            case .geocodingFailed:
                return "Adresse introuvable"
            case .invalidAddress:
                return "Adresse invalide"
            case .outsideServiceArea:
                return "Adresse hors zone de service"
            case .timeout:
                return "Délai de localisation dépassé"
            case .unknown:
                return "Erreur de localisation"
            }
        }
        return errorDescription ?? "Location error"
    }
}

// MARK: - Protocole LocationServiceProtocol
@MainActor
protocol LocationServiceProtocol: ObservableObject {
    var currentLocation: CLLocationCoordinate2D? { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    var isLocationAvailable: Bool { get }
    
    func requestLocationPermission()
    func startLocationUpdates()
    func stopLocationUpdates()
    func geocodeAddress(_ address: String) async throws -> CLLocationCoordinate2D
    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> String
}

// MARK: - Service de géolocalisation principal
@MainActor
class LocationService: NSObject, LocationServiceProtocol {
    // MARK: - Configuration
    private static let searchRadiusKm: Double = 50
    private static let searchRadiusDegrees: Double = 0.45 // ~50km
    private static let timeoutInterval: TimeInterval = 10
    private static let maxAddressLength = 200
    
    // MARK: - Published Properties
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationAvailable: Bool = false
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    
    // MARK: - Initialisation
    override init() {
        super.init()
        setupLocationManager()
    }
    
    // MARK: - Configuration LocationManager
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Mise à jour tous les 10m
        
        authorizationStatus = locationManager.authorizationStatus
        
        // Déplacer sur background thread
        Task.detached { [weak self] in
            await self?.updateLocationAvailability()
        }
    }
    
    // MARK: - Gestion des permissions
    func requestLocationPermission() {
        Task { @MainActor in
            switch authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                // Diriger vers les paramètres iOS
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    await UIApplication.shared.open(settingsUrl)
                }
            case .authorizedWhenInUse, .authorizedAlways:
                startLocationUpdates()
            @unknown default:
                break
            }
        }
    }
    // Ajoutez cette méthode dans LocationService
    func checkAuthorizationStatusAsync() async -> CLAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                continuation.resume(returning: authorizationStatus)
            }
        }
    }
    
    // MARK: - Démarrage/Arrêt de la localisation
    func startLocationUpdates() {
        guard isLocationAvailable else { return }
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - Géocodage sécurisé
    func geocodeAddress(_ address: String) async throws -> CLLocationCoordinate2D {
        // Validation et sanitisation de l'entrée
        let sanitizedAddress = sanitizeAddress(address)
        guard !sanitizedAddress.isEmpty else {
            throw LocationError.invalidAddress
        }
        
        // Vérification de la position actuelle
        guard let currentLocation = currentLocation else {
            throw LocationError.locationDisabled
        }
        
        // Région de recherche (50km autour de la position actuelle)
        let searchRegion = CLCircularRegion(
            center: currentLocation,
            radius: Self.searchRadiusKm * 1000, // Conversion en mètres
            identifier: "searchArea"
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            // Timeout pour éviter les blocages
            let timeoutTask = Task {
                do {
                    try await Task.sleep(for: .seconds(Self.timeoutInterval))
                    continuation.resume(throwing: LocationError.timeout)
                } catch {
                    // Task annulé, ne rien faire
                }
            }
            
            geocoder.geocodeAddressString(sanitizedAddress, in: searchRegion) { placemarks, error in
                timeoutTask.cancel()
                
                if error != nil {
                    continuation.resume(throwing: LocationError.geocodingFailed)
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    continuation.resume(throwing: LocationError.geocodingFailed)
                    return
                }
                
                let coordinate = location.coordinate
                
                // Validation que le résultat est dans la zone de service
                if self.isCoordinateInServiceArea(coordinate) {
                    continuation.resume(returning: coordinate)
                } else {
                    continuation.resume(throwing: LocationError.outsideServiceArea)
                }
            }
        }
    }
    
    // MARK: - Géocodage inverse sécurisé
    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> String {
        guard isValidCoordinate(coordinate) else {
            throw LocationError.invalidAddress
        }
        
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        return try await withCheckedThrowingContinuation { continuation in
            let timeoutTask = Task {
                do {
                    try await Task.sleep(for: .seconds(Self.timeoutInterval))
                    continuation.resume(throwing: LocationError.timeout)
                } catch {
                    // Task annulé, ne rien faire
                }
            }
            
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                timeoutTask.cancel()
                
                if error != nil {
                    continuation.resume(throwing: LocationError.geocodingFailed)
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    continuation.resume(throwing: LocationError.geocodingFailed)
                    return
                }
                
                let address = self.formatAddress(from: placemark)
                continuation.resume(returning: address)
            }
        }
    }
    
    // MARK: - Méthodes utilitaires privées
    
    private func sanitizeAddress(_ address: String) -> String {
        // Limitation de longueur
        let trimmed = String(address.prefix(Self.maxAddressLength))
        
        // Caractères autorisés : alphanumériques, espaces, ponctuation d'adresse
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: ",-./()#'\""))
        
        let filtered = trimmed.unicodeScalars
            .filter { allowedCharacters.contains($0) }
            .map(String.init)
            .joined()
        
        return filtered.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private nonisolated func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return CLLocationCoordinate2DIsValid(coordinate) &&
               coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
               coordinate.longitude >= -180 && coordinate.longitude <= 180
    }
    
    private func isCoordinateInServiceArea(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard let currentLocation = currentLocation else { return false }
        
        let currentCLLocation = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let targetCLLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        let distance = currentCLLocation.distance(from: targetCLLocation)
        return distance <= (Self.searchRadiusKm * 1000) // 50km en mètres
    }
    
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        if let streetNumber = placemark.subThoroughfare {
            components.append(streetNumber)
        }
        
        if let streetName = placemark.thoroughfare {
            components.append(streetName)
        }
        
        if let city = placemark.locality {
            components.append(city)
        }
        
        if let province = placemark.administrativeArea {
            components.append(province)
        }
        
        return components.joined(separator: " ")
    }
    
    private func updateLocationAvailability() {
        // Éviter l'appel bloquant sur le thread principal
        Task.detached { [weak self] in
            let servicesEnabled = CLLocationManager.locationServicesEnabled()
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.isLocationAvailable = servicesEnabled &&
                                        (self.authorizationStatus == .authorizedWhenInUse ||
                                         self.authorizationStatus == .authorizedAlways)
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Validation des coordonnées
        let coordinate = location.coordinate
        guard isValidCoordinate(coordinate) else { return }
        
        Task { @MainActor in
            currentLocation = coordinate
            
            // Résoudre la continuation si en attente
            locationContinuation?.resume(returning: coordinate)
            locationContinuation = nil
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(throwing: LocationError.unknown)
            locationContinuation = nil
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            authorizationStatus = status
            updateLocationAvailability()
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                startLocationUpdates()
            case .denied, .restricted:
                stopLocationUpdates()
                currentLocation = nil
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Extension pour obtenir position actuelle
extension LocationService {
    func getCurrentLocationOnce() async throws -> CLLocationCoordinate2D {
        guard isLocationAvailable else {
            throw LocationError.locationDisabled
        }
        
        if let currentLocation = currentLocation {
            return currentLocation
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
            
            // Timeout
            Task {
                do {
                    try await Task.sleep(for: .seconds(Self.timeoutInterval))
                    if locationContinuation != nil {
                        locationContinuation = nil
                        continuation.resume(throwing: LocationError.timeout)
                    }
                } catch {
                    // Task annulé, ne rien faire
                }
            }
        }
    }
}
