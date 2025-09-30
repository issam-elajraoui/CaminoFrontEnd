//
//  Route.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-29.
//

import Foundation
import CoreLocation

// MARK: - Gestion du calcul d'itinéraire
@MainActor
class Route: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentRoute: RouteResult?
    @Published var isCalculatingRoute = false
    @Published var estimatedDistance = "0 km"
    @Published var estimatedFare = "$0.00"
    @Published var showEstimate = false
    
    // MARK: - Private Properties
    private var routeCalculationTask: Task<Void, Never>?
    
    // MARK: - Configuration
    private var serviceType: String = "standard"
    
    // MARK: - Public Methods
    
    func setServiceType(_ type: String) {
        serviceType = type
    }
    
    func scheduleRouteCalculation(
        from pickup: CLLocationCoordinate2D?,
        to destination: CLLocationCoordinate2D?
    ) {
        routeCalculationTask?.cancel()
        
        guard let pickup = pickup, let destination = destination else {
            currentRoute = nil
            showEstimate = false
            return
        }
        
        routeCalculationTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(1000)) // 1 seconde de debounce
                guard !Task.isCancelled else { return }
                await self?.calculateRoute(from: pickup, to: destination)
            } catch {
                // Task annulé
            }
        }
    }
    
    // MARK: - Private Methods (CODE EXTRAIT TEL QUEL)
    
    private func calculateRoute(
        from pickup: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async {
        guard MapboxConfig.isValidCoordinate(pickup),
              MapboxConfig.isValidCoordinate(destination) else { return }
        
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
    
    // MARK: - Cleanup
    func cancelRouteCalculation() {
        routeCalculationTask?.cancel()
        routeCalculationTask = nil
    }
}
