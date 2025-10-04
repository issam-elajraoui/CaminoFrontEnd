//
//  Vehicle.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-10-04.
//

import Foundation
import CoreLocation
import UIKit

enum CarStatus {
    case available
    case busy
    case offline
    
    var color: UIColor {
        switch self {
        case .available: return .systemGreen
        case .busy: return .systemRed
        case .offline: return .systemGray
        }
    }
}

struct CarVehicle: Identifiable, Hashable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let status: CarStatus
    let heading: Double
    
    static func == (lhs: CarVehicle, rhs: CarVehicle) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
