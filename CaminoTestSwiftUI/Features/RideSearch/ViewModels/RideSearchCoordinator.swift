//
//  RideSearchCoordinator.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-29.
//

import SwiftUI
import Foundation
import MapKit
import Combine
import CoreLocation

// MARK: - Coordinateur principal de recherche de course
@MainActor
class RideSearchCoordinator: ObservableObject {
    
    // MARK: - Sub-ViewModels
    @Published var addressSearch = AddressSearch()
    @Published var locationPicker = LocationPicker()
    @Published var pinpoint = Pinpoint()
    @Published var route = Route()
    @Published var driverSearch = DriverSearch()
    
    // MARK: - UI State Properties
    @Published var mapPosition = MapCameraPosition.region(RideSearchConfig.ottawaRegion)
    @Published var annotations: [LocationAnnotation] = []
    @Published var showUserLocation = false
    
    // MARK: - Form Properties
    @Published var pickupAddress = ""
    @Published var destinationAddress = ""
    @Published var passengerCount = 1
    @Published var serviceType = "standard" {
        didSet {
            route.setServiceType(serviceType)
        }
    }
    
    // MARK: - Active Field
    @Published var activeField: ActiveLocationField = .destination
    @Published var showSuggestions = false
    
    // MARK: - Location Permission
    @Published var showLocationPermission = false
    
    // MARK: - Private Properties
    private var locationService: LocationService?
    private var destinationCoordinate: CLLocationCoordinate2D?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var displayPickupAddress: String {
        return locationPicker.pickupAddress
    }
    
    var canSearch: Bool {
        return driverSearch.canSearch
    }
    
    // MARK: - Initialization
    init() {
        setupCoordination()
    }
    
