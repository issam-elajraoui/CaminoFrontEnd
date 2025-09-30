//
//  DriverSearch.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-29.
//


import Foundation
import CoreLocation

// MARK: - Gestion de la recherche de conducteurs
@MainActor
class DriverSearch: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isSearching = false
    @Published var showDriverResults = false
    @Published var availableDrivers: [Driver] = []
    @Published var pickupError = ""
    @Published var destinationError = ""
    @Published var userFriendlyErrorMessage = ""
    @Published var showError = false
    
    // MARK: - Validation Data
    private var pickupCoordinate: CLLocationCoordinate2D?
    private var destinationCoordinate: CLLocationCoordinate2D?
    private var pickupAddress: String = ""
    private var destinationAddress: String = ""
    private var useCustomPickup: Bool = false
    
    // MARK: - Public Methods
    
    func updatePickupData(
        coordinate: CLLocationCoordinate2D?,
        address: String,
        isCustom: Bool
    ) {
        pickupCoordinate = coordinate
        pickupAddress = address
        useCustomPickup = isCustom
    }
    
    func updateDestinationData(
        coordinate: CLLocationCoordinate2D?,
        address: String
    ) {
        destinationCoordinate = coordinate
        destinationAddress = address
    }
    
    // MARK: - Search Drivers (CODE EXTRAIT TEL QUEL)
    
    func searchDrivers() async {
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
            userFriendlyErrorMessage = "searchError".localized
            showError = true
        }
    }
    
    func selectDriver(_ driver: Driver) {
        print("Driver selected: \(driver.id)")
        // TODO: Implémenter la logique de sélection
    }
    
    // MARK: - Private Methods (CODE EXTRAIT TEL QUEL)
    
    private func validateForm() -> Bool {
        clearErrors()
        var isValid = true
        
        if useCustomPickup {
            if pickupAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pickupError = "pickupRequired".localized
                isValid = false
            }
        } else {
            if pickupCoordinate == nil {
                pickupError = "locationError".localized
                isValid = false
            }
        }
        
        if destinationAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            destinationError = "destinationRequired".localized
            isValid = false
        }
        
        return isValid
    }
    
    private func performRideSearch() async throws {
        guard let pickup = pickupCoordinate,
              let destination = destinationCoordinate else {
            throw RideSearchError.invalidLocation
        }
        
        guard MapboxConfig.isValidCoordinate(pickup) && MapboxConfig.isValidCoordinate(destination) else {
            throw RideSearchError.invalidLocation
        }
        
        // TODO: Remplacer par vraie API
        try await Task.sleep(for: .seconds(2))
        
        availableDrivers = [
            Driver(id: "1", name: "Jean Dupont", rating: 4.8, eta: "3 min", price: "$12.50"),
            Driver(id: "2", name: "Marie Tremblay", rating: 4.9, eta: "5 min", price: "$11.75")
        ]
    }
    
    private func clearErrors() {
        pickupError = ""
        destinationError = ""
        userFriendlyErrorMessage = ""
    }
    
    // MARK: - Computed Properties
    
    var canSearch: Bool {
        let hasValidPickup = useCustomPickup ?
            (!pickupAddress.isEmpty && pickupCoordinate != nil) :
            (pickupCoordinate != nil)
        
        return hasValidPickup &&
               !destinationAddress.isEmpty &&
               destinationCoordinate != nil
    }
}
