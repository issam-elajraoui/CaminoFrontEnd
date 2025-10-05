//
//  DriverAnnotation.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-10-04.
//

import Foundation
import CoreLocation
import SwiftUI

// MARK: - Annotation spécifique pour les conducteurs disponibles
struct DriverAnnotation: Identifiable, Equatable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let bearing: Double
    let status: DriverStatus
    let vehicleType: String
    
    // MARK: - Initialisation depuis AvailableDriver
    init(from driver: AvailableDriver) {
        self.id = driver.id
        self.coordinate = driver.coordinate
        self.bearing = driver.bearing
        self.status = driver.status
        self.vehicleType = driver.vehicleType
    }
    
    // MARK: - Propriétés visuelles
    var color: Color {
        switch status {
        case .available:
            return .green
        case .enRoute:
            return .orange
        case .busy:
            return .gray
        }
    }
    
    var iconName: String {
        return "car.fill" // SF Symbol
    }
    
    var iconSize: Double {
        return 20.0
    }
    
    // MARK: - Equatable
    static func == (lhs: DriverAnnotation, rhs: DriverAnnotation) -> Bool {
        return lhs.id == rhs.id
    }
}
