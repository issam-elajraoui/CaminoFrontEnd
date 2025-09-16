//
//  RideTrackingView.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-14.
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Ride Tracking View
struct RideTrackingView: View {
    @StateObject private var viewModel = RideTrackingViewModel()
    @Environment(\.presentationMode) var presentationMode
    let rideId: Int64
    
    var body: some View {
        ZStack {
            // Map with route
            TrackingMapView(
                pickupLocation: viewModel.pickupLocation,
                destinationLocation: viewModel.destinationLocation,
                driverLocation: viewModel.driverLocation,
                routePolyline: viewModel.routePolyline
            )
            .ignoresSafeArea()
            
            VStack {
                // Header
                headerSection
                
                Spacer()
                
                // Ride info card
                rideInfoCard
            }
            .padding(.horizontal, 16)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert(viewModel.translations["tripCompleted"] ?? "Trip completed", isPresented: $viewModel.showTripCompleted) {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text(viewModel.translations["thankYou"] ?? "Thank you for choosing Camino!")
        }
        .onAppear {
            Task {
                await viewModel.loadRideDetails(rideId: rideId)
                viewModel.startLocationTracking()
            }
        }
        .onDisappear {
            viewModel.stopLocationTracking()
        }
    }
    
    private var headerSection: some View {
        HStack {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "arrow.left")
                        .foregroundColor(.white)
                        .font(.title3)
                }
            }
            
