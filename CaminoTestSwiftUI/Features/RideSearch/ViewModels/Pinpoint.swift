//
//  Pinpoint.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-29.
//

import Foundation
import CoreLocation

// MARK: - Gestion du mode pinpoint (sélection sur carte)
@MainActor
class Pinpoint: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isPinpointMode: Bool = false
    @Published var isResolvingAddress: Bool = false
    @Published var pinpointAddress: String = ""
    
    // MARK: - Private Properties
    private var pinpointTask: Task<Void, Never>?
    
    // MARK: - Callbacks
    var onDestinationChanged: ((CLLocationCoordinate2D) -> Void)?
    
    // MARK: - Public Methods (CODE EXTRAIT TEL QUEL)
    
    func enablePinpointMode(for field: ActiveLocationField) {
        print("🟢 Pinpoint: enablePinpointMode called for field: \(field)")
        isPinpointMode = true
        print("🟢 Pinpoint: isPinpointMode set to \(isPinpointMode)")
    }

    func disablePinpointMode() {
        isPinpointMode = false
        isResolvingAddress = false
        pinpointAddress = ""
        
        // Annuler les tâches en cours
        pinpointTask?.cancel()
    }

    // MARK: - Map Center Changed (CODE EXTRAIT TEL QUEL)
    func onMapCenterChangedSimple(coordinate: CLLocationCoordinate2D) {
        guard isPinpointMode else { return }
        
        print("🗺️ Pinpoint center changed: \(coordinate)")
        
        // Mettre à jour la coordonnée destination
        onDestinationChanged?(coordinate)
        
        // Annuler la tâche précédente
        pinpointTask?.cancel()
        
        // Valider la coordonnée
        guard MapboxConfig.isValidCoordinate(coordinate) else {
            pinpointAddress = "Position invalide"
            isResolvingAddress = false
            return
        }
        
        // Démarrer la résolution avec debounce RÉDUIT
        isResolvingAddress = true
        
        pinpointTask = Task { [weak self] in
            do {
                // Debounce réduit à 800ms
                try await Task.sleep(for: .milliseconds(800))
                
                guard !Task.isCancelled else { return }
                
                print("🔄 Pinpoint resolving address...")
                
                // Utiliser le GeocodeManager global
                let address = try await GeocodeManager.shared.reverseGeocode(coordinate)
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.pinpointAddress = address
                    self.isResolvingAddress = false
                    
                    print("✅ Pinpoint address resolved: \(address)")
                }
                
            } catch {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.pinpointAddress = "Adresse introuvable"
                    self.isResolvingAddress = false
                    
                    print("❌ Pinpoint resolution failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Cleanup (CODE EXTRAIT TEL QUEL)
    func cleanupPinpointTasks() {
        pinpointTask?.cancel()
        pinpointTask = nil
        GeocodeManager.shared.clearQueue()
    }
}
