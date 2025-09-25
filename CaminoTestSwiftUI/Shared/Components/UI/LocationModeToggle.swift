////
////  LocationModeToggle.swift
////  CaminoTestSwiftUI
////
////  Created by Issam EL MOUJAHID on 2025-09-21.
////
//
//import SwiftUI
//
//// MARK: - Enum pour les modes de sélection d'adresse
//enum LocationInputMode {
//    case search    // Mode recherche textuelle
//    case pinpoint  // Mode pinpoint carte
//}
//
//// MARK: - Toggle pour basculer entre modes de sélection d'adresse
//struct LocationModeToggle: View {
//    @Binding var mode: LocationInputMode
//    let targetField: ActiveLocationField
//    let onModeChanged: (LocationInputMode, ActiveLocationField) -> Void
//    
//    // Configuration couleurs Canada
//    private let backgroundColor = Color.white
//    private let selectedColor = Color.red
//    private let unselectedColor = Color.gray
//    private let borderColor = Color.gray.opacity(0.3)
//    
//    init(
//        mode: Binding<LocationInputMode>,
//        targetField: ActiveLocationField,
//        onModeChanged: @escaping (LocationInputMode, ActiveLocationField) -> Void
//    ) {
//        self._mode = mode
//        self.targetField = targetField
//        self.onModeChanged = onModeChanged
//    }
//    
//    var body: some View {
//        HStack(spacing: 0) {
//            // Mode recherche textuelle
//            modeButton(
//                title: "🔍 Recherche",
//                currentMode: .search,
//                isSelected: mode == .search
//            )
//            
//            // Mode pinpoint carte
//            modeButton(
//                title: "📍 Sur la carte",
//                currentMode: .pinpoint,
//                isSelected: mode == .pinpoint
//            )
//        }
//        .background(backgroundColor)
//        .cornerRadius(8)
//        .overlay(
//            RoundedRectangle(cornerRadius: 8)
//                .stroke(borderColor, lineWidth: 1)
//        )
//        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
//    }
//    
//    // MARK: - Bouton de mode individuel
//    private func modeButton(
//        title: String,
//        currentMode: LocationInputMode,
//        isSelected: Bool
//    ) -> some View {
//        Button(action: {
//            withAnimation(.easeInOut(duration: 0.2)) {
//                mode = currentMode
//                onModeChanged(currentMode, targetField)
//            }
//        }) {
//            Text(title)
//                .font(.system(size: 13, weight: .medium))
//                .foregroundColor(isSelected ? .white : unselectedColor)
//                .frame(maxWidth: .infinity)
//                .frame(height: 32)
//                .background(isSelected ? selectedColor : Color.clear)
//                .cornerRadius(6)
//        }
//        .buttonStyle(PlainButtonStyle())
//    }
//}
//
//// MARK: - Composant d'affichage du mode pinpoint actif
//struct PinpointModeDisplay: View {
//    let isActive: Bool
//    let isResolving: Bool
//    let address: String
//    let onConfirm: () -> Void
//    let onCancel: () -> Void
//    
//    var body: some View {
//        if isActive {
//            VStack(spacing: 12) {
//                // Indicateur d'adresse résolue
//                addressDisplay
//                
//                // Boutons d'action
//                actionButtons
//            }
//            .padding(16)
//            .background(Color.white)
//            .cornerRadius(12)
//            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
//        }
//    }
//    
//    // MARK: - Affichage de l'adresse
//    private var addressDisplay: some View {
//        HStack(spacing: 8) {
//            // Indicateur de statut
//            if isResolving {
//                ProgressView()
//                    .progressViewStyle(CircularProgressViewStyle(tint: .red))
//                    .scaleEffect(0.8)
//            } else {
//                Image(systemName: "mappin.circle.fill")
//                    .foregroundColor(.red)
//                    .font(.system(size: 16))
//            }
//            
//            // Texte d'adresse
//            VStack(alignment: .leading, spacing: 2) {
//                Text(isResolving ? "Finding address..." : "Selected location")
//                    .font(.caption)
//                    .foregroundColor(.gray)
//                
//                Text(address.isEmpty ? "..." : address)
//                    .font(.footnote)
//                    .fontWeight(.medium)
//                    .foregroundColor(.black)
//                    .multilineTextAlignment(.leading)
//            }
//            
//            Spacer()
//        }
//    }
//    
//    // MARK: - Boutons d'action
//    private var actionButtons: some View {
//        HStack(spacing: 12) {
//            // Bouton annuler
//            Button(action: onCancel) {
//                Text("Cancel")
//                    .font(.system(size: 14, weight: .medium))
//                    .foregroundColor(.gray)
//                    .frame(maxWidth: .infinity)
//                    .frame(height: 36)
//                    .background(Color.gray.opacity(0.1))
//                    .cornerRadius(6)
//            }
//            
//            // Bouton confirmer
//            Button(action: onConfirm) {
//                Text("Confirm")
//                    .font(.system(size: 14, weight: .semibold))
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity)
//                    .frame(height: 36)
//                    .background(address.isEmpty ? Color.gray.opacity(0.3) : Color.red)
//                    .cornerRadius(6)
//            }
//            .disabled(address.isEmpty || isResolving)
//        }
//    }
//}
