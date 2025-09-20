//
//  LocationError.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-20.
//

import Foundation

// MARK: - Erreurs de géolocalisation
public enum LocationError: Error, LocalizedError {
    case permissionDenied
    case locationDisabled
    case geocodingFailed
    case invalidAddress
    case outsideServiceArea
    case timeout
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission denied"
        case .locationDisabled:
            return "Location services disabled"
        case .geocodingFailed:
            return "Address not found"
        case .invalidAddress:
            return "Invalid address"
        case .outsideServiceArea:
            return "Address outside service area"
        case .timeout:
            return "Location request timeout"
        case .unknown:
            return "Location error"
        }
    }
    
    func localizedDescription(language: String) -> String {
        if language == "fr" {
            switch self {
            case .permissionDenied:
                return "Permission de localisation refusée"
            case .locationDisabled:
                return "Services de localisation désactivés"
            case .geocodingFailed:
                return "Adresse introuvable"
            case .invalidAddress:
                return "Adresse invalide"
            case .outsideServiceArea:
                return "Adresse hors zone de service"
            case .timeout:
                return "Délai de localisation dépassé"
            case .unknown:
                return "Erreur de localisation"
            }
        }
        return errorDescription ?? "Location error"
    }
}
