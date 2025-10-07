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
    @Binding var driverAnnotations: [DriverAnnotation]
    @Binding var route: RouteResult?
    @Binding var showUserLocation: Bool
    
    @Binding var isPinpointMode: Bool

    
    // MARK: - Propriétés de callback
    let onMapTap: (CLLocationCoordinate2D) -> Void
    let onAnnotationTap: (LocationAnnotation) -> Void
    let onPinpointMove: (CLLocationCoordinate2D) -> Void

    
    // MARK: - État interne
    @State private var isMapboxAvailable = false
//    @State private var mapView: MapView?

    
    // MARK: - Initialisation
    init(
        center: Binding<CLLocationCoordinate2D>,
        annotations: Binding<[LocationAnnotation]>,
        driverAnnotations: Binding<[DriverAnnotation]>,
        route: Binding<RouteResult?>,
        showUserLocation: Binding<Bool>,
        isPinpointMode: Binding<Bool>,
        onMapTap: @escaping (CLLocationCoordinate2D) -> Void = { _ in },
        onPinpointMove: @escaping (CLLocationCoordinate2D) -> Void = { _ in },  // NOUVEAU
        onAnnotationTap: @escaping (LocationAnnotation) -> Void = { _ in }
    ) {
        self._center = center
        self._annotations = annotations
        self._driverAnnotations = driverAnnotations
        self._route = route
        self._showUserLocation = showUserLocation
        self._isPinpointMode = isPinpointMode
        self.onMapTap = onMapTap
        self.onPinpointMove = onPinpointMove  // NOUVEAU
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
    private func createMapboxView(context: Context) -> MapView {
        let validCenter = MapboxConfig.isValidCoordinate(center) ? center : MapboxConfig.fallbackRegion
        
        let mapInitOptions = MapInitOptions(
            cameraOptions: CameraOptions(
                center: validCenter,
                zoom: MapboxConfig.sanitizeZoom(MapboxConfig.defaultZoom)
            ),
            styleURI: StyleURI(rawValue: MapboxConfig.styleURL)
        )
        
        let mapView = MapView(frame: .zero, mapInitOptions: mapInitOptions)
        
        setupCanadianTheme(mapView)
        
        // SIMPLE - Pas d'auto-sync, seulement réaction aux gestures
        print("🟦 MapboxWrapper: Created map, isPinpointMode = \(isPinpointMode)")
        
        // ✅ Appels directs - pas d'observer
        updateAnnotations(mapView)
        updateRoute(mapView)
        updateUserLocation(mapView)
        
        // Configuration événement map loaded
//        mapView.mapboxMap.onMapLoaded.observeNext { [weak mapView] _ in
//            guard let mapView = mapView else { return }
//            
//            // ✅ Pas de modification d'état - seulement appels de fonction
//            Task { @MainActor in
//                // Plus de délai pour être sûr
//                try? await Task.sleep(for: .milliseconds(200))
//                
//                // ❌ SUPPRIMER : self.mapView = mapView
//                
//                // ✅ Appels directs sans modification d'état
//                self.updateAnnotations(mapView)
//                self.updateRoute(mapView)
//                self.updateUserLocation(mapView)
//                print("🟦 MapboxWrapper: Map loaded")
//            }
//        }.store(in: &cancellables)
        

        // Gesture pour détecter les mouvements en mode pinpoint
//        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapPan(_:)))
//        panGesture.delegate = context.coordinator
//        mapView.addGestureRecognizer(panGesture)
        
        // Tap gesture existant
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(tapGesture)
        
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapPan(_:)))
        panGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(panGesture)
        
        
        return mapView
    }
    
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
    
    @State private var isUpdatingCenter: Bool = false

    // MARK: - Mise à jour Mapbox corrigée
    private func updateMapboxView(_ mapView: MapView, context: Context) {
        print("🔴 updateMapboxView called - center: \(center)")
        print("🔴 isPinpointMode: \(isPinpointMode)")
        
        // ✅ TOUJOURS mettre à jour les annotations (drivers, pickup, destination)
        updateAnnotations(mapView)
        updateRoute(mapView)
        updateUserLocation(mapView)
        
        // ✅ Bloquer SEULEMENT le mouvement de caméra en mode pinpoint
        guard !isPinpointMode else {
            print("🔴 SKIPPING camera update - pinpoint mode active")
            return
        }
        
        // Reste du code pour le mouvement de caméra
        guard !isUpdatingCenter else { return }
        
        let validCenter = MapboxConfig.isValidCoordinate(center) ? center : MapboxConfig.fallbackRegion
        
        let currentCenter = mapView.mapboxMap.cameraState.center
        let distanceThreshold = 0.001
        let latDiff = abs(validCenter.latitude - currentCenter.latitude)
        let lonDiff = abs(validCenter.longitude - currentCenter.longitude)
        
        guard latDiff > distanceThreshold || lonDiff > distanceThreshold else {
            return
        }
        
        let cameraOptions = CameraOptions(
            center: validCenter,
            zoom: MapboxConfig.sanitizeZoom(MapboxConfig.defaultZoom)
        )
        
        mapView.camera.ease(
            to: cameraOptions,
            duration: 0.2
        )
    }
    
    private func setupCanadianTheme(_ mapView: MapView) {
        mapView.ornaments.attributionButton.isHidden = true
        mapView.ornaments.logoView.isHidden = true
        mapView.backgroundColor = UIColor.white
    }

    private var annotationManagerId = "main-annotation-manager"

    // MARK: - CORRECTION: Gestion des annotations simplifiée
    private func updateAnnotations(_ mapView: MapView) {
        print("🟢 updateAnnotations called")
        
        // Charger l'icône PNG custom
        addCustomCarIcon(mapView)
       // addCustomMarkerIcon(mapView)
        
        
        
        
        
        let pointAnnotationManager: PointAnnotationManager
        
        //let pointAnnotationManager = mapView.annotations.makePointAnnotationManager()
        
        
        
        
        if let existingManager = mapView.annotations.annotationManagersById[annotationManagerId] as? PointAnnotationManager {
                pointAnnotationManager = existingManager
            } else {
                pointAnnotationManager = mapView.annotations.makePointAnnotationManager(id: annotationManagerId)
            }
        
        pointAnnotationManager.annotations = []
        var allPointAnnotations: [PointAnnotation] = []
        
        // 2. Drivers avec PNG custom
        for driverAnnotation in driverAnnotations {
            guard MapboxConfig.isValidCoordinate(driverAnnotation.coordinate) else { continue }
            
            var pointAnnotation = PointAnnotation(coordinate: driverAnnotation.coordinate)
            pointAnnotation.iconImage = "custom-car-icon"  // Référence au PNG
            
            let color: UIColor
            switch driverAnnotation.status {
            case .available:
                color = .systemGreen
            case .enRoute:
                color = .systemOrange
            case .busy:
                color = .systemGray
            }
            
            pointAnnotation.iconColor = StyleColor(color)
            pointAnnotation.iconSize = 1.5
            pointAnnotation.iconRotate = driverAnnotation.bearing  // Rotation fonctionne
            
            allPointAnnotations.append(pointAnnotation)
        }
        
        pointAnnotationManager.annotations = allPointAnnotations
        print("🟢 Applied \(allPointAnnotations.count) annotations with custom PNG")
    }
    // MARK: - Charger icône PNG custom depuis Assets
    private func addCustomCarIcon(_ mapView: MapView) {
        // Éviter de recharger si déjà présente
        guard mapView.mapboxMap.image(withId: "custom-car-icon") == nil else { return }
        
        // Charger depuis Assets
        guard let carImage = UIImage(named: "car-icon") else {
            print("❌ car-icon PNG not found in Assets")
            return
        }
        
        // Ajouter au style Mapbox
        try? mapView.mapboxMap.addImage(carImage, id: "custom-car-icon")
        print("✅ Custom car PNG loaded")
    }

