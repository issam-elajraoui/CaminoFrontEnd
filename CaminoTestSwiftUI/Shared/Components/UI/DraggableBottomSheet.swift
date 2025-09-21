import SwiftUI

// MARK: - Bottom Sheet draggable sécurisé
struct DraggableBottomSheet<Content: View>: View {
    
    // MARK: - Propriétés
    @Binding var heightPercentage: CGFloat
    @Binding var isDragging: Bool
    let content: Content
    
    // MARK: - Configuration
    private let minHeight: CGFloat = 0.35  // 35%
    private let maxHeight: CGFloat = 0.70  // 70%
    private let handleHeight: CGFloat = 24
    private let cornerRadius: CGFloat = 20
    
    // MARK: - État interne
    @State private var dragOffset: CGFloat = 0
    @State private var lastDragValue: CGFloat = 0
    
    // MARK: - Initialisation
    init(
        heightPercentage: Binding<CGFloat>,
        isDragging: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self._heightPercentage = heightPercentage
        self._isDragging = isDragging
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let currentHeight = screenHeight * heightPercentage + dragOffset
            
            VStack(spacing: 0) {
                // Handle de drag
                dragHandle
                
                // Contenu du sheet
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: currentHeight)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: -5)
            .offset(y: screenHeight - currentHeight)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        handleDragChanged(value, screenHeight: screenHeight)
                    }
                    .onEnded { value in
                        handleDragEnded(value, screenHeight: screenHeight)
                    }
            )
        }
    }
    
    // MARK: - Handle de drag
    private var dragHandle: some View {
        VStack(spacing: 0) {
            // Indicateur visuel
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
            
            Spacer()
        }
        .frame(height: handleHeight)
        .contentShape(Rectangle())
    }
    
    // MARK: - Gestion du drag
    private func handleDragChanged(_ value: DragGesture.Value, screenHeight: CGFloat) {
        isDragging = true
        
        // CORRECTION: CGSize utilise .height pour la direction verticale
        let translation = value.translation.height
        let newOffset = lastDragValue + translation
        
        // Limiter dans les bornes
        let minHeightPoints = screenHeight * minHeight
        let maxHeightPoints = screenHeight * maxHeight
        let currentHeightPoints = screenHeight * heightPercentage
        
        let limitedOffset = max(
            minHeightPoints - currentHeightPoints,
            min(maxHeightPoints - currentHeightPoints, newOffset)
        )
        
        dragOffset = limitedOffset
    }
    
    private func handleDragEnded(_ value: DragGesture.Value, screenHeight: CGFloat) {
        isDragging = false
        
        // CORRECTION: CGSize utilise .height pour la direction verticale
        let velocity = value.predictedEndTranslation.height - value.translation.height
        
        // Déterminer la position finale
        let currentHeightPoints = screenHeight * heightPercentage + dragOffset
        let currentPercentage = currentHeightPoints / screenHeight
        
        let targetPercentage: CGFloat
        
        // Logique de snap basée sur la position et vélocité
        if velocity > 50 {
            // Drag vers le bas rapide
            targetPercentage = minHeight
        } else if velocity < -50 {
            // Drag vers le haut rapide
            targetPercentage = maxHeight
        } else {
            // Snap vers la position la plus proche
            let midPoint = (minHeight + maxHeight) / 2
            targetPercentage = currentPercentage > midPoint ? maxHeight : minHeight
        }
        
        // Animation vers la position finale
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            heightPercentage = targetPercentage
            dragOffset = 0
            lastDragValue = 0
        }
    }
}
