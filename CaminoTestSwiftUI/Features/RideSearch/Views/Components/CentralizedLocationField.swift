import SwiftUI
import CoreLocation

// MARK: - Champ de localisation centralisé avec support pickup GPS et tap long
struct CentralizedLocationField: View {
    @Binding var text: String
    let placeholder: String
    let errorMessage: String
    let isPickup: Bool
    let fieldType: ActiveLocationField
    @Binding var activeField: ActiveLocationField
    let onTextChange: (String) -> Void
    let onLocationSelected: (CLLocationCoordinate2D) -> Void
    
    //  NOUVEAUX paramètres pour pickup GPS
    let isGPSMode: Bool
    let onLongPress: (() -> Void)?
    
    //  État interne pour tap long
    @State private var isLongPressing = false
    @State private var longPressTimer: Timer?
    
    //  Initialisation avec paramètres optionnels
    init(
        text: Binding<String>,
        placeholder: String,
        errorMessage: String,
        isPickup: Bool,
        fieldType: ActiveLocationField,
        activeField: Binding<ActiveLocationField>,
        onTextChange: @escaping (String) -> Void,
        onLocationSelected: @escaping (CLLocationCoordinate2D) -> Void,
        isGPSMode: Bool = false,
        onLongPress: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.errorMessage = errorMessage
        self.isPickup = isPickup
        self.fieldType = fieldType
        self._activeField = activeField
        self.onTextChange = onTextChange
        self.onLocationSelected = onLocationSelected
        self.isGPSMode = isGPSMode
        self.onLongPress = onLongPress
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                //  Indicateur visuel GPS/Custom
                Circle()
                    .fill(circleColor)
                    .frame(width: 8, height: 8)
                    .overlay(
                        // Indicateur GPS spécial
                        Circle()
                            .stroke(Color.white, lineWidth: 1)
                            .opacity(isGPSMode ? 1.0 : 0.0)
                    )
                
                //  TextField avec gestion GPS/Custom
                Group {
                    if isGPSMode {
                        gpsTextField
                    } else {
                        regularTextField
                    }
                }
                
                // Bouton clear (conservé)
                if !text.isEmpty && !isGPSMode {
                    Button(action: {
                        text = ""
                        activeField = .none
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                }
                
                //  Indicateur GPS visible
                if isGPSMode {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
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
            //  Animation tap long
            .scaleEffect(isLongPressing ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isLongPressing)
            
            // Messages d'erreur
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.leading, 18)
            }
            
            //  Message informatif GPS
            if isGPSMode && isPickup {
                Text("📍 Position GPS utilisée • Appui long pour modifier")
                    .font(.caption2)
                    .foregroundColor(.green)
                    .padding(.leading, 18)
                    .padding(.top, 2)
            }
        }
    }
    
    // MARK: -  TextField mode GPS (read-only avec tap long)
    private var gpsTextField: some View {
        Text(text.isEmpty ? placeholder : text)
            .font(.system(size: 14))
            .foregroundColor(text.isEmpty ? .secondary : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                // Tap normal ne fait rien en mode GPS
            }
            .gesture(
                //  Gesture tap long pour activer custom pickup
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isLongPressing {
                            isLongPressing = true
                            startLongPressTimer()
                        }
                    }
                    .onEnded { _ in
                        stopLongPressTimer()
                        isLongPressing = false
                    }
            )
    }
    
    // MARK: - TextField mode normal (éditable)
    private var regularTextField: some View {
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
    }
    
    // MARK: -  Couleurs adaptatives selon mode et thème canadien
    private var circleColor: Color {
        if isGPSMode {
            return .green // GPS actif
        } else {
            return isPickup ? Color.green : Color.red // Normal
        }
    }
    
    private var fieldBackgroundColor: Color {
        if isGPSMode {
            return Color.green.opacity(0.05) // Fond légèrement vert en mode GPS
        } else {
            return Color.gray.opacity(0.1) // Fond normal
        }
    }
    
    private var borderColor: Color {
        if !errorMessage.isEmpty {
            return .red
        } else if isGPSMode {
            return Color.green.opacity(0.3)
        } else {
            return Color.clear
        }
    }
    
    private var borderWidth: CGFloat {
        if !errorMessage.isEmpty {
            return 1
        } else if isGPSMode {
            return 1
        } else {
            return 0
        }
    }
    
    // MARK: -  Gestion tap long sécurisée
    private func startLongPressTimer() {
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { _ in
            handleLongPress()
        }
    }
    
    private func stopLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
    
    private func handleLongPress() {
        guard isGPSMode, let onLongPress = onLongPress else { return }
        
        //  Feedback haptique style canadien (léger)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        //  Animation courte et exécution callback
        withAnimation(.easeInOut(duration: 0.2)) {
            onLongPress()
        }
    }
    
    // MARK: - Sanitisation sécurisée (conservée)
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
