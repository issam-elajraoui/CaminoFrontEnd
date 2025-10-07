// PARTIE 2 : MODIFICATIONS dans Pinpoint.swift

import Foundation
import CoreLocation

@MainActor
class Pinpoint: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isPinpointMode: Bool = false
    @Published var isResolvingAddress: Bool = false
    @Published var pinpointAddress: String = ""
    @Published var targetField: ActiveLocationField = .destination
    
    // MARK: - Private Properties
    private var pinpointTask: Task<Void, Never>?
    
    // MARK: - Callbacks
    var onLocationChanged: ((CLLocationCoordinate2D, ActiveLocationField) -> Void)?
    
    // MARK: - Public Methods
    func enablePinpointMode(for field: ActiveLocationField) {
        targetField = field
        isPinpointMode = true
    }

    func disablePinpointMode() {
        isPinpointMode = false
        isResolvingAddress = false
        pinpointAddress = ""
        pinpointTask?.cancel()
    }

    //  AJOUTER paramètre currentFocus
    func onMapCenterChangedSimple(coordinate: CLLocationCoordinate2D, currentFocus: ActiveLocationField?) {
        guard isPinpointMode else { return }
        
        //  Utiliser currentFocus au lieu de targetField
        let fieldToUpdate = currentFocus ?? .destination
        onLocationChanged?(coordinate, fieldToUpdate)
        
        pinpointTask?.cancel()
        
        guard MapboxConfig.isValidCoordinate(coordinate) else {
            pinpointAddress = "Position invalide"
            isResolvingAddress = false
            return
        }
        
        isResolvingAddress = true
        
        pinpointTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                
                let address = try await GeocodeManager.shared.reverseGeocode(coordinate)
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.pinpointAddress = address
                    self.isResolvingAddress = false
                }
                
            } catch {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.pinpointAddress = "Adresse introuvable"
                    self.isResolvingAddress = false
                }
            }
        }
    }
    
    // MARK: - Cleanup
    func cleanupPinpointTasks() {
        pinpointTask?.cancel()
        pinpointTask = nil
        GeocodeManager.shared.clearQueue()
    }
}
