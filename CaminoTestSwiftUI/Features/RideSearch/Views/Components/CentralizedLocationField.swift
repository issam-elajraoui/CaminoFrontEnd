import SwiftUI
import CoreLocation

// MARK: - Champ de localisation centralisé simplifié
struct CentralizedLocationField: View {
    @Binding var text: String
    let placeholder: String
    let errorMessage: String
    let isPickup: Bool
    let fieldType: ActiveLocationField
    @Binding var activeField: ActiveLocationField
    let onTextChange: (String) -> Void
    let onLocationSelected: (CLLocationCoordinate2D) -> Void
    let showGPSIndicator: Bool
    
    // MARK: - Initialisation
    init(
        text: Binding<String>,
        placeholder: String,
        errorMessage: String,
        isPickup: Bool,
        fieldType: ActiveLocationField,
        activeField: Binding<ActiveLocationField>,
        onTextChange: @escaping (String) -> Void,
        onLocationSelected: @escaping (CLLocationCoordinate2D) -> Void,
        showGPSIndicator: Bool = false
    ) {
        self._text = text
        self.placeholder = placeholder
        self.errorMessage = errorMessage
        self.isPickup = isPickup
        self.fieldType = fieldType
        self._activeField = activeField
        self.onTextChange = onTextChange
        self.onLocationSelected = onLocationSelected
        self.showGPSIndicator = showGPSIndicator
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                // Indicateur visuel pickup/destination
                Circle()
                    .fill(circleColor)
                    .frame(width: 8, height: 8)
                
                // TextField standard toujours éditable
                TextField(placeholder, text: $text)
                    .font(.system(size: 14))
                    .disableAutocorrection(true)
                    .onChange(of: text) { _, newValue in
                        let sanitized = sanitizeLocationInput(newValue)
                        if sanitized != newValue {
                            text = sanitized
                        }
                        activeField = fieldType
                        onTextChange(sanitized)
                    }
                    .onTapGesture {
                        activeField = fieldType
                        if !text.isEmpty && text.count >= 3 {
                            onTextChange(text)
                        }
                    }
                
                // Bouton clear
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                        activeField = .none
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                }
                
                // Indicateur GPS si applicable
                if showGPSIndicator {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(fieldBackgroundColor)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            
            // Messages d'erreur
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.leading, 18)
            }
        }
    }
    
    // MARK: - Couleurs adaptatives
    private var circleColor: Color {
        if showGPSIndicator {
            return .black // GPS actif
        } else {
            return isPickup ? Color.gray.opacity(0.5) : Color.red
        }
    }
    
    private var fieldBackgroundColor: Color {
        if showGPSIndicator {
            return Color.gray.opacity(0.05)
        } else {
            return Color.gray.opacity(0.1)
        }
    }
    
    private var borderColor: Color {
        if !errorMessage.isEmpty {
            return .red
        } else if showGPSIndicator {
            return Color.green.opacity(0.3)
        } else {
            return Color.clear
        }
    }
    
    private var borderWidth: CGFloat {
        if !errorMessage.isEmpty {
            return 1
        } else if showGPSIndicator {
            return 1
        } else {
            return 0
        }
    }
    
    // MARK: - Sanitisation sécurisée
    private func sanitizeLocationInput(_ input: String) -> String {
        let maxLength = 200
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: ",-./()#"))
        
        let filtered = input.unicodeScalars
            .filter { allowedCharacters.contains($0) }
            .map(String.init)
            .joined()
        
        return String(filtered.prefix(maxLength))
    }
}
