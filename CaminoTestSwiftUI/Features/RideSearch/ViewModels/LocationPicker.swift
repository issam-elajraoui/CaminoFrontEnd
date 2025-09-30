//
//  Untitled.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-29.
//


import Foundation
import CoreLocation
import Combine

// MARK: - Gestion du pickup GPS vs Custom
@MainActor
class LocationPicker: ObservableObject {
    
    // MARK: - Published Properties
    @Published var useCustomPickup: Bool = false {
        didSet {
            handlePickupModeChange()
        }
    }
    @Published var isPickupFromGPS: Bool = true
    @Published var gpsPickupAddress: String = ""
    @Published var customPickupAddress: String = ""
    @Published var pickupCoordinate: CLLocationCoordinate2D?
    
    // MARK: - Computed Property
    var displayPickupAddress: String {
        return useCustomPickup ? customPickupAddress : gpsPickupAddress
    }
    
    // MARK: - Dependencies
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Callbacks
    var onPickupChanged: ((CLLocationCoordinate2D?) -> Void)?
    var onClearErrors: (() -> Void)?
    
    // MARK: - Setup
    func observeLocationService(_ locationService: LocationService) {
        locationService.$currentLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.handleGPSLocationUpdate(location)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - GPS Location Updates (CODE EXTRAIT TEL QUEL)
    private func handleGPSLocationUpdate(_ location: CLLocationCoordinate2D?) {
        print("🌐 LocationPicker.handleGPSLocationUpdate called with: \(String(describing: location))")
        
        guard let location = location,
              MapboxConfig.isValidCoordinate(location) else {
            handleGPSUnavailable()
            return
        }
        
        if !useCustomPickup {
            print("🎯 LocationPicker will call updateGPSPickup...")
            updateGPSPickup(location)
        }
    }
    
    private func updateGPSPickup(_ coordinate: CLLocationCoordinate2D) {
        print("📍 LocationPicker.updateGPSPickup called for: \(coordinate)")
        pickupCoordinate = coordinate
        isPickupFromGPS = true
        
        Task {
            do {
                print("🔄 LocationPicker calling GeocodeManager...")
                
                let address = try await GeocodeManager.shared.reverseGeocode(coordinate)
                
                await MainActor.run {
                    gpsPickupAddress = address.isEmpty ?
                        "Position actuelle" :
                        address
                    print("✅ LocationPicker got address: '\(gpsPickupAddress)'")
                }
            } catch {
                print("❌ LocationPicker geocoding failed: \(error)")
                await MainActor.run {
                    gpsPickupAddress = "Position actuelle"
                }
            }
        }
        
        onPickupChanged?(coordinate)
    }
    
    private func handleGPSUnavailable() {
        let ottawaCoordinate = CLLocationCoordinate2D(latitude: 45.4215, longitude: -75.6972)
        
        if !useCustomPickup {
            pickupCoordinate = ottawaCoordinate
            isPickupFromGPS = false
            gpsPickupAddress = "fallbackLocation".localized
            onPickupChanged?(ottawaCoordinate)
        }
    }
    
    // MARK: - Mode Change (CODE EXTRAIT TEL QUEL)
    private func handlePickupModeChange() {
        if useCustomPickup {
            isPickupFromGPS = false
            
            if customPickupAddress.isEmpty {
                pickupCoordinate = nil
                onPickupChanged?(nil)
            }
        } else {
            isPickupFromGPS = true
            
            // Réutiliser l'adresse GPS si disponible
            if !gpsPickupAddress.isEmpty, let coord = pickupCoordinate {
                onPickupChanged?(coord)
            } else {
                handleGPSUnavailable()
            }
        }
        
        onClearErrors?()
    }
    
    // MARK: - Public Methods (CODE EXTRAIT TEL QUEL)
    func enableCustomPickup() {
        useCustomPickup = true
        customPickupAddress = gpsPickupAddress
    }
    
    func disableCustomPickup() {
        useCustomPickup = false
        customPickupAddress = ""
    }
    
    func setCustomPickupAddress(_ address: String) {
        customPickupAddress = address
    }
    
    func setCustomPickupCoordinate(_ coordinate: CLLocationCoordinate2D) {
        guard MapboxConfig.isValidCoordinate(coordinate) else { return }
        pickupCoordinate = coordinate
        isPickupFromGPS = false
        onPickupChanged?(coordinate)
    }
}
