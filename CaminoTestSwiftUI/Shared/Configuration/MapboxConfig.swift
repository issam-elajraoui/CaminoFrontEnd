//
//  MapboxConfig.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-20.
//

import Foundation
import CoreLocation
import UIKit

// MARK: - Configuration Mapbox centralisée avec sécurité
public struct MapboxConfig {
    
    // MARK: - Configuration principale
    public static let styleURL = "mapbox://styles/mapbox/light-v11"
    public static let fallbackRegion = CLLocationCoordinate2D(latitude: 45.4215, longitude: -75.6972) // Ottawa
    public static let defaultZoom: Double = 12.0
    public static let animationDuration: TimeInterval = 1.0
    
    // MARK: - Limites de sécurité
    public static let maxZoom: Double = 18.0
    public static let minZoom: Double = 8.0
    public static let validCanadianBounds = CoordinateBounds(
        southWest: CLLocationCoordinate2D(latitude: 43.0, longitude: -78.0),
        northEast: CLLocationCoordinate2D(latitude: 48.0, longitude: -73.0)
    )
    
    // MARK: - Couleurs thème canadien
    public struct Colors {
        public static let pickupRed = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0) // Rouge Canada
        public static let destinationGreen = UIColor(red: 0.0, green: 0.6, blue: 0.0, alpha: 1.0)
        public static let routeBlue = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.8)
        public static let backgroundWhite = UIColor.white
        public static let borderGray = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)
    }
    
    // MARK: - Configuration des annotations
    public struct Annotations {
        public static let pickupSize: CGFloat = 20.0
        public static let destinationSize: CGFloat = 20.0
        public static let borderWidth: CGFloat = 3.0
    }
    
    // MARK: - Mode dégradé offline
    public struct Fallback {
        public static let isOfflineModeEnabled = true
        public static let maxOfflineRetries = 3
        public static let offlineTimeout: TimeInterval = 5.0
    }
    
    // MARK: - Validation sécurisée des coordonnées
    public static func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return CLLocationCoordinate2DIsValid(coordinate) &&
               coordinate.latitude >= validCanadianBounds.southWest.latitude &&
               coordinate.latitude <= validCanadianBounds.northEast.latitude &&
               coordinate.longitude >= validCanadianBounds.southWest.longitude &&
               coordinate.longitude <= validCanadianBounds.northEast.longitude
    }
    
    // MARK: - Sanitisation des niveaux de zoom
    public static func sanitizeZoom(_ zoom: Double) -> Double {
        return max(minZoom, min(maxZoom, zoom))
    }
}

// MARK: - Structure pour les limites de coordonnées
public struct CoordinateBounds {
    public let southWest: CLLocationCoordinate2D
    public let northEast: CLLocationCoordinate2D
    
    public init(southWest: CLLocationCoordinate2D, northEast: CLLocationCoordinate2D) {
        self.southWest = southWest
        self.northEast = northEast
    }
}
