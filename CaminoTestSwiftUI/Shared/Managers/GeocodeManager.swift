//
//  GeocodeManager.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-23.
//

import Foundation
import CoreLocation

// MARK: - Gestionnaire global de géocodage avec queue
@MainActor
public class GeocodeManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = GeocodeManager()
    
    // MARK: - Private Properties
    private let geocoder = CLGeocoder()
    private var isProcessing = false
    private var pendingRequests: [GeocodeRequest] = []
    
    // MARK: - Initialisation privée
    private init() {}
    
    // MARK: - Structure de requête
    private struct GeocodeRequest {
        let coordinate: CLLocationCoordinate2D
        let continuation: CheckedContinuation<String, Error>
        let requestId: String
        
        init(coordinate: CLLocationCoordinate2D, continuation: CheckedContinuation<String, Error>) {
            self.coordinate = coordinate
            self.continuation = continuation
            self.requestId = UUID().uuidString
        }
    }
    
    // MARK: - Méthode publique de géocodage
    public func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> String {
        print("🔍 GeocodeManager: Request for \(coordinate)")
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = GeocodeRequest(coordinate: coordinate, continuation: continuation)
            
            pendingRequests.append(request)
            print("📋 GeocodeManager: Queued request \(request.requestId), queue size: \(pendingRequests.count)")
            
            Task {
                await processNextRequest()
            }
        }
    }
    
    // MARK: - Traitement de la queue
    private func processNextRequest() async {
        guard !isProcessing, !pendingRequests.isEmpty else { return }
        
        isProcessing = true
        let request = pendingRequests.removeFirst()
        
        print(" GeocodeManager: Processing request \(request.requestId)")
        
        do {
            let address = try await performSingleGeocode(request.coordinate)
            request.continuation.resume(returning: address)
            print(" GeocodeManager: Success for \(request.requestId): \(address)")
            
        } catch {
            request.continuation.resume(throwing: error)
            print(" GeocodeManager: Error for \(request.requestId): \(error)")
        }
        
        isProcessing = false
        
        // Traiter la requête suivante
        if !pendingRequests.isEmpty {
            Task {
                try? await Task.sleep(for: .milliseconds(100)) // Petit délai entre requêtes
                await processNextRequest()
            }
        }
    }
    
    // MARK: - Géocodage individuel
    private func performSingleGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        return try await withCheckedThrowingContinuation { continuation in
            // ✅ Pas besoin de [weak self] car on n'utilise pas self
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    continuation.resume(throwing: NSError(
                        domain: "GeocodeError",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "No address found"]
                    ))
                    return
                }
                
                // Formatage inline (pas besoin d'appeler self.formatPlacemark())
                var components: [String] = []
                
                // Partie 1: "1154 Tischart Cres"
                if let number = placemark.subThoroughfare?.trimmingCharacters(in: .whitespaces),
                   let street = placemark.thoroughfare?.trimmingCharacters(in: .whitespaces),
                   !number.isEmpty, !street.isEmpty {
                    components.append("\(number) \(street)")
                } else if let street = placemark.thoroughfare?.trimmingCharacters(in: .whitespaces),
                          !street.isEmpty {
                    components.append(street)
                }
                
                // Partie 2: "Gloucester"
                if let city = placemark.locality?.trimmingCharacters(in: .whitespaces), !city.isEmpty {
                    components.append(city)
                }
                
                // Partie 3: "ON K1B 5P5"
                var provincePostal: [String] = []
                if let province = placemark.administrativeArea?.trimmingCharacters(in: .whitespaces), !province.isEmpty {
                    provincePostal.append(province)
                }
                if let postal = placemark.postalCode?.trimmingCharacters(in: .whitespaces), !postal.isEmpty {
                    provincePostal.append(postal)
                }
                
                if !provincePostal.isEmpty {
                    components.append(provincePostal.joined(separator: " "))
                }
                
                let address = components.isEmpty ? "Adresse inconnue" : components.joined(separator: ", ")
                continuation.resume(returning: address)
            }
        }
    }
//    private func formatPlacemark(_ placemark: CLPlacemark) -> String {
//        var components: [String] = []
//        
//        // Partie 1: "1154 Tischart Cres"
//        if let number = placemark.subThoroughfare?.trimmingCharacters(in: .whitespaces),
//           let street = placemark.thoroughfare?.trimmingCharacters(in: .whitespaces),
//           !number.isEmpty, !street.isEmpty {
//            components.append("\(number) \(street)")
//        } else if let street = placemark.thoroughfare?.trimmingCharacters(in: .whitespaces),
//                  !street.isEmpty {
//            components.append(street)
//        }
//        
//        // Partie 2: "Gloucester"
//        if let city = placemark.locality?.trimmingCharacters(in: .whitespaces), !city.isEmpty {
//            components.append(city)
//        }
//        
//        // Partie 3: "ON K1B 5P5"
//        var provincePostal: [String] = []
//        if let province = placemark.administrativeArea?.trimmingCharacters(in: .whitespaces), !province.isEmpty {
//            provincePostal.append(province)
//        }
//        if let postal = placemark.postalCode?.trimmingCharacters(in: .whitespaces), !postal.isEmpty {
//            provincePostal.append(postal)
//        }
//        
//        if !provincePostal.isEmpty {
//            components.append(provincePostal.joined(separator: " "))
//        }
//        
//        return components.isEmpty ? "Adresse inconnue" : components.joined(separator: ", ")
//    }
//    
    // MARK: - Méthode de nettoyage
    public func clearQueue() {
        print(" GeocodeManager: Clearing queue of \(pendingRequests.count) requests")
        
        for request in pendingRequests {
            request.continuation.resume(throwing: CancellationError())
        }
        
        pendingRequests.removeAll()
        geocoder.cancelGeocode()
    }
}
