//
//  PointOfInterest.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-10-04.
//
// CaminoTestSwiftUI/Features/RideSearch/Models/PointOfInterest.swift

import UIKit
import Foundation
import CoreLocation

// MARK: - Type de POI
enum POICategory: String, CaseIterable {
    case library = "library"
    case supermarket = "supermarket"
    case park = "park"
    case hospital = "hospital"
    case restaurant = "restaurant"
    case gasStation = "gas_station"
    
    // CORRECTION: Retourner la clé au lieu de la valeur localisée
    var displayNameKey: String {
        switch self {
        case .library: return "poiLibrary"
        case .supermarket: return "poiSupermarket"
        case .park: return "poiPark"
        case .hospital: return "poiHospital"
        case .restaurant: return "poiRestaurant"
        case .gasStation: return "poiGasStation"
        }
    }
    
    // NOUVEAU: Méthode pour obtenir le nom localisé de manière synchrone
    @MainActor
    func localizedDisplayName() -> String {
        return displayNameKey.localized
    }
    
    var symbolName: String {
        switch self {
        case .library: return "book.fill"
        case .supermarket: return "cart.fill"
        case .park: return "tree.fill"
        case .hospital: return "cross.fill"
        case .restaurant: return "fork.knife"
        case .gasStation: return "fuelpump.fill"
        }
    }
    
    var color: UIColor {
        switch self {
        case .library: return .systemBlue
        case .supermarket: return .systemGreen
        case .park: return .systemGreen
        case .hospital: return .systemRed
        case .restaurant: return .systemOrange
        case .gasStation: return .systemPurple
        }
    }
}

// MARK: - Modèle Point d'Intérêt
struct PointOfInterest: Identifiable, Hashable {
    let id: String
    let name: String
    let category: POICategory
    let coordinate: CLLocationCoordinate2D
    let address: String
    
    init(id: String, name: String, category: POICategory, coordinate: CLLocationCoordinate2D, address: String = "") {
        self.id = id
        self.name = Self.sanitizeName(name)
        self.category = category
        self.coordinate = coordinate
        self.address = Self.sanitizeAddress(address)
    }
    
    static func == (lhs: PointOfInterest, rhs: PointOfInterest) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    private static func sanitizeName(_ name: String) -> String {
        let maxLength = 100
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-'&,.()"))
        
        let filtered = name.unicodeScalars
            .filter { allowedCharacters.contains($0) }
            .map(String.init)
            .joined()
        
        return String(filtered.prefix(maxLength))
    }
    
    private static func sanitizeAddress(_ address: String) -> String {
        let maxLength = 200
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-,./()#"))
        
        let filtered = address.unicodeScalars
            .filter { allowedCharacters.contains($0) }
            .map(String.init)
            .joined()
        
        return String(filtered.prefix(maxLength))
    }
}
