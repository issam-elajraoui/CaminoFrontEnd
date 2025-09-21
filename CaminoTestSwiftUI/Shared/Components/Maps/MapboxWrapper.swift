//
//  MapboxWrapper.swift - CORRECTIONS FINALES
//  CaminoTestSwiftUI
//

import SwiftUI
import UIKit
import CoreLocation
import MapKit
import Combine

#if canImport(MapboxMaps)
import MapboxMaps

// MARK: - Wrapper SwiftUI pour Mapbox avec corrections finales
public struct MapboxWrapper: UIViewRepresentable {
    
    // MARK: - Propriétés bindées
    @Binding var center: CLLocationCoordinate2D
    @Binding var annotations: [LocationAnnotation]
    @Binding var route: RouteResult?
    @Binding var showUserLocation: Bool
    
    // MARK: - Propriétés de callback
    let onMapTap: (CLLocationCoordinate2D) -> Void
    let onAnnotationTap: (LocationAnnotation) -> Void
    
    // MARK: - État interne
    @State private var isMapboxAvailable = false
    @State private var mapView: MapView?
    
    // MARK: - Initialisation
    init(
        center: Binding<CLLocationCoordinate2D>,
        annotations: Binding<[LocationAnnotation]>,
        route: Binding<RouteResult?>,
        showUserLocation: Binding<Bool>,
        onMapTap: @escaping (CLLocationCoordinate2D) -> Void = { _ in },
        onAnnotationTap: @escaping (LocationAnnotation) -> Void = { _ in }
    ) {
        self._center = center
        self._annotations = annotations
        self._route = route
        self._showUserLocation = showUserLocation
        self.onMapTap = onMapTap
        self.onAnnotationTap = onAnnotationTap
    }
    
    // MARK: - UIViewRepresentable
    public func makeUIView(context: Context) -> UIView {
        guard isMapboxSupported() else {
            return createFallbackView()
        }
        
        return createMapboxView(context: context)
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        guard let mapView = uiView as? MapView else { return }
        updateMapboxView(mapView, context: context)
    }
    
    // MARK: - Création Mapbox corrigée
    // MARK: - Création Mapbox corrigée
        private func createMapboxView(context: Context) -> MapView {
            let validCenter = MapboxConfig.isValidCanadianCoordinate(center) ? center : MapboxConfig.fallbackRegion
            
            let mapInitOptions = MapInitOptions(
                cameraOptions: CameraOptions(
                    center: validCenter,
                    zoom: MapboxConfig.sanitizeZoom(MapboxConfig.defaultZoom)
                ),
                styleURI: StyleURI(rawValue: MapboxConfig.styleURL)
            )
            
            let mapView = MapView(frame: .zero, mapInitOptions: mapInitOptions)
            
            setupCanadianTheme(mapView)
            
            // ✅ CORRECTION: Observer les changements de caméra pour mettre à jour le binding center
            mapView.mapboxMap.onCameraChanged.observeNext { [weak mapView] _ in
                guard let mapView = mapView else { return }
                
                // Obtenir le centre actuel de la caméra
                let currentCenter = mapView.cameraState.center
                
                // ✅ CORRECTION: Mettre à jour le binding center sur le main thread
                DispatchQueue.main.async {
                    // Éviter les boucles infinies en vérifiant si le centre a vraiment changé
                    let distanceThreshold = 0.0001 // Environ 10 mètres
                    let latDiff = abs(currentCenter.latitude - self.center.latitude)
                    let lonDiff = abs(currentCenter.longitude - self.center.longitude)
                    
                    if latDiff > distanceThreshold || lonDiff > distanceThreshold {
                        print("🐛 DEBUG MapboxWrapper - Camera center changed to: \(currentCenter)")
                        self.center = currentCenter
                    }
                }
            }.store(in: &cancellables)
            
            // CORRECTION: Gestion événement map loaded avec DispatchQueue
            mapView.mapboxMap.onMapLoaded.observeNext { [weak mapView] _ in
                guard let mapView = mapView else { return }
                DispatchQueue.main.async {
                    // Éviter modification état pendant view update
                    Task { @MainActor in
                        self.mapView = mapView
                        self.updateAnnotations(mapView)
                        self.updateRoute(mapView)
                    }
                }
            }.store(in: &cancellables)
            
            let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
            mapView.addGestureRecognizer(tapGesture)
            
            // CORRECTION: Éviter modification état dans createMapboxView
            DispatchQueue.main.async {
                self.isMapboxAvailable = true
            }
            return mapView
        }
    @State private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Mode dégradé (inchangé)
    private func createFallbackView() -> UIView {
        let fallbackView = UIView()
        fallbackView.backgroundColor = UIColor.white
        
        let messageLabel = UILabel()
        messageLabel.text = "Carte en mode allégé"
        messageLabel.textColor = UIColor.red
        messageLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        messageLabel.textAlignment = .center
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        fallbackView.addSubview(messageLabel)
        NSLayoutConstraint.activate([
            messageLabel.centerXAnchor.constraint(equalTo: fallbackView.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: fallbackView.centerYAnchor)
        ])
        
        fallbackView.layer.borderWidth = 1
        fallbackView.layer.borderColor = UIColor.lightGray.cgColor
        fallbackView.layer.cornerRadius = 8
        
        // CORRECTION: Éviter modification état dans createFallbackView
        DispatchQueue.main.async {
            self.isMapboxAvailable = false
        }
        return fallbackView
    }
    
