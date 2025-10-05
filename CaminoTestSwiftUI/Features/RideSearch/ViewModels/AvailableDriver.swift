//
//  AvailableDriver.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-10-04.
//

import Foundation
import CoreLocation

// MARK: - Modèle pour conducteur disponible en temps réel
struct AvailableDriver: Identifiable, Hashable {
    let id: String
    var coordinate: CLLocationCoordinate2D
    var bearing: Double // Orientation 0-360°
    var status: DriverStatus
    let vehicleType: String
    var lastUpdate: Date
    
    // MARK: - Initialisation avec validation
    init(
        id: String,
        coordinate: CLLocationCoordinate2D,
        bearing: Double,
        status: DriverStatus = .available,
        vehicleType: String = "standard",
        lastUpdate: Date = Date()
    ) {
        self.id = AvailableDriver.sanitizeId(id)
        self.coordinate = MapboxConfig.isValidCoordinate(coordinate) ? coordinate : MapboxConfig.fallbackRegion
        self.bearing = AvailableDriver.sanitizeBearing(bearing)
        self.status = status
        self.vehicleType = AvailableDriver.sanitizeVehicleType(vehicleType)
        self.lastUpdate = lastUpdate
    }
    
    // MARK: - Hashable conformité
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AvailableDriver, rhs: AvailableDriver) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Sanitisation privée
    private static func sanitizeId(_ id: String) -> String {
        let maxLength = 50
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        
        let filtered = id.unicodeScalars
            .filter { allowedCharacters.contains($0) }
            .map(String.init)
            .joined()
        
        return String(filtered.prefix(maxLength))
    }
    
    private static func sanitizeBearing(_ bearing: Double) -> Double {
        let normalized = bearing.truncatingRemainder(dividingBy: 360)
        return normalized < 0 ? normalized + 360 : normalized
    }
    
    private static func sanitizeVehicleType(_ type: String) -> String {
        let allowed = ["standard", "premium", "economy"]
        return allowed.contains(type.lowercased()) ? type.lowercased() : "standard"
    }
}

// MARK: - Statut conducteur
enum DriverStatus: String, Codable {
    case available = "available"
    case enRoute = "en_route"
    case busy = "busy"
    
    var displayName: String {
        switch self {
        case .available:
            return "available"
        case .enRoute:
            return "enRoute"
        case .busy:
            return "busy"
        }
    }
}
