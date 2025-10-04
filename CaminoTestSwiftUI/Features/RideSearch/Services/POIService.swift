//
//  POIService.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-10-04.
//


import Foundation
import CoreLocation
import MapKit

@MainActor
class POIService {
    
    static let shared = POIService()
    
    private init() {}
    
    // MARK: - Configuration
    private let searchRadius: CLLocationDistance = 2000 // 2 km
    private let maxPOIsPerCategory = 5
    
    // MARK: - Récupération POIs proches
    func fetchNearbyPOIs(
        center: CLLocationCoordinate2D,
        categories: [POICategory] = POICategory.allCases
    ) async throws -> [PointOfInterest] {
        
        guard MapboxConfig.isValidCoordinate(center) else {
            throw POIError.invalidLocation
        }
        
        var allPOIs: [PointOfInterest] = []
        
        for category in categories {
            let categoryPOIs = try await searchPOIs(
                center: center,
                category: category
            )
            allPOIs.append(contentsOf: categoryPOIs)
        }
        
        return allPOIs
    }
    
    // MARK: - Recherche par catégorie
    private func searchPOIs(
        center: CLLocationCoordinate2D,
        category: POICategory
    ) async throws -> [PointOfInterest] {
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = getNaturalLanguageQuery(for: category)
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: searchRadius,
            longitudinalMeters: searchRadius
        )
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            
            let pois = response.mapItems.prefix(maxPOIsPerCategory).compactMap { mapItem -> PointOfInterest? in
                guard let name = mapItem.name,
                      MapboxConfig.isValidCoordinate(mapItem.placemark.coordinate) else {
                    return nil
                }
                
                let address = formatAddress(from: mapItem.placemark)
                
                return PointOfInterest(
                    id: "\(category.rawValue)-\(UUID().uuidString)",
                    name: name,
                    category: category,
                    coordinate: mapItem.placemark.coordinate,
                    address: address
                )
            }
            
            return Array(pois)
            
        } catch {
            print("❌ POIService: Error searching \(category.rawValue) - \(error)")
            return []
        }
    }
    
    // MARK: - Helper
    private func getNaturalLanguageQuery(for category: POICategory) -> String {
        switch category {
        case .library: return "library"
        case .supermarket: return "supermarket grocery store"
        case .park: return "park"
        case .hospital: return "hospital"
        case .restaurant: return "restaurant"
        case .gasStation: return "gas station"
        }
    }
    
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        if let street = placemark.thoroughfare {
            components.append(street)
        }
        if let city = placemark.locality {
            components.append(city)
        }
        
        return components.joined(separator: ", ")
    }
}

// MARK: - Erreur POI
enum POIError: Error, LocalizedError {
    case invalidLocation
    case searchFailed
    case noResultsFound
    
    var errorDescription: String? {
        switch self {
        case .invalidLocation: return "Invalid location for POI search"
        case .searchFailed: return "POI search failed"
        case .noResultsFound: return "No POIs found nearby"
        }
    }
}
