import SwiftUI

// MARK: - Indicateur pinpoint CORRIGÉ avec pointe précise
struct PinpointIndicator: View {
    let isActive: Bool
    let isResolving: Bool
    
    // MARK: - Configuration optimisée pour précision
    private let circleSize: CGFloat = 20  // Diamètre du cercle
    private let pinHeight: CGFloat = 30   // Hauteur totale de la pointe
    private let pinWidth: CGFloat = 4     // Largeur de la tige
    private let shadowRadius: CGFloat = 4
    
    init(isActive: Bool = true, isResolving: Bool = false) {
        self.isActive = isActive
        self.isResolving = isResolving
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Cercle principal (tête du pin)
            circleIndicator
            
            // Tige du pin qui se termine en pointe
            pinStem
        }
        .scaleEffect(isActive ? (isResolving ? 1.1 : 1.0) : 0.8)
        .opacity(isActive ? 1.0 : 0.6)
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .animation(.easeInOut(duration: 0.1), value: isResolving)
    }
    
    // MARK: - Cercle indicateur avec style canadien
    private var circleIndicator: some View {
        ZStack {
            // Fond blanc avec ombre
            Circle()
                .fill(Color.white)
                .frame(width: circleSize, height: circleSize)
                .shadow(color: .black.opacity(0.3), radius: shadowRadius, x: 0, y: 2)
            
            // Bordure rouge Canada
            Circle()
                .stroke(Color.red, lineWidth: 3)
                .frame(width: circleSize, height: circleSize)
            
            // Point central pour meilleure visibilité
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
            
            // Animation de résolution
            if isResolving {
                resolvingAnimation
            }
        }
    }
    
    // MARK: - Tige du pin (bâton simple sans pointe)
    private var pinStem: some View {
        Rectangle()
            .fill(Color.red)
            .frame(width: pinWidth, height: pinHeight)
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Animation de résolution subtile
    private var resolvingAnimation: some View {
        Circle()
            .stroke(Color.red.opacity(0.6), lineWidth: 2)
            .frame(width: circleSize * 1.8, height: circleSize * 1.8)
            .scaleEffect(isResolving ? 1.3 : 0.9)
            .opacity(isResolving ? 0.4 : 0.8)
            .animation(
                isResolving ?
                Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) :
                Animation.easeInOut(duration: 0.2),
                value: isResolving
            )
    }
}

// MARK: - Preview
struct PinpointIndicator_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.2)
            
            VStack(spacing: 40) {
                // Normal
                PinpointIndicator(isActive: true, isResolving: false)
                
                // En résolution
                PinpointIndicator(isActive: true, isResolving: true)
                
                // Inactif
                PinpointIndicator(isActive: false, isResolving: false)
            }
        }
    }
}
