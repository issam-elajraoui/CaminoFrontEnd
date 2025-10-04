//
//  DrawerItem.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-10-02.
//

import Foundation
import CoreLocation

// MARK: - Type d'item dans le drawer
enum DrawerItemType {
    case suggestion
    case recent
}

// MARK: - Item unifié pour le drawer
struct DrawerItem: Identifiable {
    let id: String
    let type: DrawerItemType
    let suggestion: AddressSuggestion
    
    init(type: DrawerItemType, suggestion: AddressSuggestion) {
        self.id = "\(type)-\(suggestion.id)"
        self.type = type
        self.suggestion = suggestion
    }
}
