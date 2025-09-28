//
//  LocationService.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-20.
//

import Foundation
import CoreLocation
import MapKit
import UIKit

// MARK: - Service de géolocalisation principal avec réactivité UI corrigée
@MainActor
public class LocationService: NSObject, LocationServiceProtocol {
    // MARK: - Configuration
    private static let ottawaFallbackLocation = CLLocationCoordinate2D(
        latitude: 45.4215,
        longitude: -75.6972
    )
    private static let timeoutInterval: TimeInterval = 10
    
    // MARK: - Published Properties - Thread-safe sur MainActor
    @Published public var currentLocation: CLLocationCoordinate2D?
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var isLocationAvailable: Bool = false
    
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
        await updateLocationAvailability()
    }
    
    // MARK: - Gestion des permissions avec réactivité UI
    public func requestLocationPermission() {
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
    public func startLocationUpdates() {
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
    
    public func stopLocationUpdates() {
        Task { @MainActor in
            locationManager.stopUpdatingLocation()
        }
    }
    
    // MARK: - Géocodage non-bloquant via Actor
    public func geocodeAddress(_ address: String) async throws -> CLLocationCoordinate2D {
        let searchCenter = await MainActor.run { () -> CLLocationCoordinate2D in
            return currentLocation ?? Self.ottawaFallbackLocation
        }
        
        return try await operationsActor.performGeocode(
            address: address,
            searchCenter: searchCenter
        )
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
        let hasPermission = (authorizationStatus == .authorizedWhenInUse ||
                           authorizationStatus == .authorizedAlways)
        
        isLocationAvailable = hasPermission
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


// MARK: - CLLocationManagerDelegate avec réactivité UI
extension LocationService: CLLocationManagerDelegate {
    
    nonisolated public func locationManager(
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
    
    nonisolated public func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        // Gestion d'erreur thread-safe
        Task { @MainActor [weak self, error] in
            await self?.handleLocationError(error)
        }
    }
    
    nonisolated public func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        // Gestion du changement d'autorisation thread-safe
        Task { @MainActor [weak self, status] in
            await self?.handleAuthorizationChange(status)
        }
    }
}
