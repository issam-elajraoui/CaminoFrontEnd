//
//  CLLocationCoordinate2D+Extensions.swift - CORRECTION
//  CaminoTestSwiftUI
//

import CoreLocation
import Turf

// MARK: -  CORRECTION: Extension CLLocationCoordinate2D pour Hashable seulement
extension CLLocationCoordinate2D: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
    
    //  CORRECTION: Supprimer Equatable car déjà conforme
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return abs(lhs.latitude - rhs.latitude) < 0.000001 &&
               abs(lhs.longitude - rhs.longitude) < 0.000001
    }
}
