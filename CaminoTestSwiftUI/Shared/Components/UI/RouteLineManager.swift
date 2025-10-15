//
//  Untitled.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-10-13.
//

import Foundation
import CoreLocation

#if canImport(MapboxMaps)
import MapboxMaps

// MARK: - Gestionnaire de ligne de trajet avec animation progressive
@MainActor
public class RouteLineManager {
    
    // MARK: - Configuration Style Premium
    private struct Style {
        static let lineColor = "#2C3E50"  // Gris foncé premium
        static let lineWidth: Double = 5.5
        static let animationDuration: TimeInterval = 1.5
        static let sourceId = "animated-route-source"
        static let layerId = "animated-route-layer"
    }
    
    // MARK: - Private Properties
    private weak var mapView: MapView?
    private var animationTask: Task<Void, Never>?
    
    // MARK: - Initialisation
    public init(mapView: MapView) {
        self.mapView = mapView
    }
    
    // MARK: - Public Methods
    
    /// Dessine une route avec animation progressive
    public func drawAnimatedRoute(coordinates: [CLLocationCoordinate2D]) {
        // Annuler animation précédente
        animationTask?.cancel()
        
        // Nettoyer route existante
        removeRoute()
        
        // Valider coordonnées
        let validCoordinates = coordinates.filter { MapboxConfig.isValidCoordinate($0) }
        guard validCoordinates.count >= 2 else {
            print("⚠️ RouteLineManager: Pas assez de coordonnées valides")
            return
        }
        
        // Lancer animation
        animationTask = Task { @MainActor in
            await animateRouteDraw(coordinates: validCoordinates)
        }
    }
    
    /// Supprime la route affichée
    public func removeRoute() {
        guard let mapView = mapView else { return }
        
        animationTask?.cancel()
        
        do {
            try mapView.mapboxMap.removeLayer(withId: Style.layerId)
        } catch {}
        
        do {
            try mapView.mapboxMap.removeSource(withId: Style.sourceId)
        } catch {}
    }
    
    // MARK: - Private Animation Logic
    
    private func animateRouteDraw(coordinates: [CLLocationCoordinate2D]) async {
        guard let mapView = mapView else { return }
        
        let totalSegments = coordinates.count - 1
        let timePerSegment = Style.animationDuration / Double(totalSegments)
        
        // Créer source vide
        var geoJSONSource = GeoJSONSource(id: Style.sourceId)
        geoJSONSource.data = .geometry(.lineString(LineString([])))
        
        // Créer layer avec style premium
        var lineLayer = LineLayer(id: Style.layerId, source: Style.sourceId)
        lineLayer.lineColor = .constant(StyleColor(rawValue: Style.lineColor))
        lineLayer.lineWidth = .constant(Style.lineWidth)
        lineLayer.lineCap = .constant(.round)
        lineLayer.lineJoin = .constant(.round)
        
        // Ajouter source et layer
        do {
            try mapView.mapboxMap.addSource(geoJSONSource)
            try mapView.mapboxMap.addLayer(lineLayer)
        } catch {
            print("❌ RouteLineManager: Erreur création layer - \(error)")
            return
        }
        
        // Animation segment par segment
        for i in 1..<coordinates.count {
            guard !Task.isCancelled else { return }
            
            let partialCoordinates = Array(coordinates[0...i])
            let lineString = LineString(partialCoordinates)
            
            // Mettre à jour la source
            var updatedSource = GeoJSONSource(id: Style.sourceId)
            updatedSource.data = .geometry(.lineString(lineString))
            
            do {
                mapView.mapboxMap.updateGeoJSONSource(withId: Style.sourceId, geoJSON: .geometry(.lineString(lineString)))
            }
            
            // Attendre avant segment suivant
            try? await Task.sleep(for: .seconds(timePerSegment))
        }
        
        print(" RouteLineManager: Animation complète")
    }
    
    // MARK: - Cleanup
    deinit {
        animationTask?.cancel()
    }
}

#else
// Fallback si Mapbox non disponible
@MainActor
public class RouteLineManager {
    public init(mapView: Any) {}
    public func drawAnimatedRoute(coordinates: [CLLocationCoordinate2D]) {}
    public func removeRoute() {}
}
#endif
