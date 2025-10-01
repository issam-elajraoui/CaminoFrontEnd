//
//  FloatingSearchCard.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-30.
//

import SwiftUI
import CoreLocation

// MARK: - Card flottante minimaliste
struct FloatingSearchCard: View {
    
    // MARK: - Bindings depuis parent
    @Binding var pickupAddress: String
    @Binding var destinationAddress: String
    @Binding var activeField: ActiveLocationField
    
    let pickupError: String
    let destinationError: String
    let showGPSIndicator: Bool
    
    let onPickupTextChange: (String) -> Void
    let onDestinationTextChange: (String) -> Void
    
//    let isPinpointMode: Bool
//    let onEnablePinpoint: () -> Void

    
    // MARK: - FocusState pour gérer le clavier
    @FocusState private var focusedField: ActiveLocationField?
    
    // MARK: - Configuration Premium
    private let cardPadding: CGFloat = 20
    private let fieldHeight: CGFloat = 50
    private let shadowRadius: CGFloat = 12
    private let cornerRadius: CGFloat = 16
    
    var body: some View {
        VStack(spacing: 0) {
            // CORRECTION 3a: TextField ÉDITABLE pour pickup
            HStack(spacing: 12) {
                // Indicateur visuel pickup (vert = départ)
                Circle()
                    .fill(showGPSIndicator ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                
                // TextField ÉDITABLE au lieu de Button
                TextField("pickupLocation".localized, text: $pickupAddress)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .focused($focusedField, equals: .pickup)
                    .onChange(of: pickupAddress) { oldValue, newValue in
                        onPickupTextChange(newValue)
                    }
                    .onTapGesture {
                        activeField = .pickup
                        focusedField = .pickup
                    }
                
                // Indicateur GPS actif
                if showGPSIndicator {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
                
                // Bouton clear
                if !pickupAddress.isEmpty {
                    Button(action: {
                        pickupAddress = ""
                        onPickupTextChange("")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                }
            }
            .frame(height: fieldHeight)
            .padding(.horizontal, 16)
            .background(Color.white)
            
            // Séparateur élégant
            Divider()
                .padding(.leading, 40)
            
            // CORRECTION 3b: TextField ÉDITABLE pour destination
            HStack(spacing: 12) {
                // Indicateur visuel destination (rouge = arrivée Canada)
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                
                // TextField ÉDITABLE au lieu de Button
                TextField("destination".localized, text: $destinationAddress)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .focused($focusedField, equals: .destination)
                    .onChange(of: destinationAddress) { oldValue, newValue in
                        onDestinationTextChange(newValue)
                    }
                    .onTapGesture {
                        activeField = .destination
                        focusedField = .destination
                    }
                
                // Bouton clear
                if !destinationAddress.isEmpty {
                    Button(action: {
                        destinationAddress = ""
                        onDestinationTextChange("")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                }
            }
            .frame(height: fieldHeight)
            .padding(.horizontal, 16)
            .background(Color.white)
            
            // Messages d'erreur compacts si nécessaire
            if !pickupError.isEmpty || !destinationError.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    if !pickupError.isEmpty {
                        errorLabel(pickupError)
                    }
                    if !destinationError.isEmpty {
                        errorLabel(destinationError)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.05))
            }
        }
        .background(Color.white)
        .cornerRadius(cornerRadius)
        .shadow(
            color: .black.opacity(0.12),
            radius: shadowRadius,
            x: 0,
            y: 4
        )
        // CORRECTION 3c: Synchroniser focusedField avec activeField
        .onChange(of: activeField) { oldValue, newValue in
            focusedField = newValue
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if let newValue = newValue {
                activeField = newValue
            }
        }
    }
    
    // MARK: - Helper: Label d'erreur compact
    private func errorLabel(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.red)
            
            Text(message)
                .font(.caption2)
                .foregroundColor(.red)
        }
    }
}

// MARK: - Preview
struct FloatingSearchCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.2).ignoresSafeArea()
            
            VStack {
                FloatingSearchCard(
                    pickupAddress: .constant("Tealey St, 21"),
                    destinationAddress: .constant(""),
                    activeField: .constant(.destination),
                    pickupError: "",
                    destinationError: "",
                    showGPSIndicator: true,
                    onPickupTextChange: { _ in },
                    onDestinationTextChange: { _ in }
                )
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                Spacer()
            }
        }
    }
}
