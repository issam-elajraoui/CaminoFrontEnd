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
    
    // MARK: - Configuration optimisée
    private let squareSize: CGFloat = 14
    private let lineHeight: CGFloat = 24
    private let lineWidth: CGFloat = 3
    private let borderWidth: CGFloat = 3
    private let shadowRadius: CGFloat = 4
    
    init(isActive: Bool = true, isResolving: Bool = false) {
        self.isActive = isActive
        self.isResolving = isResolving
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Carré principal avec ombre canadienne
            squareIndicator
            
            // Ligne verticale avec ombre
            lineIndicator
        }
        .scaleEffect(isActive ? (isResolving ? 1.1 : 1.0) : 0.8)
        .opacity(isActive ? 1.0 : 0.6)
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .animation(.easeInOut(duration: 0.1), value: isResolving)
    }
    
    // MARK: - Carré indicateur avec style canadien (MODIFIÉ)
    private var squareIndicator: some View {
        ZStack {
            // Fond blanc avec ombre
            Rectangle()
                .fill(Color.white)
                .frame(width: squareSize, height: squareSize)
                .shadow(color: .black.opacity(0.3), radius: shadowRadius, x: 0, y: 2)
            
            // Bordure rouge Canada
            Rectangle()
                .stroke(Color.red, lineWidth: borderWidth)
                .frame(width: squareSize, height: squareSize)
            
            // Animation de résolution optimisée pour temps réel
            if isResolving {
                resolvingAnimation
            }
        }
    }
    
    // MARK: - Ligne verticale avec style canadien (MODIFIÉ)
    private var lineIndicator: some View {
        Rectangle()
            .fill(Color.red) // Rouge Canada
            .frame(width: lineWidth, height: lineHeight)
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Animation de résolution plus subtile (MODIFIÉ)
    private var resolvingAnimation: some View {
        Circle()
            .stroke(Color.red.opacity(0.6), lineWidth: 2)
            .frame(width: squareSize * 1.8, height: squareSize * 1.8)
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
