import SwiftUI
import Foundation
import MapKit
import Combine


//// MARK: - Vue principale avec mode automatique selon position bottom sheet
//struct RideSearchView: View {
//    private static let maxSuggestions = 7
//    @StateObject private var viewModel = RideSearchCoordinator()
//    @StateObject private var locationService = LocationService()
//    @Environment(\.presentationMode) var presentationMode
//    @EnvironmentObject var localizationManager: LocalizationManager
//    
//    // États pour coordonnées Mapbox
//    @State private var mapboxCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 45.4215, longitude: -75.6972)
//    @State private var cancellables = Set<AnyCancellable>()
//    
//    // États bottom sheet
//    @State private var bottomSheetHeight: CGFloat = 0.7
//    @State private var isDraggingSheet: Bool = false
//    
//    // Seuils pour changement automatique de mode
//    private let searchModeThreshold: CGFloat = 0.55
//    private let pinpointModeThreshold: CGFloat = 0.55
//    
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack {
//                // Carte Mapbox plein écran
//                mapboxFullScreenSection
//                
//                // Bottom Sheet draggable
//                DraggableBottomSheet(
//                    heightPercentage: $bottomSheetHeight,
//                    isDragging: $isDraggingSheet
//                ) {
//                    bottomSheetContent
//                }
//                
//                // Toggle langue en overlay
//                VStack {
//                    HStack {
//                        Spacer()
//                        languageToggleButtons
//                            .padding(.trailing, 20)
//                            .padding(.top, 60)
//                    }
//                    Spacer()
//                }
//                
//                // Instructions pinpoint (seulement si mode pinpoint actif)
//                if viewModel.pinpoint.isPinpointMode {
//                    pinpointInstructions(geometry: geometry)
//                }
//            }
//        }
//        .environmentObject(locationService)
//        .alert("Error", isPresented: $viewModel.driverSearch.showError) {
//            Button("OK") { }
//        } message: {
//            Text(viewModel.driverSearch.userFriendlyErrorMessage)
//        }
//        .sheet(isPresented: $viewModel.driverSearch.showDriverResults) {
//            DriverResultsView(
//                drivers: viewModel.driverSearch.availableDrivers,
//                onDriverSelected: { driver in
//                    viewModel.selectDriver(driver)
//                }
//            )
//        }
//        .sheet(isPresented: $viewModel.showLocationPermission) {
//            LocationPermissionView(
//                onPermissionGranted: {
//                    viewModel.onLocationPermissionGranted()
//                },
//                onCancel: {
//                    viewModel.showLocationPermission = false
//                }
//            )
//            .environmentObject(locationService)
//        }
//        .onAppear {
//            viewModel.setLocationService(locationService)
//            viewModel.onViewAppear()
//            setupMapboxObserver()
//        }
//        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
//            viewModel.recheckLocationPermissions()
//        }
//        .onDisappear {
//            viewModel.pinpoint.cleanupPinpointTasks()
//        }
//        .onChange(of: bottomSheetHeight) { oldValue, newValue in
//            guard abs(newValue - oldValue) > 0.05 else { return }
//            
//            Task { @MainActor in
//                try? await Task.sleep(for: .milliseconds(100))
//                
//                let now = Date()
//                guard now.timeIntervalSince(lastSheetUpdate) > 0.2 else { return }
//                lastSheetUpdate = now
//                
//                if newValue <= pinpointModeThreshold && !viewModel.pinpoint.isPinpointMode {
//                    activatePinpointMode()
//                } else if newValue > searchModeThreshold && viewModel.pinpoint.isPinpointMode {
//                    deactivatePinpointMode()
//                }
//            }
//        }
//        .onChange(of: isDraggingSheet) { _, isDragging in
//            if !isDragging {
//                Task { @MainActor in
//                    try? await Task.sleep(for: .milliseconds(200))
//                    
//                    let now = Date()
//                    guard now.timeIntervalSince(lastSheetUpdate) > 0.2 else { return }
//                    lastSheetUpdate = now
//                    
//                    if bottomSheetHeight <= pinpointModeThreshold && !viewModel.pinpoint.isPinpointMode {
//                        activatePinpointMode()
//                    } else if bottomSheetHeight > searchModeThreshold && viewModel.pinpoint.isPinpointMode {
//                        deactivatePinpointMode()
//                    }
//                }
//            }
//        }
//    }
//    
//    // MARK: - Gestion automatique du changement de mode
//    @State private var lastSheetUpdate: Date = Date.distantPast
//
//    private func activatePinpointMode() {
//        withAnimation(.easeInOut(duration: 0.3)) {
//            viewModel.enablePinpointMode(for: viewModel.activeField)
//        }
//    }
//    
//    private func deactivatePinpointMode() {
//        withAnimation(.easeInOut(duration: 0.3)) {
//            viewModel.disablePinpointMode()
//        }
//    }
//    
//    // MARK: - Carte Mapbox plein écran
//    private var mapboxFullScreenSection: some View {
//        ZStack {
//            MapboxWrapper(
//                center: $mapboxCenter,
//                annotations: $viewModel.annotations,
//                route: $viewModel.route.currentRoute,
//                showUserLocation: $viewModel.showUserLocation,
//                isPinpointMode: $viewModel.pinpoint.isPinpointMode,
//                onMapTap: { coordinate in
//                    viewModel.handleMapTap(at: CGPoint(x: 0, y: 0))
//                },
//                onPinpointMove: { coordinate in
//                    viewModel.onMapCenterChangedSimple(coordinate: coordinate)
//                }
//            )
//            
//            PinpointIndicator(
//                isActive: viewModel.pinpoint.isPinpointMode,
//                isResolving: viewModel.pinpoint.isResolvingAddress
//            )
//            
//            VStack {
//                HStack {
//                    gpsLocationButton
//                        .padding(.leading, 20)
//                        .padding(.top, 60)
//                    Spacer()
//                }
//                Spacer()
//            }
//        }
//    }
//    
//    // MARK: - Instructions pinpoint simplifiées
//    private func pinpointInstructions(geometry: GeometryProxy) -> some View {
//        VStack {
//            VStack(spacing: 12) {
//                HStack {
//                    Spacer()
//                    Text("Déplacez la carte pour choisir votre destination")
//                        .font(.subheadline)
//                        .fontWeight(.medium)
//                        .foregroundColor(.white)
//                        .padding(.horizontal, 20)
//                        .padding(.vertical, 10)
//                        .background(Color.black.opacity(0.7))
//                        .cornerRadius(20)
//                        .shadow(radius: 4)
//                    Spacer()
//                }
//                
//                if viewModel.pinpoint.isResolvingAddress || !viewModel.pinpoint.pinpointAddress.isEmpty {
//                    HStack {
//                        Spacer()
//                        HStack(spacing: 8) {
//                            if viewModel.pinpoint.isResolvingAddress {
//                                ProgressView()
//                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                    .scaleEffect(0.7)
//                                Text("Recherche...")
//                                    .font(.footnote)
//                                    .foregroundColor(.white)
//                            } else {
//                                Text("📍")
//                                    .font(.footnote)
//                                Text(viewModel.pinpoint.pinpointAddress)
//                                    .font(.footnote)
//                                    .fontWeight(.medium)
//                                    .foregroundColor(.white)
//                                    .multilineTextAlignment(.center)
//                                    .lineLimit(2)
//                            }
//                        }
//                        .padding(.horizontal, 16)
//                        .padding(.vertical, 8)
//                        .background(Color.black.opacity(0.6))
//                        .cornerRadius(15)
//                        .shadow(radius: 3)
//                        Spacer()
//                    }
//                }
//            }
//            .padding(.top, 120)
//            
//            Spacer()
//        }
//        .transition(.opacity)
//    }
//
//    // MARK: - Bouton GPS
//    private var gpsLocationButton: some View {
//        Button(action: {
//            Task {
//                await viewModel.centerOnUserLocation()
//            }
//        }) {
//            ZStack {
//                Circle()
//                    .fill(Color.white)
//                    .frame(width: 44, height: 44)
//                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
//                
//                Image(systemName: locationService.isLocationAvailable ? "location.fill" : "location.slash")
//                    .font(.system(size: 18, weight: .medium))
//                    .foregroundColor(locationService.isLocationAvailable ? .red : .gray)
//            }
//        }
//        .disabled(!locationService.isLocationAvailable)
//        .scaleEffect(locationService.isLocationAvailable ? 1.0 : 0.9)
//        .animation(.easeInOut(duration: 0.2), value: locationService.isLocationAvailable)
//    }
//    
//    // MARK: - Toggle de langue
//    private var languageToggleButtons: some View {
//        LanguageToggle()
//            .shadow(radius: 2)
//    }
//    
//    // MARK: - Contenu bottom sheet simplifié
//    private var bottomSheetContent: some View {
//        ScrollView {
//            VStack(spacing: 12) {
//                // Titre avec indicateur mode
//                HStack {
//                    Text("findRide".localized)
//                        .font(.title3)
//                        .fontWeight(.bold)
//                        .foregroundColor(.black)
//                    
//                    Spacer()
//                    
//                    HStack(spacing: 4) {
//                        Image(systemName: viewModel.pinpoint.isPinpointMode ? "map.fill" : "magnifyingglass")
//                            .font(.caption)
//                            .foregroundColor(.gray)
//                        Text(viewModel.pinpoint.isPinpointMode ? "Carte" : "Recherche")
//                            .font(.caption2)
//                            .foregroundColor(.gray)
//                    }
//                }
//                .padding(.horizontal, 20)
//                .padding(.top, 8)
//                
//                // Message GPS si désactivé
//                if !locationService.isLocationAvailable {
//                    gpsDisabledWarning
//                }
//                
//                // Toggle "Pour moi / Pour quelqu'un d'autre"
//                rideModeToggle
//                
//                // Champs d'adresse
//                addressFieldsSection
//                
//                // Indicateur mode pickup GPS
//                if !viewModel.locationPicker.isRideForSomeoneElse && viewModel.locationPicker.isPickupFromGPS {
//                    gpsPickupIndicator
//                }
//                
//                // Options compactes
//                optionsSection
//                
//                // Bouton de recherche
//                searchButton
//                
//                // Estimation
//                if viewModel.route.showEstimate {
//                    estimationSection
//                }
//                
//                // Suggestions (seulement en mode recherche)
//                if viewModel.showSuggestions &&
//                   !viewModel.addressSearch.suggestions.isEmpty &&
//                   !viewModel.pinpoint.isPinpointMode {
//                    suggestionsList
//                }
//            }
//            .padding(.bottom, 40)
//        }
//    }
//    
//    // MARK: - Sections spécialisées
//    private var gpsDisabledWarning: some View {
//        HStack {
//            Image(systemName: "location.slash")
//                .foregroundColor(.red)
//            Text("enableGpsMessage".localized)
//                .font(.caption)
//                .foregroundColor(.red)
//            Spacer()
//            Button("enableGps".localized) {
//                viewModel.requestLocationPermission()
//            }
//            .font(.caption)
//            .foregroundColor(.red)
//        }
//        .padding(.horizontal, 20)
//        .padding(.vertical, 8)
//        .background(Color.red.opacity(0.1))
//        .cornerRadius(8)
//        .padding(.horizontal, 20)
//    }
//    
//    // MARK: - Toggle mode course (NOUVEAU)
//    private var rideModeToggle: some View {
//        HStack(spacing: 12) {
//            Button(action: {
//                viewModel.locationPicker.isRideForSomeoneElse = false
//            }) {
//                HStack(spacing: 4) {
//                    Image(systemName: viewModel.locationPicker.isRideForSomeoneElse ? "circle" : "checkmark.circle.fill")
//                        .font(.caption)
//                    Text("Pour moi")
//                        .font(.caption)
//                }
//                .foregroundColor(viewModel.locationPicker.isRideForSomeoneElse ? .gray : .red)
//            }
//            
//            Button(action: {
//                viewModel.locationPicker.isRideForSomeoneElse = true
//            }) {
//                HStack(spacing: 4) {
//                    Image(systemName: viewModel.locationPicker.isRideForSomeoneElse ? "checkmark.circle.fill" : "circle")
//                        .font(.caption)
//                    Text("Pour quelqu'un d'autre")
//                        .font(.caption)
//                }
//                .foregroundColor(viewModel.locationPicker.isRideForSomeoneElse ? .red : .gray)
//            }
//        }
//        .padding(.horizontal, 20)
//        .padding(.bottom, 4)
//    }
//    
//    private var addressFieldsSection: some View {
//        VStack(spacing: 8) {
//            // Champ pickup (toujours visible)
//            CentralizedLocationField(
//                text: Binding(
//                    get: { viewModel.locationPicker.pickupAddress },
//                    set: { newValue in
//                        viewModel.locationPicker.setPickupAddress(newValue)
//                        viewModel.onLocationTextChanged(newValue, for: .pickup)
//                    }
//                ),
//                placeholder: "pickupLocation".localized,
//                errorMessage: viewModel.driverSearch.pickupError,
//                isPickup: true,
//                fieldType: .pickup,
//                activeField: $viewModel.activeField,
//                onTextChange: { newText in
//                    viewModel.onLocationTextChanged(newText, for: .pickup)
//                },
//                onLocationSelected: { location in
//                    viewModel.setPickupLocation(location)
//                },
//                showGPSIndicator: !viewModel.locationPicker.isRideForSomeoneElse && viewModel.locationPicker.isPickupFromGPS
//            )
//            
//            // Champ destination (masqué en mode pinpoint)
//            if !viewModel.pinpoint.isPinpointMode {
//                CentralizedLocationField(
//                    text: $viewModel.destinationAddress,
//                    placeholder: "destination".localized,
//                    errorMessage: viewModel.driverSearch.destinationError,
//                    isPickup: false,
//                    fieldType: .destination,
//                    activeField: $viewModel.activeField,
//                    onTextChange: { newText in
//                        viewModel.onLocationTextChanged(newText, for: .destination)
//                    },
//                    onLocationSelected: { location in
//                        viewModel.setDestinationLocation(location)
//                    }
//                )
//            }
//        }
//        .padding(.horizontal, 20)
//    }
//    
//    private var gpsPickupIndicator: some View {
//        HStack {
//            Image(systemName: "location.fill")
//                .font(.caption)
//                .foregroundColor(.red)
//            Text("usingGpsLocation".localized)
//                .font(.caption2)
//                .foregroundColor(.gray)
//            Spacer()
//        }
//        .padding(.horizontal, 20)
//        .padding(.vertical, 4)
//    }
//
//    private var optionsSection: some View {
//        HStack(spacing: 16) {
//            // Passagers
//            HStack(spacing: 4) {
//                Text("passengers".localized)
//                    .font(.caption)
//                    .foregroundColor(.gray)
//                HStack(spacing: 8) {
//                    Button("-") {
//                        if viewModel.passengerCount > 1 {
//                            viewModel.passengerCount -= 1
//                        }
//                    }
//                    .frame(width: 24, height: 24)
//                    .background(Color.gray.opacity(0.1))
//                    .foregroundColor(.black)
//                    .cornerRadius(4)
//                    .disabled(viewModel.passengerCount <= 1)
//                    
//                    Text("\(viewModel.passengerCount)")
//                        .font(.footnote)
//                        .fontWeight(.medium)
//                        .foregroundColor(.black)
//                        .frame(minWidth: 16)
//                    
//                    Button("+") {
//                        if viewModel.passengerCount < 8 {
//                            viewModel.passengerCount += 1
//                        }
//                    }
//                    .frame(width: 24, height: 24)
//                    .background(Color.gray.opacity(0.1))
//                    .foregroundColor(.black)
//                    .cornerRadius(4)
//                    .disabled(viewModel.passengerCount >= 8)
//                }
//            }
//            
//            Spacer()
//            
//            // Type de service
//            Picker("", selection: $viewModel.serviceType) {
//                Text("economy".localized)
//                Text("standard".localized)
//                Text("premium".localized)
//            }
//            .pickerStyle(SegmentedPickerStyle())
//            .frame(maxWidth: 160)
//        }
//        .padding(.horizontal, 20)
//    }
//    
//    private var searchButton: some View {
//        Button(action: {
//            Task {
//                await viewModel.searchDrivers()
//            }
//        }) {
//            HStack {
//                if viewModel.driverSearch.isSearching {
//                    ProgressView()
//                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                        .scaleEffect(0.8)
//                }
//                Text(viewModel.driverSearch.isSearching ?
//                     ("searching".localized) :
//                        ("findDrivers".localized))
//                .fontWeight(.semibold)
//            }
//        }
//        .frame(maxWidth: .infinity)
//        .frame(height: 44)
//        .background(viewModel.canSearch ? Color.red : Color.gray.opacity(0.9))
//        .foregroundColor(.white)
//        .cornerRadius(8)
//        .disabled(viewModel.driverSearch.isSearching || !viewModel.canSearch)
//        .padding(.horizontal, 20)
//    }
//    
//    private var estimationSection: some View {
//        HStack {
//            VStack(alignment: .leading, spacing: 2) {
//                Text("estimatedFare".localized)
//                    .font(.caption)
//                    .foregroundColor(.gray)
//                Text(viewModel.route.estimatedFare)
//                    .font(.footnote)
//                    .fontWeight(.semibold)
//                    .foregroundColor(.black)
//            }
//            Spacer()
//            VStack(alignment: .trailing, spacing: 2) {
//                Text("distance".localized)
//                    .font(.caption)
//                    .foregroundColor(.gray)
//                Text(viewModel.route.estimatedDistance)
//                    .font(.footnote)
//                    .fontWeight(.semibold)
//                    .foregroundColor(.black)
//            }
//        }
//        .padding(10)
//        .background(Color.gray.opacity(0.1))
//        .cornerRadius(6)
//        .padding(.horizontal, 20)
//    }
//    
//    // MARK: - Liste de suggestions
//    private var suggestionsList: some View {
//        VStack(spacing: 0) {
//            // CHANGEMENT 1: Container avec background teinté + shadow moderne
//            // POURQUOI: Sépare visuellement la liste du reste, aspect premium
//            VStack(spacing: 10) { // CHANGEMENT 2: Espacement entre cards (avant: 0)
//                
//                ForEach(Array(viewModel.addressSearch.suggestions.prefix(Self.maxSuggestions).enumerated()), id: \.element.id) { index, suggestion in
//                    
//                    // CHANGEMENT 3: Button avec état pressed
//                    // POURQUOI: Feedback tactile immédiat
//                    Button(action: {
//                        viewModel.selectSuggestion(suggestion)
//                    }) {
//                        // CHANGEMENT 4: Card individuelle (pas de VStack global)
//                        HStack(alignment: .top, spacing: 12) { // CHANGEMENT 5: spacing 8→12, top alignment
//                            
//                            // CHANGEMENT 6: Icône minimaliste PREMIUM
//                            // POURQUOI: Less is more - look épuré type Uber Black/Apple Maps
//                            Image(systemName: "location.fill")
//                                .foregroundColor(.red)
//                                .font(.system(size: 14, weight: .medium)) // CHANGEMENT 7: Petite et discrète
//                            
//                            // CHANGEMENT 8: Hiérarchie textuelle améliorée
//                            // POURQUOI: Lecture rapide, info principale en avant
//                            VStack(alignment: .leading, spacing: 4) { // CHANGEMENT 9: spacing ajouté
//                                
//                                // CHANGEMENT 10: Adresse principale en bold
//                                // POURQUOI: C'est l'info critique pour l'utilisateur
//                                Text(extractMainAddress(suggestion.displayText))
//                                    .font(.body) // CHANGEMENT 11: caption → body
//                                    .fontWeight(.semibold) // CHANGEMENT 12: regular → semibold
//                                    .foregroundColor(.black)
//                                    .lineLimit(1)
//                                
//                                // CHANGEMENT 13: Sous-adresse en gris secondaire
//                                // POURQUOI: Hiérarchie visuelle claire
//                                if let subAddress = extractSubAddress(suggestion.displayText) {
//                                    Text(subAddress)
//                                        .font(.caption) // NOUVEAU: sous-adresse séparée
//                                        .foregroundColor(.secondary)
//                                        .lineLimit(1)
//                                }
//                            }
//                            
//                            Spacer()
//                            
//                            // CHANGEMENT 14: Chevron subtil pour indiquer l'action
//                            // POURQUOI: Affordance claire (élément cliquable)
//                            Image(systemName: "chevron.right")
//                                .font(.system(size: 12, weight: .medium))
//                                .foregroundColor(.gray.opacity(0.4))
//                        }
//                        .padding(.horizontal, 16) // CHANGEMENT 15: 12→16 pour plus d'air
//                        .padding(.vertical, 14) // CHANGEMENT 16: 8→14 pour plus de confort
//                        .background(Color.white) // CHANGEMENT 17: Background explicite blanc
//                        .cornerRadius(14) // CHANGEMENT 18: 6→14 pour modernité
//                        .shadow(
//                            color: .black.opacity(0.08), // CHANGEMENT 19: Shadow subtile
//                            radius: 6,
//                            x: 0,
//                            y: 3
//                        )
//                    }
//                    .buttonStyle(SuggestionButtonStyle()) // CHANGEMENT 20: Style custom avec animation
//                    .transition(.move(edge: .top).combined(with: .opacity)) // CHANGEMENT 21: Animation apparition
//                    .animation(
//                        .spring(response: 0.4, dampingFraction: 0.75)
//                            .delay(Double(index) * 0.05), // CHANGEMENT 22: Stagger effect
//                        value: viewModel.addressSearch.suggestions.count
//                    )
//                }
//            }
//            .padding(12) // CHANGEMENT 23: Padding interne du container
//            .background(Color.gray.opacity(0.02)) // CHANGEMENT 24: Background teinté très léger
//            .cornerRadius(16) // CHANGEMENT 25: Container arrondi moderne
//            .shadow(
//                color: .black.opacity(0.12), // CHANGEMENT 26: Shadow container
//                radius: 8,
//                x: 0,
//                y: 4
//            )
//        }
//        .padding(.horizontal, 20)
//        .padding(.top, 8) // CHANGEMENT 27: Espacement avec le contenu au-dessus
//    }
//    
//    private func extractMainAddress(_ fullAddress: String) -> String {
//        let components = fullAddress.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
//        return components.first ?? fullAddress
//    }
//
//    // CHANGEMENT 29: Helper pour extraire la sous-adresse
//    // POURQUOI: Afficher ville+province en secondaire
//    private func extractSubAddress(_ fullAddress: String) -> String? {
//        let components = fullAddress.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
//        guard components.count > 1 else { return nil }
//        return components.dropFirst().joined(separator: ", ")
//    }
//
//    // CHANGEMENT 30: Style de bouton custom avec effet pressed
//    // POURQUOI: Feedback tactile moderne, spring animation
//    struct SuggestionButtonStyle: ButtonStyle {
//        func makeBody(configuration: Configuration) -> some View {
//            configuration.label
//                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
//                .opacity(configuration.isPressed ? 0.9 : 1.0)
//                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
//        }
//    }
//    
//    // Observer changements position pour Mapbox
//    private func setupMapboxObserver() {
//        viewModel.$annotations
//            .removeDuplicates()
//            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
//            .sink { annotations in
//                DispatchQueue.main.async {
//                    mapboxCenter = annotations.first?.coordinate ?? mapboxCenter
//                }
//            }
//            .store(in: &cancellables)
//        
//        locationService.$currentLocation
//            .compactMap { $0 }
//            .removeDuplicates { old, new in
//                let distance = CLLocation(latitude: old.latitude, longitude: old.longitude)
//                    .distance(from: CLLocation(latitude: new.latitude, longitude: new.longitude))
//                return distance < 20
//            }
//            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
//            .sink { location in
//                DispatchQueue.main.async {
//                    mapboxCenter = location
//                }
//            }
//            .store(in: &cancellables)
//    }
//}

//import SwiftUI
//import Foundation
//import MapKit
//import Combine

// MARK: - Vue principale redesign Premium

struct RideSearchView: View {
    private static let maxSuggestions = 7
    
    @StateObject private var viewModel = RideSearchCoordinator()
    @StateObject private var locationService = LocationService()
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var localizationManager: LocalizationManager
    
    // États Mapbox
    @State private var mapboxCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 45.4215, longitude: -75.6972)
    @State private var cancellables = Set<AnyCancellable>()
    
    // État drawer suggestions
    @State private var showSuggestionsDrawer: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. CARTE PLEIN ÉCRAN
                mapboxFullScreen
                
                // 2. PINPOINT INDICATOR (CORRECTION 2: au-dessus de tout, centré)
                if viewModel.pinpoint.isPinpointMode {
                    PinpointIndicator(
                        isActive: viewModel.pinpoint.isPinpointMode,
                        isResolving: viewModel.pinpoint.isResolvingAddress
                    )
                    .zIndex(100) // CORRECTION 2: Z-index élevé pour être au-dessus
                }
                
                // 3. FLOATING SEARCH CARD - CORRECTION 1: Positionnement responsive 50%
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: geometry.size.height * 0.30) // 10% du haut = safeArea + marge
                    
                    floatingSearchCard(geometry: geometry)
                    
                    Spacer() // Pousse vers le haut
                }
                .zIndex(50) // Au-dessus de la carte mais sous le pinpoint
                
                // 4. BOUTONS D'ACTION EN OVERLAY
                overlayButtons
                    .zIndex(60)
                
                // 5. DRAWER DE SUGGESTIONS EN BAS
                if !viewModel.addressSearch.suggestions.isEmpty {
                    BottomSuggestionsDrawer(
                        suggestions: $viewModel.addressSearch.suggestions,
                        isVisible: $showSuggestionsDrawer,
                        onSuggestionSelected: { suggestion in
                            viewModel.selectSuggestion(suggestion)
                            showSuggestionsDrawer = false
                        }
                    )
                    .transition(.move(edge: .bottom))
                    .zIndex(40)
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
        .onChange(of: viewModel.addressSearch.suggestions) { oldValue, newValue in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showSuggestionsDrawer = !newValue.isEmpty
            }
        }
    }
    
    // MARK: - Carte Plein Écran
    private var mapboxFullScreen: some View {
        MapboxWrapper(
            center: $mapboxCenter,
            annotations: $viewModel.annotations,
            route: $viewModel.route.currentRoute,
            showUserLocation: $viewModel.showUserLocation,
            isPinpointMode: $viewModel.pinpoint.isPinpointMode,
            onMapTap: { coordinate in
                withAnimation {
                    showSuggestionsDrawer = false
                }
            },
            onPinpointMove: { coordinate in
                viewModel.onMapCenterChangedSimple(coordinate: coordinate)
            }
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Floating Search Card - CORRECTION 1 & 3: Responsive + TextFields
    private func floatingSearchCard(geometry: GeometryProxy) -> some View {
        FloatingSearchCard(
            pickupAddress: $viewModel.pickupAddress,
            destinationAddress: $viewModel.destinationAddress,
            activeField: $viewModel.activeField,
            pickupError: viewModel.driverSearch.pickupError,
            destinationError: viewModel.driverSearch.destinationError,
            showGPSIndicator: !viewModel.locationPicker.isRideForSomeoneElse && viewModel.locationPicker.isPickupFromGPS,
            
            // CORRECTION 3: Callbacks pour text change (pas tap)
            onPickupTextChange: { newText in
                viewModel.onLocationTextChanged(newText, for: .pickup)
                
                // Auto-show drawer si texte > 3 caractères
                if newText.count >= 3 {
                    withAnimation {
                        showSuggestionsDrawer = true
                    }
                }
            },
            onDestinationTextChange: { newText in
                viewModel.onLocationTextChanged(newText, for: .destination)
                
                // Auto-show drawer si texte > 3 caractères
                if newText.count >= 3 {
                    withAnimation {
                        showSuggestionsDrawer = true
                    }
                }
            }
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Boutons d'action en overlay
    private var overlayButtons: some View {
        VStack {
            HStack {
                // Bouton GPS
                gpsLocationButton
                    .padding(.leading, 20)
                    .padding(.top, 60)
                
                Spacer()
                
                // Toggle langue
                LanguageToggle()
                    .padding(.trailing, 20)
                    .padding(.top, 60)
            }
            
            Spacer()
        }
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
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
                
                Image(systemName: locationService.isLocationAvailable ? "location.fill" : "location.slash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(locationService.isLocationAvailable ? .red : .gray)
            }
        }
        .disabled(!locationService.isLocationAvailable)
    }
    
    // MARK: - Setup Mapbox Observer
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

// MARK: - Preview
struct RideSearchView_Previews: PreviewProvider {
    static var previews: some View {
        RideSearchView()
            .environmentObject(LocalizationManager.shared)
    }
}
