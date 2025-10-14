//
//  MapboxWrapper.swift - AVEC RouteLineManager
//  CaminoTestSwiftUI
//

import SwiftUI
import UIKit
import CoreLocation
import MapKit
import Combine

#if canImport(MapboxMaps)
import MapboxMaps

// MARK: - Wrapper SwiftUI pour Mapbox avec RouteLineManager
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
    
    // MARK: - Initialisation
    init(
        center: Binding<CLLocationCoordinate2D>,
        annotations: Binding<[LocationAnnotation]>,
        driverAnnotations: Binding<[DriverAnnotation]>,
        route: Binding<RouteResult?>,
        showUserLocation: Binding<Bool>,
        isPinpointMode: Binding<Bool>,
        onMapTap: @escaping (CLLocationCoordinate2D) -> Void = { _ in },
        onPinpointMove: @escaping (CLLocationCoordinate2D) -> Void = { _ in },
        onAnnotationTap: @escaping (LocationAnnotation) -> Void = { _ in }
    ) {
        self._center = center
        self._annotations = annotations
        self._driverAnnotations = driverAnnotations
        self._route = route
        self._showUserLocation = showUserLocation
        self._isPinpointMode = isPinpointMode
        self.onMapTap = onMapTap
        self.onPinpointMove = onPinpointMove
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
    
    // MARK: - Création Mapbox
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
        
        print("🟦 MapboxWrapper: Created map, isPinpointMode = \(isPinpointMode)")
        
        // ✅ Initialiser d'abord les annotations et user location
        updateAnnotations(mapView)
        updateUserLocation(mapView)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(tapGesture)
        
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapPan(_:)))
        panGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(panGesture)
        
        // ✅ NOUVEAU : Initialiser le RouteLineManager dans le Coordinator
        context.coordinator.routeLineManager = RouteLineManager(mapView: mapView)
        print("✅ MapboxWrapper: RouteLineManager initialisé")
        
        // ✅ Maintenant qu'on a le manager, on peut afficher la route si elle existe
        updateRoute(mapView, coordinator: context.coordinator)
        
        return mapView
    }
    
    // MARK: - Mode dégradé
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
        
        DispatchQueue.main.async {
            self.isMapboxAvailable = false
        }
        return fallbackView
    }
    
    @State private var isUpdatingCenter: Bool = false

    // MARK: - Mise à jour Mapbox
    private func updateMapboxView(_ mapView: MapView, context: Context) {
        print("🔴 updateMapboxView called - center: \(center)")
        print("🔴 isPinpointMode: \(isPinpointMode)")
        
        updateAnnotations(mapView)
        updateRoute(mapView, coordinator: context.coordinator)
        updateUserLocation(mapView)
        
        guard !isPinpointMode else {
            print("🔴 SKIPPING camera update - pinpoint mode active")
            return
        }
        
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

    // MARK: - Gestion des annotations
    private func updateAnnotations(_ mapView: MapView) {
        print("🟢 updateAnnotations called")
        
        addCustomCarIcon(mapView)
        
        let pointAnnotationManager: PointAnnotationManager
        
        if let existingManager = mapView.annotations.annotationManagersById[annotationManagerId] as? PointAnnotationManager {
            pointAnnotationManager = existingManager
        } else {
            pointAnnotationManager = mapView.annotations.makePointAnnotationManager(id: annotationManagerId)
        }
        
        pointAnnotationManager.annotations = []
        var allPointAnnotations: [PointAnnotation] = []
        
        for driverAnnotation in driverAnnotations {
            guard MapboxConfig.isValidCoordinate(driverAnnotation.coordinate) else { continue }
            
            var pointAnnotation = PointAnnotation(coordinate: driverAnnotation.coordinate)
            pointAnnotation.iconImage = "custom-car-icon"
            
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
            pointAnnotation.iconRotate = driverAnnotation.bearing
            
            allPointAnnotations.append(pointAnnotation)
        }
        
        pointAnnotationManager.annotations = allPointAnnotations
        print("🟢 Applied \(allPointAnnotations.count) annotations with custom PNG")
    }
    
    private func addCustomCarIcon(_ mapView: MapView) {
        guard mapView.mapboxMap.image(withId: "custom-car-icon") == nil else { return }
        
        guard let carImage = UIImage(named: "car-icon") else {
            print("❌ car-icon PNG not found in Assets")
            return
        }
        
        try? mapView.mapboxMap.addImage(carImage, id: "custom-car-icon")
        print("✅ Custom car PNG loaded")
    }
    
    // MARK: - ✅ NOUVEAU : Route avec animation progressive
    private func updateRoute(_ mapView: MapView, coordinator: Coordinator) {
        print("🟡 updateRoute called, route exists: \(route != nil)")
        
        guard let route = route else {
            print("🟡 No route - removing existing route")
            coordinator.routeLineManager?.removeRoute()
            return
        }
        
        let coordinates = route.polyline.coordinates
        let validCoordinates = coordinates.filter {
            MapboxConfig.isValidCoordinate($0)
        }
        
        print("🟡 Route has \(coordinates.count) coordinates, \(validCoordinates.count) valid")
        
        guard validCoordinates.count >= 2 else {
            print("⚠️ Route invalide - pas assez de coordonnées")
            return
        }
        
        guard let manager = coordinator.routeLineManager else {
            print("❌ RouteLineManager is nil!")
            return
        }
        
        print("🟢 Calling drawAnimatedRoute with \(validCoordinates.count) coordinates")
        manager.drawAnimatedRoute(coordinates: validCoordinates)
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

// MARK: - Coordinator
extension MapboxWrapper {
    public class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: MapboxWrapper
        var routeLineManager: RouteLineManager?
        
        init(_ parent: MapboxWrapper) {
            self.parent = parent
        }
        
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MapView else { return }
            
            let point = gesture.location(in: mapView)
            let coordinate = mapView.mapboxMap.coordinate(for: point)
            
            guard MapboxConfig.isValidCoordinate(coordinate) else { return }
            parent.onMapTap(coordinate)
        }
        
        @objc func handleMapPan(_ gesture: UIPanGestureRecognizer) {
            guard parent.isPinpointMode else { return }
            guard gesture.state == .ended else { return }
            
            guard let mapView = gesture.view as? MapView else { return }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let currentCenter = mapView.mapboxMap.cameraState.center
                
                guard MapboxConfig.isValidCoordinate(currentCenter) else { return }
                
                print(" Pan ended - center: \(currentCenter)")
                self.parent.onPinpointMove(currentCenter)
            }
        }
        
        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}

// MARK: - Extension MKPolyline
private extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

#else
// MARK: - Fallback si Mapbox non disponible
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