    // MARK: - Mise à jour Mapbox corrigée
    private func updateMapboxView(_ mapView: MapView, context: Context) {
        let validCenter = MapboxConfig.isValidCanadianCoordinate(center) ? center : MapboxConfig.fallbackRegion
        
        let cameraOptions = CameraOptions(
            center: validCenter,
            zoom: MapboxConfig.sanitizeZoom(MapboxConfig.defaultZoom)
        )
        
        mapView.camera.ease(
            to: cameraOptions,
            duration: MapboxConfig.animationDuration
        )
        
        updateAnnotations(mapView)
        updateRoute(mapView)
        updateUserLocation(mapView)
    }
    
    private func setupCanadianTheme(_ mapView: MapView) {
        mapView.ornaments.attributionButton.isHidden = true
        mapView.ornaments.logoView.isHidden = true
        mapView.backgroundColor = UIColor.white
    }
    
    // MARK: - CORRECTION: Gestion des annotations simplifiée
    private func updateAnnotations(_ mapView: MapView) {
        // CORRECTION: Utiliser pointAnnotationManager correctement
        let pointAnnotationManager = mapView.annotations.makePointAnnotationManager()
        
        // Supprimer les annotations existantes
        pointAnnotationManager.annotations = []
        
        // CORRECTION: Création annotations sans icônes custom (utiliser système)
        var pointAnnotations: [PointAnnotation] = []
        
        for annotation in annotations {
            guard MapboxConfig.isValidCanadianCoordinate(annotation.coordinate) else {
                print("⚠️ Coordonnée invalide ignorée: \(annotation.coordinate)")
                continue
            }
            
            var pointAnnotation = PointAnnotation(coordinate: annotation.coordinate)
            
            // CORRECTION: Utiliser couleur simple au lieu d'icône custom
            let color = annotation.type == .pickup ? UIColor.red : UIColor.green
            pointAnnotation.iconColor = StyleColor(color)
            pointAnnotation.iconSize = annotation.type == .pickup ?
                MapboxConfig.Annotations.pickupSize/20 :
                MapboxConfig.Annotations.destinationSize/20
            
            pointAnnotations.append(pointAnnotation)
        }
        
        pointAnnotationManager.annotations = pointAnnotations
    }
    
