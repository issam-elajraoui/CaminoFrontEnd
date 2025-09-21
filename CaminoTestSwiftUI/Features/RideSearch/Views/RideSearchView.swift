import SwiftUI
import Foundation
import MapKit
import Combine

// MARK: - Vue principale de recherche avec Mapbox et pickup GPS automatique
struct RideSearchView: View {
    private static let maxSuggestions = 7
    @StateObject private var viewModel = RideSearchViewModel()
    @StateObject private var locationService = LocationService()
    @Environment(\.presentationMode) var presentationMode
    
    // ✅ État pour coordonnées Mapbox
    @State private var mapboxCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 45.4215, longitude: -75.6972)
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    // ✅ Carte Mapbox (30% de l'écran)
                    mapboxSection
                        .frame(height: geometry.size.height * 0.30)
                    
                    // Formulaire de recherche (70% de l'écran)
                    searchFormSection
                        .frame(height: geometry.size.height * 0.70)
                }
                
                // Toggle langue en overlay
                VStack {
                    HStack {
                        Spacer()
                        languageToggleButtons
                            .padding(.trailing, 20)
                            .padding(.top, 10)
                    }
                    Spacer()
                }
            }
        }
        .environmentObject(locationService)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.userFriendlyErrorMessage)
        }
        .sheet(isPresented: $viewModel.showDriverResults) {
            DriverResultsView(
                drivers: viewModel.availableDrivers,
                onDriverSelected: { driver in
                    viewModel.selectDriver(driver)
                }
            )
        }
        .sheet(isPresented: $viewModel.showLocationPermission) {
            LocationPermissionView(
                onPermissionGranted: {
                    viewModel.onLocationPermissionGranted()
                },
                onCancel: {
                    viewModel.showLocationPermission = false
                }
            )
            .environmentObject(locationService)
        }
        .onAppear {
            viewModel.setLocationService(locationService)
            viewModel.onViewAppear()
            setupMapboxObserver()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            viewModel.recheckLocationPermissions()
        }
    }
    
    // ✅ NOUVEAU - Section Mapbox
    private var mapboxSection: some View {
        ZStack {
            // ✅ MapboxWrapper remplace Map SwiftUI
            MapboxWrapper(
                center: $mapboxCenter,
                annotations: $viewModel.annotations,
                route: $viewModel.currentRoute,
                showUserLocation: $viewModel.showUserLocation,
                onMapTap: { coordinate in
                    viewModel.handleMapTap(at: CGPoint(x: 0, y: 0)) // Simplified tap handling
                }
            )
            
            // Overlay bouton GPS (conservé)
            VStack {
                HStack {
                    gpsLocationButton
                    Spacer()
                }
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Bouton GPS (inchangé)
    private var gpsLocationButton: some View {
        Button(action: {
            Task {
                await viewModel.centerOnUserLocation()
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                Image(systemName: locationService.isLocationAvailable ? "location.fill" : "location.slash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(locationService.isLocationAvailable ? .red : .gray)
            }
        }
        .disabled(!locationService.isLocationAvailable)
        .scaleEffect(locationService.isLocationAvailable ? 1.0 : 0.9)
        .animation(.easeInOut(duration: 0.2), value: locationService.isLocationAvailable)
    }
    
    // MARK: - Toggle de langue (inchangé)
    private var languageToggleButtons: some View {
        HStack(spacing: 0) {
            Button(action: {
                viewModel.currentLanguage = "en"
            }) {
                Text("EN")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(viewModel.currentLanguage == "en" ? .white : .gray)
                    .frame(width: 40, height: 28)
                    .background(viewModel.currentLanguage == "en" ? Color.red : Color.clear)
            }
            Button(action: {
                viewModel.currentLanguage = "fr"
            }) {
                Text("FR")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(viewModel.currentLanguage == "fr" ? .white : .gray)
                    .frame(width: 40, height: 28)
                    .background(viewModel.currentLanguage == "fr" ? Color.red : Color.clear)
            }
        }
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(radius: 2)
    }
    
    // MARK: - Section formulaire de recherche avec pickup GPS
    private var searchFormSection: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
            
            ScrollView {
                VStack(spacing: 12) {
                    // Titre avec indicateur GPS
                    HStack {
                        Text(viewModel.translations["findRide"] ?? "Find a Ride")
                            .font(.title3)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Message GPS si désactivé
                    if !locationService.isLocationAvailable {
                        HStack {
                            Image(systemName: "location.slash")
                                .foregroundColor(.orange)
                            Text(viewModel.translations["enableGpsMessage"] ?? "Enable GPS for better location services")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Spacer()
                            Button(viewModel.translations["enableGps"] ?? "Enable") {
                                viewModel.requestLocationPermission()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 20)
                    }
                    
                    // ✅ Container pour les champs avec gestion pickup GPS
                    ZStack(alignment: .top) {
                        VStack(spacing: 8) {
                            // ✅ Champ pickup GPS automatique
                            CentralizedLocationField(
                                text: Binding(
                                    get: { viewModel.displayPickupAddress },
                                    set: { newValue in
                                        if viewModel.useCustomPickup {
                                            viewModel.onLocationTextChanged(newValue, for: .pickup)
                                        }
                                    }
                                ),
                                placeholder: viewModel.translations["pickupLocation"] ?? "Pickup Location",
                                errorMessage: viewModel.pickupError,
                                isPickup: true,
                                fieldType: .pickup,
                                activeField: $viewModel.activeField,
                                onTextChange: { newText in
                                    if viewModel.useCustomPickup {
                                        viewModel.onLocationTextChanged(newText, for: .pickup)
                                    }
                                },
                                onLocationSelected: { location in
                                    viewModel.setPickupLocation(location)
                                },
                                // ✅ Nouveaux paramètres pickup GPS
                                isGPSMode: !viewModel.useCustomPickup,
                                onLongPress: {
                                    viewModel.enableCustomPickup()
                                }
                            )
                            
                            // Champ destination (focus par défaut)
                            CentralizedLocationField(
                                text: $viewModel.destinationAddress,
                                placeholder: viewModel.translations["destination"] ?? "Destination",
                                errorMessage: viewModel.destinationError,
                                isPickup: false,
                                fieldType: .destination,
                                activeField: $viewModel.activeField,
                                onTextChange: { newText in
                                    viewModel.onLocationTextChanged(newText, for: .destination)
                                },
                                onLocationSelected: { location in
                                    viewModel.setDestinationLocation(location)
                                }
                            )
                        }
                        
                        // Suggestions centralisées avec positionnement intelligent
                        if viewModel.showSuggestions && !viewModel.suggestions.isEmpty {
                            suggestionsList
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // ✅ Indicateur mode pickup GPS
                    if !viewModel.useCustomPickup && viewModel.isPickupFromGPS {
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text(viewModel.translations["usingGpsLocation"] ?? "Using GPS location")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(viewModel.translations["tapToCustomize"] ?? "Long press to customize")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                    }
                    
                    // Options compactes sur une ligne (inchangé)
                    HStack(spacing: 16) {
                        // Passagers
                        HStack(spacing: 4) {
                            Text(viewModel.translations["passengers"] ?? "Passengers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                Button("-") {
                                    if viewModel.passengerCount > 1 {
                                        viewModel.passengerCount -= 1
                                    }
                                }
                                .frame(width: 24, height: 24)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                                .disabled(viewModel.passengerCount <= 1)
                                
                                Text("\(viewModel.passengerCount)")
                                    .font(.footnote)
                                    .fontWeight(.medium)
                                    .frame(minWidth: 16)
                                
                                Button("+") {
                                    if viewModel.passengerCount < 8 {
                                        viewModel.passengerCount += 1
                                    }
                                }
                                .frame(width: 24, height: 24)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                                .disabled(viewModel.passengerCount >= 8)
                            }
                        }
                        
                        Spacer()
                        
                        // Type de service compact
                        Picker("", selection: $viewModel.serviceType) {
                            Text(viewModel.translations["economy"] ?? "Eco").tag("economy")
                            Text(viewModel.translations["standard"] ?? "Std").tag("standard")
                            Text(viewModel.translations["premium"] ?? "Prem").tag("premium")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(maxWidth: 160)
                    }
                    .padding(.horizontal, 20)
                    
                    // Bouton de recherche (inchangé)
                    Button(action: {
                        Task {
                            await viewModel.searchDrivers()
                        }
                    }) {
                        HStack {
                            if viewModel.isSearching {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(viewModel.isSearching ?
                                 (viewModel.translations["searching"] ?? "Searching...") :
                                    (viewModel.translations["findDrivers"] ?? "Find Drivers"))
                            .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(viewModel.canSearch ? Color.red : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(viewModel.isSearching || !viewModel.canSearch)
                    .padding(.horizontal, 20)
                    
                    // Estimation si disponible (inchangé)
                    if viewModel.showEstimate {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.translations["estimatedFare"] ?? "Est. Fare")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(viewModel.estimatedFare)
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(viewModel.translations["distance"] ?? "Distance")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(viewModel.estimatedDistance)
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(10)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
    }
    
    // MARK: - Liste de suggestions centralisée (inchangée)
    private var suggestionsList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.suggestions.prefix(Self.maxSuggestions), id: \.id) { suggestion in
                Button(action: {
                    viewModel.selectSuggestion(suggestion)
                }) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        
                        Text(suggestion.displayText)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                
                if suggestion.id != viewModel.suggestions.prefix(Self.maxSuggestions).last?.id {
                    Divider()
                }
            }
        }
        .background(Color.white)
        .cornerRadius(6)
        .shadow(radius: 4)
        .padding(.top, viewModel.activeField == .pickup ? 44 : 96)
        .padding(.leading, 18)
        .zIndex(1000)
    }
    
    // ✅ NOUVEAU - Observer changements position pour Mapbox
    private func setupMapboxObserver() {
        // Observer les changements d'annotations pour mettre à jour la carte Mapbox
        viewModel.$annotations
            .receive(on: DispatchQueue.main)
            .sink { [self] annotations in
                updateMapboxCenter(for: annotations)
            }
            .store(in: &cancellables)
        
        // Observer la position utilisateur
        locationService.$currentLocation
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [self] location in
                mapboxCenter = location
            }
            .store(in: &cancellables)
    }
    
    private func updateMapboxCenter(for annotations: [LocationAnnotation]) {
        guard !annotations.isEmpty else { return }
        
        if annotations.count == 1 {
            mapboxCenter = annotations[0].coordinate
        } else if annotations.count >= 2 {
            // Calculer le centre entre pickup et destination
            let pickup = annotations.first { $0.type == .pickup }?.coordinate
            let destination = annotations.first { $0.type == .destination }?.coordinate
            
            if let pickup = pickup, let destination = destination {
                mapboxCenter = CLLocationCoordinate2D(
                    latitude: (pickup.latitude + destination.latitude) / 2,
                    longitude: (pickup.longitude + destination.longitude) / 2
                )
            }
        }
    }
}
