import Foundation
import CoreLocation
import MapKit
import Combine

// MARK: - ViewModel pour gestion des conducteurs disponibles
@MainActor
class AvailableDrivers: ObservableObject {
    
    // MARK: - Published Properties
    @Published var drivers: [AvailableDriver] = []
    
    // MARK: - Private Properties
    private var simulationTimer: Timer?
    private let maxDrivers = 15
    private let updateInterval: TimeInterval = 3.0 // 3 secondes
    private let movementSpeed: Double = 0.0001 // Déplacement léger en degrés
    
    // MARK: - Configuration
    private let spawnRadius: Double = 0.03 // ~3km en degrés (proche utilisateur)
    
    // MARK: - Public Methods
    
    /// Charge les conducteurs mock autour d'un centre donné
    func loadMockDrivers(nearCenter center: CLLocationCoordinate2D) {
        let validCenter = MapboxConfig.isValidCoordinate(center) ? center : MapboxConfig.fallbackRegion
        
        drivers = (0..<maxDrivers).map { index in
            let randomOffset = generateRandomOffset()
            let coordinate = CLLocationCoordinate2D(
                latitude: validCenter.latitude + randomOffset.latitude,
                longitude: validCenter.longitude + randomOffset.longitude
            )
            
            return AvailableDriver(
                id: "mock-driver-\(index)",
                coordinate: coordinate,
                bearing: Double.random(in: 0...360),
                status: randomStatus(),
                vehicleType: randomVehicleType(),
                lastUpdate: Date()
            )
        }
        
        print("✅ AvailableDrivers: Loaded \(drivers.count) mock drivers near \(validCenter)")
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
    
    /// Mise à jour positions (mouvement simple linéaire)
    private func updateDriverPositions() {
        drivers = drivers.map { driver in
            var updated = driver
            
            // Déplacement simple selon bearing actuel
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
            
            // Changement bearing aléatoire occasionnel (10% chance)
            if Double.random(in: 0...1) < 0.1 {
                updated.bearing = Double.random(in: 0...360)
            }
            
            return updated
        }
    }
    
    /// Génère offset aléatoire dans le rayon de spawn
    private func generateRandomOffset() -> (latitude: Double, longitude: Double) {
        let angle = Double.random(in: 0...(2 * .pi))
        let distance = Double.random(in: 0...spawnRadius)
        
        return (
            latitude: cos(angle) * distance,
            longitude: sin(angle) * distance
        )
    }
    
    /// Statut aléatoire (80% available, 20% autres)
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
        // CORRECTION: Timer invalidation peut être faite depuis n'importe quel thread
        simulationTimer?.invalidate()
    }
}
