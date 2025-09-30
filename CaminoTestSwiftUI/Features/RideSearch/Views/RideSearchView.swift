import SwiftUI
import Foundation
import MapKit
import Combine

// MARK: - Vue principale avec mode automatique selon position bottom sheet
struct RideSearchView: View {
    private static let maxSuggestions = 7
    //@StateObject private var viewModel = RideSearchViewModel()
    @StateObject private var viewModel = RideSearchCoordinator()
    @StateObject private var locationService = LocationService()
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var localizationManager: LocalizationManager
    
    
    // États pour coordonnées Mapbox
    @State private var mapboxCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 45.4215, longitude: -75.6972)
    
    @State private var cancellables = Set<AnyCancellable>()
    
    // États bottom sheet
    @State private var bottomSheetHeight: CGFloat = 0.7  // 70% par défaut = mode recherche
    @State private var isDraggingSheet: Bool = false
    
    // Seuils pour changement automatique de mode
    private let searchModeThreshold: CGFloat = 0.55  // Au-dessus = mode recherche
    private let pinpointModeThreshold: CGFloat = 0.55 // En-dessous = mode pinpoint
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Carte Mapbox plein écran
                mapboxFullScreenSection
                
                // Bottom Sheet draggable
                DraggableBottomSheet(
                    heightPercentage: $bottomSheetHeight,
                    isDragging: $isDraggingSheet
                ) {
                    bottomSheetContent
                }
                
                // Toggle langue en overlay
                VStack {
                    HStack {
                        Spacer()
                        languageToggleButtons
                            .padding(.trailing, 20)
                            .padding(.top, 60)
                    }
                    Spacer()
                }
                
                // Instructions pinpoint (seulement si mode pinpoint actif)
                if viewModel.pinpoint.isPinpointMode {
                    pinpointInstructions(geometry: geometry)
                }
            }
        }
        .environmentObject(locationService)
        .alert("Error", isPresented: $viewModel.driverSearch.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.driverSearch.userFriendlyErrorMessage)
        }
        .sheet(isPresented: $viewModel.driverSearch.showDriverResults) {
            DriverResultsView(
                drivers: viewModel.driverSearch.availableDrivers,
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
        
        .onDisappear {
            viewModel.pinpoint.cleanupPinpointTasks()
                }
        
        
        // NOUVEAU - Observer les changements de position du sheet
        .onChange(of: bottomSheetHeight) { oldValue, newValue in
            print("🔵 Sheet height changed: \(oldValue) → \(newValue)")
            print("🔵 pinpointModeThreshold: \(pinpointModeThreshold)")
            // Éviter updates trop fréquents
            guard abs(newValue - oldValue) > 0.05 else { return }
            
            // Debounce les changements
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                
                let now = Date()
                guard now.timeIntervalSince(lastSheetUpdate) > 0.2 else { return }
                lastSheetUpdate = now
                
                if newValue <= pinpointModeThreshold && !viewModel.pinpoint.isPinpointMode {
                    activatePinpointMode()
                } else if newValue > searchModeThreshold && viewModel.pinpoint.isPinpointMode {
                    deactivatePinpointMode()
                }
            }
        }
        
        .onChange(of: isDraggingSheet) { _, isDragging in
            if !isDragging {
                // Fin du drag, attendre stabilisation
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(200))
                    
                    let now = Date()
                    guard now.timeIntervalSince(lastSheetUpdate) > 0.2 else { return }
                    lastSheetUpdate = now
                    
                    if bottomSheetHeight <= pinpointModeThreshold && !viewModel.pinpoint.isPinpointMode {
                        activatePinpointMode()
                    } else if bottomSheetHeight > searchModeThreshold && viewModel.pinpoint.isPinpointMode {
                        deactivatePinpointMode()
                    }
                }
            }
        }
        
    }
    
    // MARK: - Gestion automatique du changement de mode
    @State private var lastSheetUpdate: Date = Date.distantPast

