//
//  BottomSuggestionsDrawer.swift - LIMITE SOUS LA CARD
//  CaminoTestSwiftUI
//

import SwiftUI
import CoreLocation

struct BottomSuggestionsDrawer: View {
    
    @Binding var items: [DrawerItem]
    @Binding var isVisible: Bool
    
    let onItemSelected: (AddressSuggestion) -> Void
    let cardBottomY: CGFloat  // NOUVEAU: Position Y du bas de la floating card
    
    @State private var dragOffset: CGFloat = 0
    
    private let handleHeight: CGFloat = 20
    private let cornerRadius: CGFloat = 20
    private let horizontalPadding: CGFloat = 20
    
    private let heightPercentage: CGFloat = 0.45
    private let minHeight: CGFloat = 280
    private let maxHeight: CGFloat = 550
    private let bottomPadding: CGFloat = 20
    private let gapBelowCard: CGFloat = 8  // NOUVEAU: Espace minimum sous la card
    
    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let calculatedHeight = drawerHeight(for: screenHeight)
            let finalHeight = calculatedHeight + dragOffset
            
            // NOUVEAU: Calculer la position maximale (ne pas dépasser la card)
            let maxTopPosition = cardBottomY + gapBelowCard
            let defaultBottomPosition = screenHeight - finalHeight - bottomPadding
            let actualTopPosition = max(maxTopPosition, defaultBottomPosition)
            
            VStack(spacing: 0) {
                dragHandle
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        sectionsView
                    }
                    .padding(.bottom, 20)
                }
            }
            .frame(height: finalHeight)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: -5)
            .padding(.horizontal, horizontalPadding)
            .offset(y: actualTopPosition)  // MODIFIÉ: Utilise la position calculée
            .gesture(
                DragGesture()
                    .onChanged { value in
                        handleDragChanged(value)
                    }
                    .onEnded { value in
                        handleDragEnded(value)
                    }
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
        }
        .opacity(isVisible ? 1.0 : 0.0)
        .allowsHitTesting(isVisible)
    }
    
    private func drawerHeight(for screenHeight: CGFloat) -> CGFloat {
        let calculated = screenHeight * heightPercentage
        return min(max(calculated, minHeight), maxHeight)
    }
    
    private var sectionsView: some View {
        VStack(spacing: 0) {
            let suggestionItems = items.filter { $0.type == .suggestion }
            let recentItems = items.filter { $0.type == .recent }
            
            if !suggestionItems.isEmpty {
                sectionHeader(title: "SUGGESTIONS")
                
                ForEach(Array(suggestionItems.enumerated()), id: \.element.id) { index, item in
                    itemRow(item: item)
                    
                    if index < suggestionItems.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            
            if !recentItems.isEmpty {
                if !suggestionItems.isEmpty {
                    Divider()
                        .padding(.vertical, 8)
                }
                
                sectionHeader(title: "RÉCENT")
                
                ForEach(Array(recentItems.enumerated()), id: \.element.id) { index, item in
                    itemRow(item: item)
                    
                    if index < recentItems.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
        }
    }
    
    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
                .tracking(0.5)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(Color.white)
    }
    
    private func itemRow(item: DrawerItem) -> some View {
        Button(action: {
            onItemSelected(item.suggestion)
        }) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: item.type == .suggestion ? "location.fill" : "clock.fill")
                    .foregroundColor(item.type == .suggestion ? .red : .gray)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(extractMainAddress(item.suggestion.displayText))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    if let subAddress = extractSubAddress(item.suggestion.displayText) {
                        Text(subAddress)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 0)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white)
            .contentShape(Rectangle())
        }
        .buttonStyle(SuggestionRowButtonStyle())
    }
    
    private var dragHandle: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 4)
            
            Divider()
        }
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        let translation = value.translation.height
        dragOffset = max(0, translation)
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let velocity = value.predictedEndTranslation.height - value.translation.height
        let translation = value.translation.height
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if velocity > 50 || translation > 80 {
                isVisible = false
            }
            dragOffset = 0
        }
    }
    
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

struct SuggestionRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.gray.opacity(0.05) : Color.white)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
