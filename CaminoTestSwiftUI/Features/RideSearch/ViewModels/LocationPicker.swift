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
    @Published var isRideForSomeoneElse: Bool = false {
        didSet {
            handleRideModeChange()
        }
    }
    @Published var isPickupFromGPS: Bool = true
    @Published var gpsPickupAddress: String = ""
    @Published var pickupAddress: String = ""
    @Published var pickupCoordinate: CLLocationCoordinate2D?
    
    // MARK: - Callbacks
    var onPickupChanged: ((CLLocationCoordinate2D?) -> Void)?
    var onClearErrors: (() -> Void)?
    
    // MARK: - Dependencies
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup
    func observeLocationService(_ locationService: LocationService) {
        locationService.$currentLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.handleGPSLocationUpdate(location)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - GPS Location Updates
    private func handleGPSLocationUpdate(_ location: CLLocationCoordinate2D?) {
        guard let location = location,
              MapboxConfig.isValidCoordinate(location) else {
            handleGPSUnavailable()
            return
        }
        
        if !isRideForSomeoneElse && isPickupFromGPS {
            updateGPSPickup(location)
        }
    }
    
    private func updateGPSPickup(_ coordinate: CLLocationCoordinate2D) {
        pickupCoordinate = coordinate
        isPickupFromGPS = true
        
        Task {
            do {
                let address = try await GeocodeManager.shared.reverseGeocode(coordinate)
                await MainActor.run {
                    gpsPickupAddress = address.isEmpty ? "Position actuelle" : address
                    if !isRideForSomeoneElse {
                        pickupAddress = gpsPickupAddress
                    }
                }
            } catch {
                await MainActor.run {
                    gpsPickupAddress = "Position actuelle"
                    if !isRideForSomeoneElse {
                        pickupAddress = gpsPickupAddress
                    }
                }
            }
        }
        
        onPickupChanged?(coordinate)
    }
    
    private func handleGPSUnavailable() {
        let ottawaCoordinate = CLLocationCoordinate2D(latitude: 45.4215, longitude: -75.6972)
        
        if !isRideForSomeoneElse && isPickupFromGPS {
            pickupCoordinate = ottawaCoordinate
            isPickupFromGPS = false
            gpsPickupAddress = "fallbackLocation".localized
            pickupAddress = gpsPickupAddress
            onPickupChanged?(ottawaCoordinate)
        }
    }
    
    // MARK: - Mode Change
    private func handleRideModeChange() {
        if isRideForSomeoneElse {
            isPickupFromGPS = false
            pickupAddress = ""
            pickupCoordinate = nil
            onPickupChanged?(nil)
        } else {
            isPickupFromGPS = true
            if !gpsPickupAddress.isEmpty, let coord = pickupCoordinate {
                pickupAddress = gpsPickupAddress
                onPickupChanged?(coord)
            } else {
                handleGPSUnavailable()
            }
        }
        onClearErrors?()
    }
    
    // MARK: - Public Methods
    func setPickupAddress(_ address: String) {
        pickupAddress = address
    }
    
    func setPickupCoordinate(_ coordinate: CLLocationCoordinate2D) {
        guard MapboxConfig.isValidCoordinate(coordinate) else { return }
        pickupCoordinate = coordinate
        onPickupChanged?(coordinate)
    }
}
