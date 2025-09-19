//
//  LocationService.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-16.
//


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

// MARK: - Actor pour opérations géolocalisation thread-safe
actor LocationOperationsActor {
    private let geocoder = CLGeocoder()
    private let timeoutInterval: TimeInterval = 10
    private let searchRadiusKm: Double = 50
    
    // MARK: - Géocodage sécurisé et non-bloquant
    func performGeocode(
        address: String,
        searchCenter: CLLocationCoordinate2D
    ) async throws -> CLLocationCoordinate2D {
        
        // Validation d'entrée
        let sanitizedAddress = sanitizeAddress(address)
        guard !sanitizedAddress.isEmpty else {
            throw LocationError.invalidAddress
        }
        
        let searchRegion = CLCircularRegion(
            center: searchCenter,
            radius: searchRadiusKm * 1000,
            identifier: "searchArea"
        )
        
        // Géocodage avec timeout robuste
        return try await withThrowingTaskGroup(of: CLLocationCoordinate2D.self) { group in
            // Tâche de géocodage
            group.addTask {
                try await self.performGeocodingOperation(
                    address: sanitizedAddress,
                    region: searchRegion
                )
            }
            
            // Tâche de timeout
            group.addTask {
                try await Task.sleep(for: .seconds(self.timeoutInterval))
                throw LocationError.timeout
            }
            
            // Retourner le premier résultat (géocodage ou timeout)
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
    
    // MARK: - Géocodage inverse sécurisé
    func performReverseGeocode(
        coordinate: CLLocationCoordinate2D
    ) async throws -> String {
        
        guard isValidCoordinate(coordinate) else {
            throw LocationError.invalidAddress
        }
        
        let location = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        
        return try await withThrowingTaskGroup(of: String.self) { group in
            // Tâche de géocodage inverse
            group.addTask {
                try await self.performReverseGeocodingOperation(location: location)
            }
            
            // Tâche de timeout
            group.addTask {
                try await Task.sleep(for: .seconds(self.timeoutInterval))
                throw LocationError.timeout
            }
            
            // Retourner le premier résultat
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
    
    // MARK: - Opérations privées
    private func performGeocodingOperation(
        address: String,
        region: CLCircularRegion
    ) async throws -> CLLocationCoordinate2D {
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocationCoordinate2D, Error>) in
            geocoder.geocodeAddressString(address, in: region) { placemarks, error in
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
                continuation.resume(returning: coordinate)
            }
        }
    }
    
    private func performReverseGeocodingOperation(
        location: CLLocation
    ) async throws -> String {
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
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
    
    // MARK: - Utilitaires thread-safe
    private func sanitizeAddress(_ address: String) -> String {
        let maxLength = 200
        let trimmed = String(address.prefix(maxLength))
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: ",-./()#'\""))
        
        let filtered = trimmed.unicodeScalars
            .filter { allowedCharacters.contains($0) }
            .map(String.init)
            .joined()
        
        return filtered.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return CLLocationCoordinate2DIsValid(coordinate) &&
               coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
               coordinate.longitude >= -180 && coordinate.longitude <= 180
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
}

// MARK: - Service de géolocalisation principal avec réactivité UI corrigée
@MainActor
class LocationService: NSObject, LocationServiceProtocol {
    // MARK: - Configuration
    private static let ottawaFallbackLocation = CLLocationCoordinate2D(
        latitude: 45.4215,
        longitude: -75.6972
    )
    private static let timeoutInterval: TimeInterval = 10
    
    // MARK: - Published Properties - Thread-safe sur MainActor
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationAvailable: Bool = false
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private let operationsActor = LocationOperationsActor()
    
    // États thread-safe pour les continuations
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    private var permissionContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    
    // MARK: - Initialisation
    override init() {
        super.init()
        
        setupLocationManagerSync()
        
        Task { @MainActor in
            await setupLocationManagerAsync()
            await checkInitialPermissions()
        }
    }
    
    // MARK: - Configuration thread-safe
    private func setupLocationManagerSync() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50
        authorizationStatus = locationManager.authorizationStatus
    }
    // MARK: - Configuration thread-safe async
    private func setupLocationManagerAsync() async {
        await updateLocationAvailability()
    }
    private func checkInitialPermissions() async {
        let servicesEnabled = await Task.detached { @Sendable in
            return CLLocationManager.locationServicesEnabled()
        }.value
        
        if !servicesEnabled {
            isLocationAvailable = false
        }
        await updateLocationAvailability()
    }
    
    // MARK: - Gestion des permissions avec réactivité UI
    func requestLocationPermission() {
        Task { @MainActor in
            switch authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
                let newStatus = await waitForPermissionResult()
                await handlePermissionResult(newStatus)
                
            case .denied, .restricted:
                await openLocationSettings()
                
            case .authorizedWhenInUse, .authorizedAlways:
                await startLocationUpdatesInternal()
                
            @unknown default:
                locationManager.requestWhenInUseAuthorization()
            }
        }
    }
    
    private func waitForPermissionResult() async -> CLAuthorizationStatus {
        return await withCheckedContinuation { (continuation: CheckedContinuation<CLAuthorizationStatus, Never>) in
            permissionContinuation = continuation
            
            // Timeout automatique avec Task isolé
            Task {
                try? await Task.sleep(for: .seconds(10))
                await MainActor.run { [weak self] in
                    if let permissionCont = self?.permissionContinuation {
                        self?.permissionContinuation = nil
                        permissionCont.resume(returning: self?.authorizationStatus ?? .notDetermined)
                    }
                }
            }
        }
    }
    
    private func handlePermissionResult(_ status: CLAuthorizationStatus) async {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            isLocationAvailable = true
            await startLocationUpdatesInternal()
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
    
    // MARK: - Démarrage/Arrêt de la localisation thread-safe
    func startLocationUpdates() {
        Task { @MainActor in
            await startLocationUpdatesInternal()
        }
    }
    
    private func startLocationUpdatesInternal() async {
        let servicesEnabled = await Task.detached { @Sendable in
            return CLLocationManager.locationServicesEnabled()
        }.value
        
        guard servicesEnabled else {
            isLocationAvailable = false
            return
        }
        
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            isLocationAvailable = false
            return
        }
        
        isLocationAvailable = true
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        Task { @MainActor in
            locationManager.stopUpdatingLocation()
        }
    }
    
    // MARK: - Géocodage non-bloquant via Actor
    func geocodeAddress(_ address: String) async throws -> CLLocationCoordinate2D {
        let searchCenter = await MainActor.run { () -> CLLocationCoordinate2D in
            return currentLocation ?? Self.ottawaFallbackLocation
        }
        
        return try await operationsActor.performGeocode(
            address: address,
            searchCenter: searchCenter
        )
    }
    
    // MARK: - Géocodage inverse non-bloquant via Actor
    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> String {
        return try await operationsActor.performReverseGeocode(coordinate: coordinate)
    }
    
    // MARK: - Obtenir position actuelle non-bloquante
    func getCurrentLocationOnce() async throws -> CLLocationCoordinate2D {
        let servicesEnabled = await Task.detached { @Sendable in
            return CLLocationManager.locationServicesEnabled()
        }.value
        
        guard servicesEnabled else {
            throw LocationError.locationDisabled
        }
        
        // Vérifier les permissions sur MainActor
        let hasPermission = await MainActor.run { () -> Bool in
            authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        }
        
        guard hasPermission else {
            throw LocationError.permissionDenied
        }
        
        // Retourner la position actuelle si disponible
        let existingLocation = await MainActor.run { () -> CLLocationCoordinate2D? in
            return currentLocation
        }
        
        if let currentLocation = existingLocation {
            return currentLocation
        }
        
        // Sinon, demander une nouvelle position
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocationCoordinate2D, Error>) in
            Task { @MainActor in
                locationContinuation = continuation
                locationManager.requestLocation()
                
                // Timeout avec Task simple au lieu de Task.detached
                let timeoutInterval = Self.timeoutInterval
                Task {
                    try? await Task.sleep(for: .seconds(timeoutInterval))
                    await MainActor.run { [weak self] in
                        if let locationCont = self?.locationContinuation {
                            self?.locationContinuation = nil
                            locationCont.resume(throwing: LocationError.timeout)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Utilitaires thread-safe
    private func updateLocationAvailability() async {
        let servicesEnabled = await Task.detached { @Sendable in
            return CLLocationManager.locationServicesEnabled()
        }.value
        
        let hasPermission = (authorizationStatus == .authorizedWhenInUse ||
                           authorizationStatus == .authorizedAlways)
        
        isLocationAvailable = servicesEnabled && hasPermission
    }
    
    private func handleLocationUpdate(_ coordinate: CLLocationCoordinate2D) async {
        await MainActor.run { [weak self] in
            self?.currentLocation = coordinate
            
            if let locationCont = self?.locationContinuation {
                self?.locationContinuation = nil
                locationCont.resume(returning: coordinate)
            }
        }
    }
    
    private func handleLocationError(_ error: Error) async {
        print("Location manager error: \(error.localizedDescription)")
        
        await MainActor.run { [weak self] in
            if let locationCont = self?.locationContinuation {
                self?.locationContinuation = nil
                locationCont.resume(throwing: LocationError.unknown)
            }
        }
    }
    
    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) async {
        await MainActor.run { [weak self] in
            self?.authorizationStatus = status
            
            if let permissionCont = self?.permissionContinuation {
                self?.permissionContinuation = nil
                permissionCont.resume(returning: status)
            }
        }
        
        await updateLocationAvailability()
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            await startLocationUpdatesInternal()
        case .denied, .restricted:
            await MainActor.run { [weak self] in
                self?.currentLocation = nil
                self?.isLocationAvailable = false
            }
            locationManager.stopUpdatingLocation()
        case .notDetermined:
            await MainActor.run { [weak self] in
                self?.isLocationAvailable = false
            }
        @unknown default:
            await MainActor.run { [weak self] in
                self?.isLocationAvailable = false
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate avec réactivité UI corrigée
extension LocationService: CLLocationManagerDelegate {
    
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        
        let coordinate = location.coordinate
        
        // Validation non-bloquante
        guard CLLocationCoordinate2DIsValid(coordinate) &&
              coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
              coordinate.longitude >= -180 && coordinate.longitude <= 180 else {
            return
        }
        
        // Mise à jour thread-safe sur MainActor
        Task { @MainActor [weak self, coordinate] in
            await self?.handleLocationUpdate(coordinate)
        }
    }
    
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        // Gestion d'erreur thread-safe
        Task { @MainActor [weak self, error] in
            await self?.handleLocationError(error)
        }
    }
    
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        // Gestion du changement d'autorisation thread-safe
        Task { @MainActor [weak self, status] in
            await self?.handleAuthorizationChange(status)
        }
    }
}
