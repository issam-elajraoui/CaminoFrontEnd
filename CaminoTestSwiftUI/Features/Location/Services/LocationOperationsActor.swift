//
//  LocationService.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-16.
//


import Foundation
import CoreLocation
import MapKit

// MARK: - Actor pour opérations géolocalisation thread-safe
actor LocationOperationsActor {
    private let geocoder = CLGeocoder()
    private let timeoutInterval: TimeInterval = 10
    private let searchRadiusKm: Double = 50
    
    // MARK: - Géocodage sécurisé et non-bloquant
    func performGeocode(
        address: String,
        searchCenter: CLLocationCoordinate2D
    ) async throws -> CLLocationCoordinate2D {
        
        // Validation d'entrée
        let sanitizedAddress = sanitizeAddress(address)
        guard !sanitizedAddress.isEmpty else {
            throw LocationError.invalidAddress
        }
        
        let searchRegion = CLCircularRegion(
            center: searchCenter,
            radius: searchRadiusKm * 1000,
            identifier: "searchArea"
        )
        
        // Géocodage avec timeout robuste
        return try await withThrowingTaskGroup(of: CLLocationCoordinate2D.self) { group in
            // Tâche de géocodage
            group.addTask {
                try await self.performGeocodingOperation(
                    address: sanitizedAddress,
                    region: searchRegion
                )
            }
            
            // Tâche de timeout
            group.addTask {
                try await Task.sleep(for: .seconds(self.timeoutInterval))
                throw LocationError.timeout
            }
            
            // Retourner le premier résultat (géocodage ou timeout)
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
    
    
    // MARK: - Opérations privées
    private func performGeocodingOperation(
        address: String,
        region: CLCircularRegion
    ) async throws -> CLLocationCoordinate2D {
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocationCoordinate2D, Error>) in
            geocoder.geocodeAddressString(address, in: region) { placemarks, error in
                if error != nil {
                    continuation.resume(throwing: LocationError.geocodingFailed)
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    continuation.resume(throwing: LocationError.geocodingFailed)
                    return
                }
                
                let coordinate = location.coordinate
                continuation.resume(returning: coordinate)
            }
        }
    }
    

    // MARK: - Utilitaires thread-safe
    private func sanitizeAddress(_ address: String) -> String {
        let maxLength = 200
        let trimmed = String(address.prefix(maxLength))
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: ",-./()#'\""))
        
        let filtered = trimmed.unicodeScalars
            .filter { allowedCharacters.contains($0) }
            .map(String.init)
            .joined()
        
        return filtered.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