    // MARK: - Setup Coordination
    private func setupCoordination() {
        
        // LocationPicker callbacks
        locationPicker.onPickupChanged = { [weak self] coordinate in
            self?.handlePickupChanged(coordinate)
        }
        
        locationPicker.onClearErrors = { [weak self] in
            self?.driverSearch.pickupError = ""
            self?.driverSearch.destinationError = ""
        }
        
        // Pinpoint callbacks
        pinpoint.onLocationChanged = { [weak self] coordinate, field in
            self?.handlePinpointLocationChanged(coordinate, for: field)
        }
        
        // Observer pinpointAddress pour mettre à jour le bon champ
        pinpoint.$pinpointAddress
            .filter { !$0.isEmpty && $0 != "Position invalide" && $0 != "Adresse introuvable" }
            .sink { [weak self] address in
                guard let self = self else { return }
                switch self.pinpoint.targetField {
                case .pickup:
                    self.locationPicker.setPickupAddress(address)
                    self.pickupAddress = address
                case .destination:
                    self.destinationAddress = address
                case .none:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Observer showSuggestions from addressSearch
        addressSearch.$suggestions
            .map { !$0.isEmpty }
            .assign(to: &$showSuggestions)
        
        $activeField
            .sink { [weak self] newActiveField in
                guard let self = self else { return }
                if self.pinpoint.isPinpointMode && newActiveField != .none {
                    self.pinpoint.targetField = newActiveField
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - LocationService Setup
    func setLocationService(_ service: LocationService) {
        self.locationService = service
        locationPicker.observeLocationService(service)
        
        // Configure search region for address search
        service.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.addressSearch.configureSearchRegion(center: location)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - View Lifecycle
    func onViewAppear() {
        checkLocationPermissions()
        
        if activeField == .none {
            activeField = .destination
        }
    }
    
    func onDisappear() {
        pinpoint.cleanupPinpointTasks()
        route.cancelRouteCalculation()
        addressSearch.cleanup()
    }
    
    // MARK: - Location Permissions
    func checkLocationPermissions() {
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
    
    func recheckLocationPermissions() {
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            checkLocationPermissions()
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
    
    // MARK: - Address Search
    func onLocationTextChanged(_ newText: String, for field: ActiveLocationField) {
        switch field {
        case .pickup:
            locationPicker.setPickupAddress(newText)
            pickupAddress = newText
            addressSearch.searchAddress(newText)
            
        case .destination:
            destinationAddress = newText
            addressSearch.searchAddress(newText)
            
        case .none:
            break
        }
    }
    
    func selectSuggestion(_ suggestion: AddressSuggestion) {
        Task {
            let resolvedSuggestion = await addressSearch.resolveCoordinates(for: suggestion)
            
            await MainActor.run {
                applySuggestionSelection(resolvedSuggestion)
            }
        }
    }
    
    private func applySuggestionSelection(_ suggestion: AddressSuggestion) {
        switch activeField {
        case .pickup:
            locationPicker.setPickupAddress(suggestion.displayText)
            pickupAddress = suggestion.displayText
            setPickupLocation(suggestion.coordinate)
            
        case .destination:
            destinationAddress = suggestion.displayText
            setDestinationLocation(suggestion.coordinate)
            
        case .none:
            break
        }
        
        showSuggestions = false
        addressSearch.suggestions = []
        activeField = .destination
    }
    
    // MARK: - Location Management
    func setPickupLocation(_ coordinate: CLLocationCoordinate2D) {
        guard MapboxConfig.isValidCoordinate(coordinate) else { return }
        locationPicker.setPickupCoordinate(coordinate)
    }
    
    func setDestinationLocation(_ coordinate: CLLocationCoordinate2D) {
        guard MapboxConfig.isValidCoordinate(coordinate) else { return }
        destinationCoordinate = coordinate
        updateMapAnnotations()
        
        route.scheduleRouteCalculation(
            from: locationPicker.pickupCoordinate,
            to: destinationCoordinate
        )
    }
    
    private func handlePickupChanged(_ coordinate: CLLocationCoordinate2D?) {
        updateMapAnnotations()
        
        driverSearch.updatePickupData(
            coordinate: coordinate,
            address: locationPicker.pickupAddress,
            isCustom: locationPicker.isRideForSomeoneElse
        )
        
        if destinationCoordinate != nil {
            route.scheduleRouteCalculation(from: coordinate, to: destinationCoordinate)
        }
    }
    
    private func handlePinpointLocationChanged(_ coordinate: CLLocationCoordinate2D, for field: ActiveLocationField) {
        switch field {
        case .pickup:
            setPickupLocation(coordinate)
        case .destination:
            destinationCoordinate = coordinate
            updateMapAnnotations()
            route.scheduleRouteCalculation(from: locationPicker.pickupCoordinate, to: coordinate)
        case .none:
            break
        }
    }
    
    private func updateMapAnnotations() {
        annotations.removeAll()
        
        if let pickup = locationPicker.pickupCoordinate {
            annotations.append(LocationAnnotation(coordinate: pickup, type: .pickup))
        }
        
        if let destination = destinationCoordinate {
            annotations.append(LocationAnnotation(coordinate: destination, type: .destination))
        }
        
        // Update map to show both points
        if let pickup = locationPicker.pickupCoordinate,
           let destination = destinationCoordinate {
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
    
    // MARK: - Pinpoint Mode
    func enablePinpointMode(for field: ActiveLocationField) {
        pinpoint.enablePinpointMode(for: field)
        showSuggestions = false
        addressSearch.suggestions = []
    }
    
    func disablePinpointMode() {
        pinpoint.disablePinpointMode()
        activeField = .destination
    }
    
    func onMapCenterChangedSimple(coordinate: CLLocationCoordinate2D) {
        pinpoint.onMapCenterChangedSimple(coordinate: coordinate)
    }
    
    // MARK: - Map Interaction
    func handleMapTap(at location: CGPoint) {
        activeField = .destination
        showSuggestions = false
    }
    
    func centerOnUserLocation() async {
        guard let locationService = locationService else {
            driverSearch.userFriendlyErrorMessage = "locationDisabled".localized
            driverSearch.showError = true
            return
        }
        
        guard locationService.isLocationAvailable else {
            driverSearch.userFriendlyErrorMessage = "locationDisabled".localized
            driverSearch.showError = true
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
                driverSearch.userFriendlyErrorMessage = locationError.localizedDescription(language: LocalizationManager.shared.currentLanguage)
                driverSearch.showError = true
            }
        } catch {
            await MainActor.run {
                driverSearch.userFriendlyErrorMessage = "locationError".localized
                driverSearch.showError = true
            }
        }
    }
    
    // MARK: - Driver Search
    func searchDrivers() async {
        activeField = .destination
        showSuggestions = false
        
        driverSearch.updatePickupData(
            coordinate: locationPicker.pickupCoordinate,
            address: displayPickupAddress,
            isCustom: locationPicker.isRideForSomeoneElse
        )
        
        driverSearch.updateDestinationData(
            coordinate: destinationCoordinate,
            address: destinationAddress
        )
        
        await driverSearch.searchDrivers()
    }
    
    func selectDriver(_ driver: Driver) {
        driverSearch.selectDriver(driver)
    }
}