    // MARK: - CORRECTION: Gestion route ultra-simplifiée
    private func updateRoute(_ mapView: MapView) {
        // CORRECTION: Supprimer route existante avec API correcte
        do {
            try mapView.mapboxMap.removeLayer(withId: "route-layer")
        } catch {
            // Layer n'existe pas encore
        }
        
        do {
            try mapView.mapboxMap.removeSource(withId: "route-source")
        } catch {
            // Source n'existe pas encore
        }
        
        guard let route = route else { return }
        
        // Conversion sécurisée MKPolyline vers coordonnées
        let coordinates = route.polyline.coordinates
        let validCoordinates = coordinates.filter {
            MapboxConfig.isValidCanadianCoordinate($0)
        }
        
        guard validCoordinates.count >= 2 else {
            print("⚠️ Route invalide - pas assez de coordonnées valides")
            return
        }
        
        // CORRECTION: Création route ultra-simplifiée
        do {
            let lineString = LineString(validCoordinates)
            
            // CORRECTION: Création source GeoJSON correcte
            var geoJSONSource = GeoJSONSource(id: "route-source")
            geoJSONSource.data = .geometry(.lineString(lineString))
            
            // CORRECTION: Création layer ligne correcte
            var lineLayer = LineLayer(id: "route-layer", source: "route-source")
            lineLayer.lineColor = .constant(StyleColor(.blue))
            lineLayer.lineWidth = .constant(4.0)
            lineLayer.lineCap = .constant(.round)
            lineLayer.lineJoin = .constant(.round)
            
            // Ajout source puis layer
            try mapView.mapboxMap.addSource(geoJSONSource)
            try mapView.mapboxMap.addLayer(lineLayer)
        } catch {
            print("⚠️ Erreur ajout route: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Position utilisateur
    private func updateUserLocation(_ mapView: MapView) {
        if showUserLocation {
            mapView.location.options.puckType = .puck2D()
        } else {
            mapView.location.options.puckType = nil
        }
    }
    
    // MARK: - Vérification support Mapbox
    private func isMapboxSupported() -> Bool {
        guard MapboxConfig.Fallback.isOfflineModeEnabled else { return true }
        return Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") != nil
    }
    
    // MARK: - Coordinator
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

// MARK: - CORRECTION: Coordinator ultra-simplifié
extension MapboxWrapper {
    public class Coordinator: NSObject {
        var parent: MapboxWrapper
        
        init(_ parent: MapboxWrapper) {
            self.parent = parent
        }
        
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MapView else { return }
            
            let point = gesture.location(in: mapView)
            let coordinate = mapView.mapboxMap.coordinate(for: point)
            
            guard MapboxConfig.isValidCanadianCoordinate(coordinate) else {
                print("⚠️ Tap hors zone de service ignoré")
                return
            }
            
            parent.onMapTap(coordinate)
        }
    }
}

// MARK: - Extension MKPolyline pour coordonnées (inchangée)
private extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

#else
// MARK: - Fallback si Mapbox non disponible (inchangé)
public struct MapboxWrapper: UIViewRepresentable {
    @Binding var center: CLLocationCoordinate2D
    @Binding var annotations: [LocationAnnotation]
    @Binding var route: RouteResult?
    @Binding var showUserLocation: Bool
    
    let onMapTap: (CLLocationCoordinate2D) -> Void
    let onAnnotationTap: (LocationAnnotation) -> Void
    
    init(
        center: Binding<CLLocationCoordinate2D>,
        annotations: Binding<[LocationAnnotation]>,
        route: Binding<RouteResult?>,
        showUserLocation: Binding<Bool>,
        onMapTap: @escaping (CLLocationCoordinate2D) -> Void = { _ in },
        onAnnotationTap: @escaping (LocationAnnotation) -> Void = { _ in }
    ) {
        self._center = center
        self._annotations = annotations
        self._route = route
        self._showUserLocation = showUserLocation
        self.onMapTap = onMapTap
        self.onAnnotationTap = onAnnotationTap
    }
    
    public func makeUIView(context: Context) -> UIView {
        let fallbackView = UIView()
        fallbackView.backgroundColor = UIColor.white
        
        let messageLabel = UILabel()
        messageLabel.text = "Mapbox non disponible - Mode dégradé"
        messageLabel.textColor = UIColor.red
        messageLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        messageLabel.textAlignment = .center
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        fallbackView.addSubview(messageLabel)
        NSLayoutConstraint.activate([
            messageLabel.centerXAnchor.constraint(equalTo: fallbackView.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: fallbackView.centerYAnchor)
        ])
        
        return fallbackView
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public class Coordinator: NSObject {}
}
#endif
