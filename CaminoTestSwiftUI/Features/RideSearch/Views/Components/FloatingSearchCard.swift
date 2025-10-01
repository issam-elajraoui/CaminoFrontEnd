//
//  FloatingSearchCard.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-30.
//
//
//  FloatingSearchCard.swift - PINPOINT TOUJOURS ACTIF
//  CaminoTestSwiftUI
//

import SwiftUI
import CoreLocation

struct FloatingSearchCard: View {
    
    // MARK: - Bindings
    @Binding var pickupAddress: String
    @Binding var destinationAddress: String
    @Binding var activeField: ActiveLocationField
    
    let pickupError: String
    let destinationError: String
    let showGPSIndicator: Bool
    
    let onPickupTextChange: (String) -> Void
    let onDestinationTextChange: (String) -> Void
    let onFieldFocused: (ActiveLocationField) -> Void  // NOUVEAU
    
    // MARK: - FocusState
    @FocusState private var focusedField: ActiveLocationField?
    
    // MARK: - Configuration
    private let fieldHeight: CGFloat = 50
    private let shadowRadius: CGFloat = 12
    private let cornerRadius: CGFloat = 16
    
    var body: some View {
        VStack(spacing: 0) {
            // Champ Pickup
            HStack(spacing: 12) {
                Circle()
                    .fill(showGPSIndicator ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                
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
                        onFieldFocused(.pickup)
                    }
                
                if showGPSIndicator {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
                
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
            
            Divider()
                .padding(.leading, 40)
            
            // Champ Destination
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                
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
                        onFieldFocused(.destination)
                    }
                
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
            
            // Messages d'erreur
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
        .onChange(of: activeField) { oldValue, newValue in
            focusedField = newValue
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if let newValue = newValue {
                activeField = newValue
                onFieldFocused(newValue)
            }
        }
    }
    
    // MARK: - Helper
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