//    private func addCustomMarkerIcon(_ mapView: MapView) {
//        guard mapView.mapboxMap.image(withId: "custom-marker-icon") == nil else { return }
//        
//        // Option 1: Utiliser un autre PNG si vous en avez un
//        // guard let markerImage = UIImage(named: "marker-icon") else { return }
//        
//        // Option 2: Créer un cercle simple programmatiquement
//        let size = CGSize(width: 30, height: 30)
//        let renderer = UIGraphicsImageRenderer(size: size)
//        
//        let markerImage = renderer.image { context in
//            let circle = UIBezierPath(ovalIn: CGRect(x: 3, y: 3, width: 24, height: 24))
//            UIColor.white.setFill()
//            circle.fill()
//            UIColor.black.setStroke()
//            circle.lineWidth = 2
//            circle.stroke()
//        }
//        
//        try? mapView.mapboxMap.addImage(markerImage, id: "custom-marker-icon")
//        print("✅ Custom marker created")
//    }
    
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
            MapboxConfig.isValidCoordinate($0)
        }
        
        guard validCoordinates.count >= 2 else {
            print("Route invalide - pas assez de coordonnées valides")
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
            print("Erreur ajout route: \(error.localizedDescription)")
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

// MARK: - Coordinator ultra-simplifié
extension MapboxWrapper {
    public class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: MapboxWrapper
        
        init(_ parent: MapboxWrapper) {
            self.parent = parent
        }
        

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MapView else { return }
            
            // Toujours utiliser position exacte du tap
            let point = gesture.location(in: mapView)
            let coordinate = mapView.mapboxMap.coordinate(for: point)
            
            guard MapboxConfig.isValidCoordinate(coordinate) else { return }
            parent.onMapTap(coordinate)
        }
        
        @objc func handleMapPan(_ gesture: UIPanGestureRecognizer) {
            guard parent.isPinpointMode else { return }
            guard gesture.state == .ended else { return }
            
            guard let mapView = gesture.view as? MapView else { return }
            
            // Délai pour stabilisation + découplage SwiftUI 6
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let currentCenter = mapView.mapboxMap.cameraState.center
                
                guard MapboxConfig.isValidCoordinate(currentCenter) else { return }
                
                print(" Pan ended - center: \(currentCenter)")
                self.parent.onPinpointMove(currentCenter)
            }
        }
        

        
        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true  // ✅ COOPÉRATION avec Mapbox
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