            Spacer()
        }
        .padding(.top, 50)
    }
    
    private var rideInfoCard: some View {
        VStack(spacing: 0) {
            // Trip timeline
            VStack(spacing: 16) {
                // Pickup location
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "train.side.front.car")
                            .foregroundColor(.white)
                            .font(.title3)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.pickupAddress)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let departureTime = viewModel.departureTime {
                            Text("\(viewModel.translations["departureTime"] ?? "Departure time") \(departureTime)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                // Timeline connector
                HStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2, height: 24)
                        .offset(x: 19)
                    Spacer()
                }
                
                // Destination location
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "house.fill")
                            .foregroundColor(.white)
                            .font(.title3)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.destinationAddress)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let arrivalTime = viewModel.arrivalTime {
                            Text("\(viewModel.translations["arrivalTime"] ?? "Arrival time") \(arrivalTime)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Driver info (if assigned)
            if let driver = viewModel.driver {
                driverInfoSection(driver: driver)
                
                Divider()
                    .padding(.horizontal, 24)
            }
            
            // Action buttons
            actionButtonsSection
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -4)
        )
        .padding(.bottom, 32)
    }
    
    private func driverInfoSection(driver: RideDriver) -> some View {
        HStack(spacing: 16) {
            // Driver avatar placeholder
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(driver.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    
                    Text(String(format: "%.1f", driver.rating))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("\(driver.vehicleModel) • \(driver.licensePlate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Button(action: {
                    // TODO: Call driver
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "phone.fill")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                }
                
                Button(action: {
                    // TODO: Message driver
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "message.fill")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Share ride button
            if viewModel.rideStatus == .inProgress {
                Button(action: {
                    // TODO: Share ride functionality
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text(viewModel.translations["shareRide"] ?? "Share ride")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.primary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            
            // Primary action button
            Button(action: {
                Task {
                    await viewModel.handlePrimaryAction()
                }
            }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(viewModel.primaryActionTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(viewModel.primaryActionColor)
                )
            }
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
}

// MARK: - Tracking Map View
struct TrackingMapView: UIViewRepresentable {
    let pickupLocation: CLLocation?
    let destinationLocation: CLLocation?
    let driverLocation: CLLocation?
    let routePolyline: MKPolyline?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.isUserInteractionEnabled = true
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Clear existing annotations and overlays
        uiView.removeAnnotations(uiView.annotations)
        uiView.removeOverlays(uiView.overlays)
        
        var annotations: [MKAnnotation] = []
        
        // Add pickup annotation
        if let pickup = pickupLocation {
            let pickupAnnotation = TrackingAnnotation(
                coordinate: pickup.coordinate,
                type: .pickup,
                title: "Train Station"
            )
            annotations.append(pickupAnnotation)
        }
        
        // Add destination annotation
        if let destination = destinationLocation {
            let destinationAnnotation = TrackingAnnotation(
                coordinate: destination.coordinate,
                type: .destination,
                title: "Home"
            )
            annotations.append(destinationAnnotation)
        }
        
        // Add driver annotation
        if let driver = driverLocation {
            let driverAnnotation = TrackingAnnotation(
                coordinate: driver.coordinate,
                type: .driver,
                title: "Driver"
            )
            annotations.append(driverAnnotation)
        }
        
        uiView.addAnnotations(annotations)
        
        // Add route polyline
        if let polyline = routePolyline {
            uiView.addOverlay(polyline)
        }
        
        // Fit map to show all annotations
        if !annotations.isEmpty {
            let region = MKCoordinateRegion.region(for: annotations)
            uiView.setRegion(region, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let trackingAnnotation = annotation as? TrackingAnnotation else {
                return nil
            }
            
            let identifier = "TrackingAnnotation"
            let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) ??
                MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            
            switch trackingAnnotation.annotationType {
            case .pickup:
                if let baseImage = UIImage(systemName: "train.side.front.car") {
                    let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
                    let configuredImage = baseImage.withConfiguration(config)
                    annotationView.image = configuredImage.withTintColor(.black, renderingMode: .alwaysOriginal)
                }
            case .destination:
                if let baseImage = UIImage(systemName: "house.fill") {
                    let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
                    let configuredImage = baseImage.withConfiguration(config)
                    annotationView.image = configuredImage.withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
                }
            case .driver:
                if let baseImage = UIImage(systemName: "car.fill") {
                    let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
                    let configuredImage = baseImage.withConfiguration(config)
                    annotationView.image = configuredImage.withTintColor(.black, renderingMode: .alwaysOriginal)
                }
            }
            
            annotationView.frame.size = CGSize(width: 30, height: 30)
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Models
struct RideDriver: Codable {
    let id: String
    let name: String
    let rating: Double
    let vehicleModel: String
    let licensePlate: String
    let phoneNumber: String?
}

enum RideStatus: String, Codable {
    case pending = "PENDING"
    case accepted = "ACCEPTED"
    case driverArriving = "DRIVER_ARRIVING"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
}

enum TrackingAnnotationType {
    case pickup, destination, driver
}

class TrackingAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let annotationType: TrackingAnnotationType
    let title: String?
    
    init(coordinate: CLLocationCoordinate2D, type: TrackingAnnotationType, title: String?) {
        self.coordinate = coordinate
        self.annotationType = type
        self.title = title
    }
}

// MARK: - View Model
@MainActor
class RideTrackingViewModel: ObservableObject {
    @Published var currentLanguage = "en"
    @Published var rideStatus: RideStatus = .pending
    @Published var pickupLocation: CLLocation?
    @Published var destinationLocation: CLLocation?
    @Published var driverLocation: CLLocation?
    @Published var routePolyline: MKPolyline?
    @Published var driver: RideDriver?
    @Published var pickupAddress = "Train Station, Ottawa"
    @Published var destinationAddress = "Home, Ottawa"
    @Published var departureTime: String?
    @Published var arrivalTime: String?
    @Published var isLoading = false
    @Published var showError = false
    @Published var showTripCompleted = false
    @Published var errorMessage = ""
    
    private var locationUpdateTimer: Timer?
    
    var translations: [String: String] {
        if currentLanguage == "fr" {
            return [
                "departureTime": "Heure de départ",
                "arrivalTime": "Heure d'arrivée",
                "shareRide": "Partager la course",
                "cancelTrip": "Annuler la course",
                "finishTrip": "Terminer la course",
                "tripCompleted": "Course terminée",
                "thankYou": "Merci d'avoir choisi Camino!",
                "cancelling": "Annulation...",
                "completing": "Finalisation...",
                "error": "Erreur",
                "networkError": "Erreur de connexion"
            ]
        } else {
            return [
                "departureTime": "Departure time",
                "arrivalTime": "Arrival time",
                "shareRide": "Share ride",
                "cancelTrip": "Cancel trip",
                "finishTrip": "Finish trip",
                "tripCompleted": "Trip completed",
                "thankYou": "Thank you for choosing Camino!",
                "cancelling": "Cancelling...",
                "completing": "Completing...",
                "error": "Error",
                "networkError": "Network error"
            ]
        }
    }
    
    var primaryActionTitle: String {
        if isLoading {
            switch rideStatus {
            case .pending, .accepted, .driverArriving:
                return translations["cancelling"] ?? "Cancelling..."
            case .inProgress:
                return translations["completing"] ?? "Completing..."
            default:
                return ""
            }
        } else {
            switch rideStatus {
            case .pending, .accepted, .driverArriving:
                return translations["cancelTrip"] ?? "Cancel trip"
            case .inProgress:
                return translations["finishTrip"] ?? "Finish trip"
            default:
                return ""
            }
        }
    }
    
    var primaryActionColor: Color {
        switch rideStatus {
        case .pending, .accepted, .driverArriving:
            return .red
        case .inProgress:
            return .black
        default:
            return .gray
        }
    }
    
    func loadRideDetails(rideId: Int64) async {
        do {
            // Mock Ottawa locations for demo
            pickupLocation = CLLocation(latitude: 45.4215, longitude: -75.6972) // Ottawa Train Station
            destinationLocation = CLLocation(latitude: 45.3876, longitude: -75.6960) // Residential area
            
            // Set mock times
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            
            let now = Date()
            departureTime = formatter.string(from: now)
            arrivalTime = formatter.string(from: now.addingTimeInterval(540)) // 9 minutes
            
            // Create mock route
            createMockRoute()
            
            // Mock driver
            driver = RideDriver(
                id: "driver123",
                name: "Jean Dupuis",
                rating: 4.8,
                vehicleModel: "Honda Civic",
                licensePlate: "ABC 123",
                phoneNumber: "+1 613-555-0123"
            )
            
            rideStatus = .inProgress
            
        } catch {
            errorMessage = translations["networkError"] ?? "Network error"
            showError = true
        }
    }
    
    func startLocationTracking() {
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task {
                await self.updateDriverLocation()
            }
        }
    }
    
    func stopLocationTracking() {
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
    
    func handlePrimaryAction() async {
        isLoading = true
        defer { isLoading = false }
        
        switch rideStatus {
        case .pending, .accepted, .driverArriving:
            await cancelRide()
        case .inProgress:
            await completeRide()
        default:
            break
        }
    }
    
    private func createMockRoute() {
        guard let pickup = pickupLocation,
              let destination = destinationLocation else { return }
        
        // Create a simple route between pickup and destination
        let coordinates = [
            pickup.coordinate,
            CLLocationCoordinate2D(latitude: 45.4100, longitude: -75.6950),
            CLLocationCoordinate2D(latitude: 45.4000, longitude: -75.6955),
            destination.coordinate
        ]
        
        routePolyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        
        // Set initial driver location
        driverLocation = CLLocation(latitude: 45.4180, longitude: -75.6965)
    }
    
    private func updateDriverLocation() async {
        guard let currentDriver = driverLocation else { return }
        
        // Simulate driver movement towards destination
        let deltaLat = (destinationLocation!.coordinate.latitude - currentDriver.coordinate.latitude) * 0.1
        let deltaLng = (destinationLocation!.coordinate.longitude - currentDriver.coordinate.longitude) * 0.1
        
        let newCoordinate = CLLocationCoordinate2D(
            latitude: currentDriver.coordinate.latitude + deltaLat,
            longitude: currentDriver.coordinate.longitude + deltaLng
        )
        
        driverLocation = CLLocation(latitude: newCoordinate.latitude, longitude: newCoordinate.longitude)
    }
    
    private func cancelRide() async {
        // Simulate API call
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Mock cancellation
        rideStatus = .cancelled
        stopLocationTracking()
    }
    
    private func completeRide() async {
        // Simulate API call
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        rideStatus = .completed
        stopLocationTracking()
        showTripCompleted = true
    }
}

// MARK: - Map Extensions
extension MKCoordinateRegion {
    static func region(for annotations: [MKAnnotation]) -> MKCoordinateRegion {
        guard !annotations.isEmpty else {
            return MKCoordinateRegion()
        }
        
        let coordinates = annotations.map { $0.coordinate }
        let minLat = coordinates.min { $0.latitude < $1.latitude }!.latitude
        let maxLat = coordinates.max { $0.latitude < $1.latitude }!.latitude
        let minLng = coordinates.min { $0.longitude < $1.longitude }!.longitude
        let maxLng = coordinates.max { $0.longitude < $1.longitude }!.longitude
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3,
            longitudeDelta: (maxLng - minLng) * 1.3
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
}

struct RideTrackingView_Previews: PreviewProvider {
    static var previews: some View {
        RideTrackingView(rideId: 123)
    }
}
