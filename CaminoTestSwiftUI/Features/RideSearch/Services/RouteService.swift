//
//  RouteService.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-20.
//

import Foundation
import MapKit
import CoreLocation

public class RouteService {
    
    // MARK: - Configuration
    private static let timeout: TimeInterval = 15
    
    // MARK: - Calcul d'itinéraire
    public static func calculateRoute(
        from startCoordinate: CLLocationCoordinate2D,
        to endCoordinate: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType = .automobile
    ) async throws -> RouteResult {
        
        // Validation des coordonnées
        guard CLLocationCoordinate2DIsValid(startCoordinate),
              CLLocationCoordinate2DIsValid(endCoordinate) else {
            throw RouteError.invalidCoordinates
        }
        
        // Création des placemarks
        let startPlacemark = MKPlacemark(coordinate: startCoordinate)
        let endPlacemark = MKPlacemark(coordinate: endCoordinate)
        
        // Configuration de la requête
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: startPlacemark)
        request.destination = MKMapItem(placemark: endPlacemark)
        request.transportType = transportType
        request.requestsAlternateRoutes = false
        
        // Calcul avec timeout
        return try await withThrowingTaskGroup(of: RouteResult.self) { group in
            
            // Tâche de calcul d'itinéraire
            group.addTask {
                try await performDirectionsRequest(request)
            }
            
            // Tâche de timeout
            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw RouteError.timeout
            }
            
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
    
    // MARK: - Exécution de la requête
    private static func performDirectionsRequest(
        _ request: MKDirections.Request
    ) async throws -> RouteResult {
        
        let directions = MKDirections(request: request)
        
        return try await withCheckedThrowingContinuation { continuation in
            directions.calculate { response, error in
                if let error = error {
                    continuation.resume(throwing: RouteError.calculationFailed(error.localizedDescription))
                    return
                }
                
                guard let response = response,
                      let route = response.routes.first else {
                    continuation.resume(throwing: RouteError.noRouteFound)
                    return
                }
                
                let result = RouteResult(
                    polyline: route.polyline,
                    distance: route.distance,
                    expectedTravelTime: route.expectedTravelTime,
                    name: route.name,
                    advisoryNotices: route.advisoryNotices
                )
                
                continuation.resume(returning: result)
            }
        }
    }
}

// MARK: - Modèles
public struct RouteResult {
    public let polyline: MKPolyline
    public let distance: CLLocationDistance // en mètres
    public let expectedTravelTime: TimeInterval // en secondes
    public let name: String
    public let advisoryNotices: [String]
    
    // Propriétés calculées pour l'affichage
    public var distanceFormatted: String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: distance)
    }
    
    public var travelTimeFormatted: String {
        let minutes = Int(expectedTravelTime / 60)
        return "\(minutes) min"
    }
}

public enum RouteError: Error, LocalizedError {
    case invalidCoordinates
    case calculationFailed(String)
    case noRouteFound
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .invalidCoordinates:
            return "Invalid coordinates provided"
        case .calculationFailed(let message):
            return "Route calculation failed: \(message)"
        case .noRouteFound:
            return "No route found between the specified locations"
        case .timeout:
            return "Route calculation timeout"
        }
    }
}
