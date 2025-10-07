// CORRECTION dans AvailableDrivers.swift

import Foundation
import CoreLocation
import MapKit
import Combine

@MainActor
class AvailableDrivers: ObservableObject {
    
    // MARK: - Published Properties
    @Published var drivers: [AvailableDriver] = []
    
    // MARK: - Private Properties
    private var simulationTimer: Timer?
    private let maxDrivers = 15
    private let updateInterval: TimeInterval = 3.0
    private let movementSpeed: Double = 0.00002  // ✅ Mouvement minimal (~2 mètres)
    
    // ✅ NOUVEAU : Positions fixes sur routes majeures d'Ottawa
    private static let ottawaRoadPositions: [CLLocationCoordinate2D] = [
        // Downtown Core
        CLLocationCoordinate2D(latitude: 45.4215, longitude: -75.6972), // Wellington St
        CLLocationCoordinate2D(latitude: 45.4235, longitude: -75.6980), // Bank St North
        CLLocationCoordinate2D(latitude: 45.4190, longitude: -75.6950), // Rideau St
        CLLocationCoordinate2D(latitude: 45.4200, longitude: -75.6930), // Sussex Drive
        
        // ByWard Market Area
        CLLocationCoordinate2D(latitude: 45.4270, longitude: -75.6897), // Clarence St
        CLLocationCoordinate2D(latitude: 45.4265, longitude: -75.6920), // George St
        CLLocationCoordinate2D(latitude: 45.4280, longitude: -75.6910), // York St
        
        // Glebe / Bank St
        CLLocationCoordinate2D(latitude: 45.4000, longitude: -75.6940), // Bank St South
        CLLocationCoordinate2D(latitude: 45.3950, longitude: -75.6935), // Lansdowne
        
        // Centretown
        CLLocationCoordinate2D(latitude: 45.4150, longitude: -75.7020), // Bronson Ave
        CLLocationCoordinate2D(latitude: 45.4180, longitude: -75.7050), // Lyon St
        
        // Sandy Hill / Université
        CLLocationCoordinate2D(latitude: 45.4220, longitude: -75.6830), // King Edward
        CLLocationCoordinate2D(latitude: 45.4210, longitude: -75.6800), // Nicholas St
        
        // West End
        CLLocationCoordinate2D(latitude: 45.4100, longitude: -75.7150), // Parkdale
        CLLocationCoordinate2D(latitude: 45.4050, longitude: -75.7200), // Wellington West
    ]
    
    // MARK: - Public Methods
    
    /// ✅ MODIFIER : Charge drivers UNE FOIS sur positions fixes
    func loadMockDrivers(nearCenter center: CLLocationCoordinate2D) {
        drivers = Self.ottawaRoadPositions.enumerated().map { index, coordinate in
            AvailableDriver(
                id: "mock-driver-\(index)",
                coordinate: coordinate,  // ✅ Position FIXE sur route
                bearing: Double.random(in: 0...360),
                status: randomStatus(),
                vehicleType: randomVehicleType(),
                lastUpdate: Date()
            )
        }
        
        print("✅ AvailableDrivers: Loaded \(drivers.count) drivers on fixed road positions")
    }
    
    /// Démarre la simulation de mouvement
    func startMockSimulation() {
        stopMockSimulation() // Cleanup précédent
        
        simulationTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateDriverPositions()
            }
        }
        
        print("🚗 AvailableDrivers: Mock simulation started")
    }
    
    /// Arrête la simulation
    func stopMockSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        print("🛑 AvailableDrivers: Mock simulation stopped")
    }
    
    /// Filtre les conducteurs dans une région visible
    func filterDriversInBounds(_ bounds: MKCoordinateRegion) -> [AvailableDriver] {
        let minLat = bounds.center.latitude - bounds.span.latitudeDelta / 2
        let maxLat = bounds.center.latitude + bounds.span.latitudeDelta / 2
        let minLon = bounds.center.longitude - bounds.span.longitudeDelta / 2
        let maxLon = bounds.center.longitude + bounds.span.longitudeDelta / 2
        
        return drivers.filter { driver in
            driver.coordinate.latitude >= minLat &&
            driver.coordinate.latitude <= maxLat &&
            driver.coordinate.longitude >= minLon &&
            driver.coordinate.longitude <= maxLon
        }
    }
    
    // MARK: - Private Methods
    
    /// ✅ MODIFIER : Mouvement MINIMAL pour éviter drift hors routes
    private func updateDriverPositions() {
        drivers = drivers.map { driver in
            var updated = driver
            
            // ✅ Mouvement très minimal (2 mètres)
            let radians = driver.bearing * .pi / 180
            let latDelta = cos(radians) * movementSpeed
            let lonDelta = sin(radians) * movementSpeed
            
            let newCoordinate = CLLocationCoordinate2D(
                latitude: driver.coordinate.latitude + latDelta,
                longitude: driver.coordinate.longitude + lonDelta
            )
            
            // Validation et update
            if MapboxConfig.isValidCoordinate(newCoordinate) {
                updated.coordinate = newCoordinate
                updated.lastUpdate = Date()
            }
            
            // ✅ Changement bearing plus fréquent (30% chance) pour effet visuel
            if Double.random(in: 0...1) < 0.3 {
                updated.bearing = Double.random(in: 0...360)
            }
            
            return updated
        }
    }
    
    /// Statut aléatoire (80% available)
    private func randomStatus() -> DriverStatus {
        let random = Double.random(in: 0...1)
        if random < 0.8 {
            return .available
        } else if random < 0.9 {
            return .enRoute
        } else {
            return .busy
        }
    }
    
    /// Type véhicule aléatoire
    private func randomVehicleType() -> String {
        let types = ["standard", "premium", "economy"]
        return types.randomElement() ?? "standard"
    }
    
    // MARK: - Cleanup
    nonisolated deinit {
        simulationTimer?.invalidate()
    }
}
