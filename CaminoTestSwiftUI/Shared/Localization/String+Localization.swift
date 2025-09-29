//
//  String+Localization.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-29.
//


import Foundation

// MARK: - Extension String pour simplifier la localisation
@MainActor
extension String {
    
    /// Retourne la chaîne localisée selon la langue courante
    /// Usage: "key".localized
    var localized: String {
        return LocalizationManager.shared.localizedString(for: self)
    }
    
    /// Retourne la chaîne localisée avec une langue spécifique
    /// Usage: "key".localized(language: "fr")
    func localized(language: String) -> String {
        // Sauvegarder la langue courante
        let currentLang = LocalizationManager.shared.currentLanguage
        
        // Changer temporairement la langue
        LocalizationManager.shared.setLanguage(language)
        let result = LocalizationManager.shared.localizedString(for: self)
        
        // Restaurer la langue d'origine
        LocalizationManager.shared.setLanguage(currentLang)
        
        return result
    }
}
