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
    private static let timeoutInterval: TimeInterval = 10
    private static let maxAddressLength = 200
    private static let ottawaFallbackLocation = CLLocationCoordinate2D(latitude: 45.4215, longitude: -75.6972)
    
    // MARK: - Published Properties
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationAvailable: Bool = false
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    private var permissionContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    
    // MARK: - Initialisation
    override init() {
        super.init()
        setupLocationManager()
        checkInitialPermissions()
    }
    
    // MARK: - Configuration LocationManager
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50
        
        authorizationStatus = locationManager.authorizationStatus
        updateLocationAvailability()
    }
    
    private func checkInitialPermissions() {
        Task.detached { [weak self] in
            let servicesEnabled = CLLocationManager.locationServicesEnabled()
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                if !servicesEnabled {
                    self.isLocationAvailable = false
                }
                self.updateLocationAvailability()
            }
        }
    }
    
    // MARK: - Gestion des permissions
    func requestLocationPermission() {
        Task { @MainActor in
            switch authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
                let newStatus = await waitForPermissionResult()
                handlePermissionResult(newStatus)
                
            case .denied, .restricted:
                await openLocationSettings()
                
            case .authorizedWhenInUse, .authorizedAlways:
                startLocationUpdates()
                
            @unknown default:
                locationManager.requestWhenInUseAuthorization()
            }
        }
    }
    
    private func waitForPermissionResult() async -> CLAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            permissionContinuation = continuation
            
            Task {
                do {
                    try await Task.sleep(for: .seconds(10))
                    if permissionContinuation != nil {
                        permissionContinuation = nil
                        continuation.resume(returning: authorizationStatus)
                    }
                } catch {
                    // Task cancelled
                }
            }
        }
    }
    
    private func handlePermissionResult(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            isLocationAvailable = true
            startLocationUpdates()
        case .denied, .restricted:
            isLocationAvailable = false
            currentLocation = nil
        case .notDetermined:
            isLocationAvailable = false
        @unknown default:
            isLocationAvailable = false
        }
    }
    
    private func openLocationSettings() async {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            await UIApplication.shared.open(settingsUrl)
        }
    }
    
    // MARK: - Démarrage/Arrêt de la localisation
    func startLocationUpdates() {
        guard CLLocationManager.locationServicesEnabled() else {
            isLocationAvailable = false
            return
        }
        
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            isLocationAvailable = false
            return
        }
        
        isLocationAvailable = true
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - Géocodage sécurisé
    func geocodeAddress(_ address: String) async throws -> CLLocationCoordinate2D {
        let sanitizedAddress = sanitizeAddress(address)
        guard !sanitizedAddress.isEmpty else {
            throw LocationError.invalidAddress
        }
        
        let searchCenter = currentLocation ?? Self.ottawaFallbackLocation
        let searchRegion = CLCircularRegion(
            center: searchCenter,
            radius: Self.searchRadiusKm * 1000,
            identifier: "searchArea"
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let timeoutTask = Task {
                do {
                    try await Task.sleep(for: .seconds(Self.timeoutInterval))
                    continuation.resume(throwing: LocationError.timeout)
                } catch {
                    // Task cancelled
                }
            }
            
            geocoder.geocodeAddressString(sanitizedAddress, in: searchRegion) { placemarks, error in
                timeoutTask.cancel()
                
                if let error = error {
                    print("Geocoding error: \(error.localizedDescription)")
                    continuation.resume(throwing: LocationError.geocodingFailed)
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    continuation.resume(throwing: LocationError.geocodingFailed)
                    return
                }
                
                let coordinate = location.coordinate
                if self.isCoordinateInServiceArea(coordinate, relativeTo: searchCenter) {
                    continuation.resume(returning: coordinate)
                } else {
                    print("Warning: Address outside preferred service area but accepting result")
                    continuation.resume(returning: coordinate)
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
                    // Task cancelled
                }
            }
            
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                timeoutTask.cancel()
                
                if let error = error {
                    print("Reverse geocoding error: \(error.localizedDescription)")
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
    
    // MARK: - Obtenir position actuelle UNE SEULE FOIS (Swift 16 compatible)
    func getCurrentLocationOnce() async throws -> CLLocationCoordinate2D {
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationError.locationDisabled
        }
        
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            throw LocationError.permissionDenied
        }
        
        if let currentLocation = currentLocation {
            return currentLocation
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
            
            Task {
                do {
                    try await Task.sleep(for: .seconds(Self.timeoutInterval))
                    if locationContinuation != nil {
                        locationContinuation = nil
                        continuation.resume(throwing: LocationError.timeout)
                    }
                } catch {
                    // Task cancelled
                }
            }
        }
    }
    
    // MARK: - Méthodes utilitaires privées
    private func sanitizeAddress(_ address: String) -> String {
        let trimmed = String(address.prefix(Self.maxAddressLength))
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
    
    private func isCoordinateInServiceArea(_ coordinate: CLLocationCoordinate2D, relativeTo center: CLLocationCoordinate2D) -> Bool {
        let currentCLLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let targetCLLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        let distance = currentCLLocation.distance(from: targetCLLocation)
        return distance <= (Self.searchRadiusKm * 1000)
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
        
        let result = components.joined(separator: " ")
        return result.isEmpty ? "Address" : result
    }
    
    private func updateLocationAvailability() {
        let servicesEnabled = CLLocationManager.locationServicesEnabled()
        let hasPermission = (authorizationStatus == .authorizedWhenInUse ||
                           authorizationStatus == .authorizedAlways)
        
        isLocationAvailable = servicesEnabled && hasPermission
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let coordinate = location.coordinate
        guard isValidCoordinate(coordinate) else { return }
        
        Task { @MainActor in
            currentLocation = coordinate
            
            locationContinuation?.resume(returning: coordinate)
            locationContinuation = nil
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
        
        Task { @MainActor in
            locationContinuation?.resume(throwing: LocationError.unknown)
            locationContinuation = nil
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            authorizationStatus = status
            
            permissionContinuation?.resume(returning: status)
            permissionContinuation = nil
            
            updateLocationAvailability()
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                startLocationUpdates()
            case .denied, .restricted:
                stopLocationUpdates()
                currentLocation = nil
                isLocationAvailable = false
            case .notDetermined:
                isLocationAvailable = false
            @unknown default:
                isLocationAvailable = false
            }
        }
    }
}
