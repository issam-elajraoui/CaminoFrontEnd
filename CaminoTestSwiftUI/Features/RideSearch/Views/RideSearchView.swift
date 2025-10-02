//
//  RideSearchView.swift - MODE HYBRIDE PINPOINT + KEYBOARD
//  CaminoTestSwiftUI
//

import SwiftUI
import Foundation
import MapKit
import Combine

struct RideSearchView: View {
    private static let maxSuggestions = 7
    
    @StateObject private var viewModel = RideSearchCoordinator()
    @StateObject private var locationService = LocationService()
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var localizationManager: LocalizationManager
    
    @State private var mapboxCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 45.4215, longitude: -75.6972)
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showSuggestionsDrawer: Bool = false
    @State private var isKeyboardMode: Bool = false  // NOUVEAU
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. CARTE PLEIN ÉCRAN
                mapboxFullScreen
                
                // 2. PINPOINT INDICATOR - TOUJOURS VISIBLE
                VStack {
                    Spacer()
                        .frame(height: geometry.size.height * 0.5)
                    
                    PinpointIndicator(
                        isActive: !isKeyboardMode,  // Actif sauf si clavier
                        isResolving: viewModel.pinpoint.isResolvingAddress
                    )
                    
                    Spacer()
                }
                .zIndex(100)
                
                // 3. FLOATING SEARCH CARD - TOUJOURS VISIBLE
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: geometry.size.height * 0.20)
                    
                    floatingSearchCard(geometry: geometry)
                    
                    Spacer()
                }
                .zIndex(50)
                
                // 4. ADRESSE PINPOINT - En bas de la card
                if !isKeyboardMode && !viewModel.pinpoint.pinpointAddress.isEmpty {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: geometry.size.height * 0.10 + 120)
                        
                        pinpointAddressDisplay
                        
                        Spacer()
                    }
                    .zIndex(45)
                    .transition(.opacity)
                }
                
                // 5. BOUTONS D'ACTION EN OVERLAY
                overlayButtons
                    .zIndex(60)
                
//                 6. DRAWER DE SUGGESTIONS - Seulement en mode keyboard
                if isKeyboardMode && !viewModel.addressSearch.suggestions.isEmpty {
                    BottomSuggestionsDrawer(
                        suggestions: $viewModel.addressSearch.suggestions,
                        isVisible: $showSuggestionsDrawer,
                        onSuggestionSelected: { suggestion in
                            viewModel.selectSuggestion(suggestion)
                            showSuggestionsDrawer = false
                            isKeyboardMode = false  // Retour au mode pinpoint
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
            
            // Activer le mode pinpoint par défaut
            viewModel.pinpoint.isPinpointMode = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            viewModel.recheckLocationPermissions()
        }
        .onDisappear {
            viewModel.pinpoint.cleanupPinpointTasks()
        }
        .onChange(of: viewModel.addressSearch.suggestions) { oldValue, newValue in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showSuggestionsDrawer = !newValue.isEmpty && isKeyboardMode
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
                    isKeyboardMode = false
                    showSuggestionsDrawer = false
                }
            },
            onPinpointMove: { coordinate in
                // Si on bouge la carte, on est en mode pinpoint
                isKeyboardMode = false
                viewModel.onMapCenterChangedSimple(coordinate: coordinate)
            }
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Floating Search Card
    private func floatingSearchCard(geometry: GeometryProxy) -> some View {
        FloatingSearchCard(
            pickupAddress: $viewModel.pickupAddress,
            destinationAddress: $viewModel.destinationAddress,
            activeField: $viewModel.activeField,
            pickupError: viewModel.driverSearch.pickupError,
            destinationError: viewModel.driverSearch.destinationError,
            showGPSIndicator: !viewModel.locationPicker.isRideForSomeoneElse && viewModel.locationPicker.isPickupFromGPS,
            onPickupTextChange: { newText in
                // Dès qu'on tape, on passe en mode keyboard
                isKeyboardMode = true
                viewModel.onLocationTextChanged(newText, for: .pickup)
                
                if newText.count >= 3 {
                    withAnimation {
                        showSuggestionsDrawer = true
                    }
                }
            },
            onDestinationTextChange: { newText in
                // Dès qu'on tape, on passe en mode keyboard
                isKeyboardMode = true
                viewModel.onLocationTextChanged(newText, for: .destination)
                
                if newText.count >= 3 {
                    withAnimation {
                        showSuggestionsDrawer = true
                    }
                }
            },
            onFieldFocused: { field in
                // Quand on focus un champ sans taper, on reste en mode pinpoint
                viewModel.activeField = field
                viewModel.pinpoint.targetField = field
            }
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Affichage adresse pinpoint
    private var pinpointAddressDisplay: some View {
        HStack(spacing: 8) {
            if viewModel.pinpoint.isResolvingAddress {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.7)
                Text("Recherche...")
                    .font(.footnote)
                    .foregroundColor(.white)
            } else {
                Text(viewModel.pinpoint.pinpointAddress)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.7))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Boutons d'action en overlay
    private var overlayButtons: some View {
        VStack {
            HStack {
                gpsLocationButton
                    .padding(.leading, 20)
                    .padding(.top, 60)
                
                Spacer()
                
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

struct RideSearchView_Previews: PreviewProvider {
    static var previews: some View {
        RideSearchView()
            .environmentObject(LocalizationManager.shared)
    }
}
