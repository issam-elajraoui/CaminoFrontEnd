//
//  PinpointIndicator.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-21.
//

import SwiftUI

// MARK: - Indicateur pinpoint fixe au centre de la carte
struct PinpointIndicator: View {
    let isActive: Bool
    let isResolving: Bool
    
    // MARK: - Configuration
    private let squareSize: CGFloat = 12
    private let lineHeight: CGFloat = 20
    private let lineWidth: CGFloat = 2
    private let borderWidth: CGFloat = 2
    
    init(isActive: Bool = true, isResolving: Bool = false) {
        self.isActive = isActive
        self.isResolving = isResolving
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Carré principal
            squareIndicator
            
            // Ligne verticale
            lineIndicator
        }
        .scaleEffect(isActive ? 1.0 : 0.8)
        .opacity(isActive ? 1.0 : 0.6)
        .animation(.easeInOut(duration: 0.3), value: isActive)
    }
    
    // MARK: - Carré indicateur
    private var squareIndicator: some View {
        ZStack {
            // Fond blanc
            Rectangle()
                .fill(Color.white)
                .frame(width: squareSize, height: squareSize)
            
            // Bordure noire
            Rectangle()
                .stroke(Color.black, lineWidth: borderWidth)
                .frame(width: squareSize, height: squareSize)
            
            // Animation de résolution d'adresse
            if isResolving {
                resolvingAnimation
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Ligne verticale
    private var lineIndicator: some View {
        Rectangle()
            .fill(Color.black)
            .frame(width: lineWidth, height: lineHeight)
            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
    }
    
    // MARK: - Animation de résolution
    private var resolvingAnimation: some View {
        Circle()
            .stroke(Color.red, lineWidth: 1)
            .frame(width: squareSize * 1.5, height: squareSize * 1.5)
            .scaleEffect(isResolving ? 1.2 : 0.8)
            .opacity(isResolving ? 0.3 : 0.8)
            .animation(
                isResolving ?
                Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                Animation.easeInOut(duration: 0.3),
                value: isResolving
            )
    }
}
