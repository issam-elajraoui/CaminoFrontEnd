//
//  BottomSuggestionsDrawer.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-30.
//

import SwiftUI
import CoreLocation

// MARK: - Drawer bottom premium pour suggestions
struct BottomSuggestionsDrawer: View {
    
    // MARK: - Bindings
    @Binding var suggestions: [AddressSuggestion]
    @Binding var isVisible: Bool
    
    let onSuggestionSelected: (AddressSuggestion) -> Void
    
    // MARK: - État interne
    @State private var dragOffset: CGFloat = 0
    @State private var isExpanded: Bool = false
    
    // MARK: - Configuration
    private let handleHeight: CGFloat = 24
    private let minHeight: CGFloat = 280 // Hauteur collapsed
    private let maxHeight: CGFloat = 500 // Hauteur expanded
    private let cornerRadius: CGFloat = 20
    
    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let currentHeight = isExpanded ? maxHeight : minHeight
            let finalHeight = currentHeight + dragOffset
            
            VStack(spacing: 0) {
                // Handle de drag élégant
                dragHandle
                
                // Contenu des suggestions
                suggestionsContent
            }
            .frame(height: finalHeight)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: -5)
            .offset(y: screenHeight - finalHeight)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        handleDragChanged(value)
                    }
                    .onEnded { value in
                        handleDragEnded(value)
                    }
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
        }
        .opacity(isVisible ? 1.0 : 0.0)
        .allowsHitTesting(isVisible)
    }
    
    // MARK: - Handle de drag
    private var dragHandle: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            Divider()
        }
    }
    
    // MARK: - Contenu des suggestions
    private var suggestionsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                
                // Header optionnel
                if !suggestions.isEmpty {
                    HStack {
                        Text("Suggestions")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                }
                
                // Liste des suggestions avec design moderne
                ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    Button(action: {
                        onSuggestionSelected(suggestion)
                    }) {
                        suggestionRow(suggestion)
                    }
                    .buttonStyle(SuggestionRowButtonStyle())
                    
                    if index < suggestions.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Row de suggestion premium
    private func suggestionRow(_ suggestion: AddressSuggestion) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Icône minimaliste
            Image(systemName: "location.fill")
                .foregroundColor(.red)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 20)
            
            // Hiérarchie textuelle
            VStack(alignment: .leading, spacing: 4) {
                // Adresse principale en gras
                Text(extractMainAddress(suggestion.displayText))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                // Sous-adresse en gris
                if let subAddress = extractSubAddress(suggestion.displayText) {
                    Text(subAddress)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Chevron subtil
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray.opacity(0.3))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.white)
        .contentShape(Rectangle())
    }
    
    // MARK: - Gestion du drag
    private func handleDragChanged(_ value: DragGesture.Value) {
        let translation = value.translation.height
        
        // Limiter le drag vers le bas seulement si collapsed
        if !isExpanded {
            dragOffset = max(0, translation)
        } else {
            // Si expanded, permettre drag dans les deux sens
            dragOffset = translation
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let velocity = value.predictedEndTranslation.height - value.translation.height
        let translation = value.translation.height
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if velocity > 50 || translation > 100 {
                // Drag vers le bas = collapse
                if isExpanded {
                    isExpanded = false
                } else {
                    isVisible = false
                }
            } else if velocity < -50 || translation < -100 {
                // Drag vers le haut = expand
                isExpanded = true
            }
            
            dragOffset = 0
        }
    }
    
    // MARK: - Helpers extraction adresse
    private func extractMainAddress(_ fullAddress: String) -> String {
        let components = fullAddress.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return components.first ?? fullAddress
    }
    
    private func extractSubAddress(_ fullAddress: String) -> String? {
        let components = fullAddress.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard components.count > 1 else { return nil }
        return components.dropFirst().joined(separator: ", ")
    }
}

// MARK: - Style de bouton avec feedback
struct SuggestionRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.gray.opacity(0.05) : Color.white)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
struct BottomSuggestionsDrawer_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.2).ignoresSafeArea()
            
            BottomSuggestionsDrawer(
                suggestions: .constant([
                    AddressSuggestion(
                        id: "1",
                        displayText: "St Thomas, 19, London City",
                        fullAddress: "St Thomas, 19, London City",
                        coordinate: CLLocationCoordinate2D(latitude: 45.4, longitude: -75.7)
                    ),
                    AddressSuggestion(
                        id: "2",
                        displayText: "Greenwood Theatre, King's College",
                        fullAddress: "Greenwood Theatre, King's College",
                        coordinate: CLLocationCoordinate2D(latitude: 45.4, longitude: -75.7)
                    )
                ]),
                isVisible: .constant(true),
                onSuggestionSelected: { _ in }
            )
        }
    }
}
