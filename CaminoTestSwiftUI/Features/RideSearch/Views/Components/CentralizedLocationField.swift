import SwiftUI
import CoreLocation

// MARK: - Champ de localisation centralisé
struct CentralizedLocationField: View {
    @Binding var text: String
    let placeholder: String
    let errorMessage: String
    let isPickup: Bool
    let fieldType: ActiveLocationField
    @Binding var activeField: ActiveLocationField
    let onTextChange: (String) -> Void
    let onLocationSelected: (CLLocationCoordinate2D) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isPickup ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                TextField(placeholder, text: $text)
                    .font(.system(size: 14))
                    .disableAutocorrection(true)
                    .onChange(of: text) { _, newValue in
                        let sanitized = sanitizeLocationInput(newValue)
                        if sanitized != newValue {
                            text = sanitized
                        }
                        
                        // Mettre à jour le champ actif et déclencher la recherche
                        activeField = fieldType
                        onTextChange(sanitized)
                    }
                    .onTapGesture {
                        activeField = fieldType
                        if !text.isEmpty && text.count >= 3 {
                            onTextChange(text)
                        }
                    }
                
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
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(errorMessage.isEmpty ? Color.clear : Color.red, lineWidth: 1)
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
    
    private func sanitizeLocationInput(_ input: String) -> String {
        let maxLength = 200
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: ",-./()#"))
        
        let filtered = input.unicodeScalars.filter { allowedCharacters.contains($0) }.map(String.init).joined()
        return String(filtered.prefix(maxLength))
    }
}
