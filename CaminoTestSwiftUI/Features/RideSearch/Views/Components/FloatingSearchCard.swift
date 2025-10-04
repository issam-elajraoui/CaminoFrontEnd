//
//  FloatingSearchCard.swift - CORRECTION
//  CaminoTestSwiftUI
//

//
//  FloatingSearchCard.swift - CORRECTION FOCUS INDIVIDUEL
//  CaminoTestSwiftUI
//

import SwiftUI
import CoreLocation

struct FloatingSearchCard: View {
    
    @Binding var pickupAddress: String
    @Binding var destinationAddress: String
    @Binding var activeField: ActiveLocationField
    
    let pickupError: String
    let destinationError: String
    let showGPSIndicator: Bool
    
    let onPickupTextChange: (String) -> Void
    let onDestinationTextChange: (String) -> Void
    
    @FocusState.Binding var focusedField: ActiveLocationField?  // CORRECTION: Enum au lieu de Bool
    
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
                    .focused($focusedField, equals: .pickup)  // CORRECTION: Focus sur .pickup
                    .onChange(of: pickupAddress) { _, newValue in
                        activeField = .pickup
                        onPickupTextChange(newValue)
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
                    .focused($focusedField, equals: .destination)  // CORRECTION: Focus sur .destination
                    .onChange(of: destinationAddress) { _, newValue in
                        activeField = .destination
                        onDestinationTextChange(newValue)
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
        .shadow(color: .black.opacity(0.12), radius: shadowRadius, x: 0, y: 4)
    }
    
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