//    private mutating func handleSheetPositionChange(_ height: CGFloat) {
//        // Throttling des updates
//        let now = Date()
//        guard now.timeIntervalSince(lastSheetUpdate) > 0.2 else { return }
//        lastSheetUpdate = now
//        
//        if height <= pinpointModeThreshold && !viewModel.pinpoint.isPinpointMode {
//            activatePinpointMode()
//        } else if height > searchModeThreshold && viewModel.pinpoint.isPinpointMode {
//            deactivatePinpointMode()
//        }
//    }

    private func activatePinpointMode() {
        print("🟢 RideSearchView: Activating pinpoint mode")
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.enablePinpointMode(for: .destination)
        }
        print("🟢 RideSearchView: Pinpoint mode activated, isPinpointMode = \(viewModel.pinpoint.isPinpointMode)")
    }
    
    private func deactivatePinpointMode() {
        print("🔴 RideSearchView: Deactivating pinpoint mode")
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.disablePinpointMode()
        }
        print("🔴 RideSearchView: Pinpoint mode deactivated")
    }
    
    // MARK: - Carte Mapbox plein écran
    private var mapboxFullScreenSection: some View {
        ZStack {
            // Carte Mapbox avec binding pour le mode pinpoint
            MapboxWrapper(
                center: $mapboxCenter,
                annotations: $viewModel.annotations,
                route: $viewModel.route.currentRoute,
                showUserLocation: $viewModel.showUserLocation,
                isPinpointMode: $viewModel.pinpoint.isPinpointMode,
                onMapTap: { coordinate in
                    viewModel.handleMapTap(at: CGPoint(x: 0, y: 0))
                },
                onPinpointMove: { coordinate in  // NOUVEAU callback
                    viewModel.onMapCenterChangedSimple(coordinate: coordinate)
                }
            )
            
            // Reste du code identique
            PinpointIndicator(
                isActive: viewModel.pinpoint.isPinpointMode,
                isResolving: viewModel.pinpoint.isResolvingAddress
            )
            
            // Overlay bouton GPS
            VStack {
                HStack {
                    gpsLocationButton
                        .padding(.leading, 20)
                        .padding(.top, 60)
                    Spacer()
                }
                Spacer()
            }
        }
    }
    
    // MARK: - Instructions pinpoint simplifiées
    private func pinpointInstructions(geometry: GeometryProxy) -> some View {
        VStack {
            VStack(spacing: 12) {
                // Instructions simples
                HStack {
                    Spacer()
                    Text("Déplacez la carte pour choisir votre destination")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(20)
                        .shadow(radius: 4)
                    Spacer()
                }
                
                // Affichage adresse en temps réel
                if viewModel.pinpoint.isResolvingAddress || !viewModel.pinpoint.pinpointAddress.isEmpty {
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            if viewModel.pinpoint.isResolvingAddress {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                                Text("Recherche...")
                                    .font(.footnote)
                                    .foregroundColor(.white)
                            } else {
                                Text("📍")
                                    .font(.footnote)
                                Text(viewModel.pinpoint.pinpointAddress)
                                    .font(.footnote)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(15)
                        .shadow(radius: 3)
                        Spacer()
                    }
                }
            }
            .padding(.top, 120)
            
            Spacer()
        }
        .transition(.opacity)
    }


    // MARK: - Bouton GPS
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
    
    // MARK: - Toggle de langue
    private var languageToggleButtons: some View {
        LanguageToggle()
            .shadow(radius: 2)
    }
    // MARK: - Contenu bottom sheet simplifié
    private var bottomSheetContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Titre avec indicateur mode
                HStack {
                    Text("findRide".localized)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    // Indicateur discret du mode actuel
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.pinpoint.isPinpointMode ? "map.fill" : "magnifyingglass")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(viewModel.pinpoint.isPinpointMode ? "Carte" : "Recherche")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                // Message GPS si désactivé
                if !locationService.isLocationAvailable {
                    gpsDisabledWarning
                }
                
                // Champs d'adresse
                addressFieldsSection
                
                // Indicateur mode pickup GPS
                if !viewModel.locationPicker.useCustomPickup && viewModel.locationPicker.isPickupFromGPS {
                    gpsPickupIndicator
                }
                
                
                // Options compactes
                optionsSection
                
                // Bouton de recherche
                searchButton
                
                // Estimation
                if viewModel.route.showEstimate {
                    estimationSection
                }
                
                // Suggestions (seulement en mode recherche)
                if viewModel.showSuggestions &&
                   !viewModel.addressSearch.suggestions.isEmpty &&
                   !viewModel.pinpoint.isPinpointMode {
                    suggestionsList
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Sections spécialisées
    private var gpsDisabledWarning: some View {
        HStack {
            Image(systemName: "location.slash")
                .foregroundColor(.red)
            Text("enableGpsMessage".localized)
                .font(.caption)
                .foregroundColor(.red)
            Spacer()
            Button("enableGps".localized) {
                viewModel.requestLocationPermission()
            }
            .font(.caption)
            .foregroundColor(.red)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 20)
    }
    
    private var addressFieldsSection: some View {
        VStack(spacing: 8) {
            // Champ pickup (toujours visible)
            CentralizedLocationField(
                text: Binding(
                    get: { viewModel.displayPickupAddress },
                    set: { newValue in
                        if viewModel.locationPicker.useCustomPickup {
                            viewModel.onLocationTextChanged(newValue, for: .pickup)
                        }
                    }
                ),
                placeholder: "pickupLocation".localized,
                errorMessage: viewModel.driverSearch.pickupError,
                isPickup: true,
                fieldType: .pickup,
                activeField: $viewModel.activeField,
                onTextChange: { newText in
                    if viewModel.locationPicker.useCustomPickup {
                        viewModel.onLocationTextChanged(newText, for: .pickup)
                    }
                },
                onLocationSelected: { location in
                    viewModel.setPickupLocation(location)
                },
                isGPSMode: !viewModel.locationPicker.useCustomPickup,
                onLongPress: {
                    viewModel.enableCustomPickup()
                }
            )
            
            // Champ destination (masqué en mode pinpoint)
            if !viewModel.pinpoint.isPinpointMode {
                CentralizedLocationField(
                    text: $viewModel.destinationAddress,
                    placeholder: "destination".localized,
                    errorMessage: viewModel.driverSearch.destinationError,
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
        }
        .padding(.horizontal, 20)
    }
    
    private var gpsPickupIndicator: some View {
        HStack {
            Image(systemName: "location.fill")
                .font(.caption)
                .foregroundColor(.red)
            Text("usingGpsLocation".localized)
                .font(.caption2)
                .foregroundColor(.gray)
            Spacer()
            Text("tapToCustomize".localized)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }
    

    private var optionsSection: some View {
        HStack(spacing: 16) {
            // Passagers
            HStack(spacing: 4) {
                Text("passengers".localized)
                    .font(.caption)
                    .foregroundColor(.gray)
                HStack(spacing: 8) {
                    Button("-") {
                        if viewModel.passengerCount > 1 {
                            viewModel.passengerCount -= 1
                        }
                    }
                    .frame(width: 24, height: 24)
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.black)
                    .cornerRadius(4)
                    .disabled(viewModel.passengerCount <= 1)
                    
                    Text("\(viewModel.passengerCount)")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                        .frame(minWidth: 16)
                    
                    Button("+") {
                        if viewModel.passengerCount < 8 {
                            viewModel.passengerCount += 1
                        }
                    }
                    .frame(width: 24, height: 24)
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.black)
                    .cornerRadius(4)
                    .disabled(viewModel.passengerCount >= 8)
                }
            }
            
            Spacer()
            
            // Type de service
            Picker("", selection: $viewModel.serviceType) {
                Text("economy".localized)
                Text("standard".localized)
                Text("premium".localized)
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(maxWidth: 160)
        }
        .padding(.horizontal, 20)
    }
    
    private var searchButton: some View {
        Button(action: {
            Task {
                await viewModel.searchDrivers()
            }
        }) {
            HStack {
                if viewModel.driverSearch.isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(viewModel.driverSearch.isSearching ?
                     ("searching".localized) :
                        ("findDrivers".localized))
                .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(viewModel.canSearch ? Color.red : Color.gray.opacity(0.3))
        .foregroundColor(.white)
        .cornerRadius(8)
        .disabled(viewModel.driverSearch.isSearching || !viewModel.canSearch)
        .padding(.horizontal, 20)
    }
    
    private var estimationSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("estimatedFare".localized)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(viewModel.route.estimatedFare)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("distance".localized)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(viewModel.route.estimatedDistance)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Liste de suggestions
    private var suggestionsList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.addressSearch.suggestions.prefix(Self.maxSuggestions), id: \.id) { suggestion in
                Button(action: {
                    viewModel.selectSuggestion(suggestion)
                }) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        
                        Text(suggestion.displayText)
                            .font(.caption)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                
                if suggestion.id != viewModel.addressSearch.suggestions.prefix(Self.maxSuggestions).last?.id {
                    Divider()
                }
            }
        }
        .background(Color.white)
        .cornerRadius(6)
        .shadow(radius: 4)
        .padding(.horizontal, 20)
    }
    
    // Observer changements position pour Mapbox
    
    private func setupMapboxObserver() {
        viewModel.$annotations
            .removeDuplicates()
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { annotations in
                DispatchQueue.main.async {
                    mapboxCenter = annotations.first?.coordinate ?? mapboxCenter
                }
            }
            .store(in: &cancellables)
        
        locationService.$currentLocation
            .compactMap { $0 }
            .removeDuplicates { old, new in
                let distance = CLLocation(latitude: old.latitude, longitude: old.longitude)
                    .distance(from: CLLocation(latitude: new.latitude, longitude: new.longitude))
                return distance < 20
            }
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { location in
                DispatchQueue.main.async {
                    mapboxCenter = location
                }
            }
            .store(in: &cancellables)
    }
    

}
