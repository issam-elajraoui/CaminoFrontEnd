//
//  RideSearchView.swift - BOUTONS TOUJOURS VISIBLES AVEC ÉTATS
//  CaminoTestSwiftUI
//

import SwiftUI
import Foundation
import MapKit
import Combine

struct RideSearchView: View {
    
    @StateObject private var viewModel = RideSearchCoordinator()
    @StateObject private var locationService = LocationService()
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var localizationManager: LocalizationManager
    
    @State private var mapboxCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 45.4215, longitude: -75.6972)
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showDrawer: Bool = false
    @State private var drawerItems: [DrawerItem] = []
    
    @FocusState private var focusedField: ActiveLocationField?
    
    // MOCK - Historique
    private let mockRecentSearches: [AddressSuggestion] = [
        AddressSuggestion(
            id: "recent-1",
            displayText: "Aéroport international Macdonald-Cartier, Ottawa",
            fullAddress: "1000 Airport Parkway Private, Ottawa, ON K1V 9B4",
            coordinate: CLLocationCoordinate2D(latitude: 45.3225, longitude: -75.6692)
        ),
        AddressSuggestion(
            id: "recent-2",
            displayText: "Rideau Centre, Ottawa",
            fullAddress: "50 Rideau St, Ottawa, ON K1N 9J7",
            coordinate: CLLocationCoordinate2D(latitude: 45.4256, longitude: -75.6911)
        ),
        AddressSuggestion(
            id: "recent-3",
            displayText: "Université d'Ottawa",
            fullAddress: "75 Laurier Ave E, Ottawa, ON K1N 6N5",
            coordinate: CLLocationCoordinate2D(latitude: 45.4215, longitude: -75.6830)
        ),
        AddressSuggestion(
            id: "recent-4",
            displayText: "Parlement du Canada",
            fullAddress: "111 Wellington St, Ottawa, ON K1A 0A9",
            coordinate: CLLocationCoordinate2D(latitude: 45.4236, longitude: -75.7009)
        ),
        AddressSuggestion(
            id: "recent-5",
            displayText: "ByWard Market, Ottawa",
            fullAddress: "55 ByWard Market Square, Ottawa, ON K1N 7A1",
            coordinate: CLLocationCoordinate2D(latitude: 45.4270, longitude: -75.6897)
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. CARTE
                mapboxFullScreen
                
                // 2. PINPOINT
                if !showDrawer {
                    VStack(spacing: 0) {
                        Spacer()
                        
                        PinpointIndicator(
                            isActive: true,
                            isResolving: viewModel.pinpoint.isResolvingAddress
                        )
                        .frame(height: 50)
                        .offset(y: -55)  // Décale vers le HAUT de la moitié de sa hauteur
                        
                        Spacer()
                    }
                    .zIndex(100)
                    .transition(.opacity)
                }
                
                // 3. FLOATING CARD
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: geometry.size.height * 0.15)
                    
                    FloatingSearchCard(
                        pickupAddress: $viewModel.pickupAddress,
                        destinationAddress: $viewModel.destinationAddress,
                        pickupError: viewModel.driverSearch.pickupError,
                        destinationError: viewModel.driverSearch.destinationError,
                        showGPSIndicator: !viewModel.locationPicker.isRideForSomeoneElse && viewModel.locationPicker.isPickupFromGPS,
                        onPickupTextChange: { newText in
                            viewModel.onLocationTextChanged(newText, for: .pickup, currentFocus: focusedField)
                            updateDrawerItems()
                        },
                        onDestinationTextChange: { newText in
                            viewModel.onLocationTextChanged(newText, for: .destination, currentFocus: focusedField)
                            updateDrawerItems()
                        },
                        focusedField: $focusedField
                    )
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .zIndex(50)
                
                // 4. ADRESSE PINPOINT
//                if !showDrawer && !viewModel.pinpoint.pinpointAddress.isEmpty {
//                    VStack(spacing: 0) {
//                        Spacer()
//                            .frame(height: geometry.size.height * 0.15 + 120)
//                        
//                        HStack(spacing: 8) {
//                            if viewModel.pinpoint.isResolvingAddress {
//                                ProgressView()
//                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                    .scaleEffect(0.7)
//                                Text("Recherche...")
//                                    .font(.footnote)
//                                    .foregroundColor(.white)
//                            } else {
//                                Text(viewModel.pinpoint.pinpointAddress)
//                                    .font(.footnote)
//                                    .fontWeight(.medium)
//                                    .foregroundColor(.white)
//                                    .multilineTextAlignment(.center)
//                                    .lineLimit(2)
//                            }
//                        }
//                        .padding(.horizontal, 16)
//                        .padding(.vertical, 10)
//                        .background(Color.black.opacity(0.7))
//                        .cornerRadius(15)
//                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
//                        
//                        Spacer()
//                    }
//                    .zIndex(45)
//                    .transition(.opacity)
//                }
//                
                // 5. BOUTONS OVERLAY
                overlayButtons
                
                // 6. DRAWER
                if showDrawer && !drawerItems.isEmpty {
                    GeometryReader { geo in
                        let cardTopOffset = geo.size.height * 0.15
                        let cardHeight: CGFloat = 120
                        let cardBottomY = cardTopOffset + cardHeight
                        
                        BottomSuggestionsDrawer(
                            items: $drawerItems,
                            isVisible: $showDrawer,
                            onItemSelected: { suggestion in
                                viewModel.selectSuggestion(suggestion, currentFocus: focusedField)
                                focusedField = nil
                            },
                            cardBottomY: cardBottomY
                        )
                    }
                    .transition(.move(edge: .bottom))
                    .zIndex(40)
                }
                
                // 7. BOUTONS LATER / RIDE NOW - TOUJOURS VISIBLES
                if !showDrawer {
                    actionButtons
                        .zIndex(70)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
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
            viewModel.pinpoint.isPinpointMode = true
            updateDrawerItems()
        }
        .onChange(of: viewModel.requestFocusOn) { _, newFocus in
            if let newFocus = newFocus {
                focusedField = newFocus
                // Reset après application
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    viewModel.requestFocusOn = nil
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            viewModel.recheckLocationPermissions()
        }
        .onDisappear {
            viewModel.pinpoint.cleanupPinpointTasks()
        }
        .onChange(of: viewModel.addressSearch.suggestions) { _, _ in
            updateDrawerItems()
        }
        .onChange(of: focusedField) { _, newField in
            if newField != nil {
                viewModel.pinpoint.targetField = newField ?? .destination
                updateDrawerItems()
                showDrawer = true
            }
        }
    }
    
    // MARK: - Boutons Later / Ride Now (toujours visibles)
    private var actionButtons: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                // Bouton Later (outline)
                Button(action: {
                    handleLaterBooking()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 16, weight: .medium))
                        Text("Later")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(canProceed ? .red : .gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(canProceed ? Color.red : Color.gray, lineWidth: 2)
                    )
                    .cornerRadius(16)
                    //.shadow(color: .black.opacity(canProceed ? 0.1 : 0.05), radius: 8, x: 0, y: 4)
                }
                .disabled(!canProceed)
                .opacity(canProceed ? 1.0 : 0.8)
                
                // Bouton Ride Now (filled)
                Button(action: {
                    handleRideNow()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Ride Now")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(canProceed ? Color.red : Color.gray)
                    .cornerRadius(16)
                    //.shadow(color: canProceed ? Color.red.opacity(0.4) : Color.clear, radius: 12, x: 0, y: 6)
                }
                .disabled(!canProceed)
                .opacity(canProceed ? 1.0 : 0.8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Condition d'activation des boutons
    private var canProceed: Bool {
        let hasPickup = !viewModel.pickupAddress.isEmpty &&
                        viewModel.locationPicker.pickupCoordinate != nil
        let hasDestination = !viewModel.destinationAddress.isEmpty &&
                             viewModel.destinationAddress != ""
        
        return hasPickup && hasDestination
    }
    
    // MARK: - Actions des boutons
    private func handleLaterBooking() {
        focusedField = nil
        showDrawer = false
        
        print("📅 Later booking - Navigate to schedule screen")
        // TODO: Navigation vers écran de planification
    }
    
    private func handleRideNow() {
        focusedField = nil
        showDrawer = false
        
        print("🚗 Ride Now - Searching for drivers...")
        
        Task {
            await viewModel.searchDrivers()
        }
    }
    
    // MARK: - Boutons en stack vertical haut droite
    private var overlayButtons: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(spacing: 12) {
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
                    
                   // LanguageToggle()
                }
                .padding(.trailing, 20)
                .padding(.top, 50)
            }
            
            Spacer()
        }
        .zIndex(60)
    }
    
    // MARK: - Smart Mix
    private func updateDrawerItems() {
        var items: [DrawerItem] = []
        let maxItems = 7
        
        let suggestions = viewModel.addressSearch.suggestions
        let suggestionItems = suggestions.prefix(5).map { suggestion in
            DrawerItem(type: .suggestion, suggestion: suggestion)
        }
        items.append(contentsOf: suggestionItems)
        
        let remainingSlots = maxItems - items.count
        if remainingSlots > 0 {
            let recentItems = mockRecentSearches.prefix(remainingSlots).map { suggestion in
                DrawerItem(type: .recent, suggestion: suggestion)
            }
            items.append(contentsOf: recentItems)
        }
        
        drawerItems = items
    }
    
    // MARK: - Carte
    private var mapboxFullScreen: some View {
        MapboxWrapper(
            center: $mapboxCenter,
            annotations: $viewModel.annotations,
            driverAnnotations: $viewModel.driverAnnotations,
            route: $viewModel.route.currentRoute,
            showUserLocation: $viewModel.showUserLocation,
            isPinpointMode: $viewModel.pinpoint.isPinpointMode,
            onMapTap: { _ in
                focusedField = nil
                showDrawer = false
            },
            onPinpointMove: { coordinate in
                viewModel.onMapCenterChangedSimple(coordinate: coordinate, currentFocus: focusedField)
            }
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Setup
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
