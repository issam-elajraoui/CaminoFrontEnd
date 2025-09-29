//
//  LocalizationManager.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-29.
//

import Foundation
import SwiftUI

// MARK: - Gestionnaire centralisé de localisation
@MainActor
public class LocalizationManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = LocalizationManager()
    
    // MARK: - Published Properties
    @Published public var currentLanguage: String = "en"
    
    // MARK: - Constantes
    public static let supportedLanguages = ["en", "fr"]
    
    // MARK: - Initialisation privée
    private init() {
        // Initialiser avec la langue par défaut
        currentLanguage = "en"
    }
    
    // MARK: - Méthode principale de localisation
    public func localizedString(for key: String) -> String {
        // Récupérer le bundle de langue approprié
        guard let bundle = getLanguageBundle(for: currentLanguage) else {
            print("LocalizationManager: Bundle not found for language '\(currentLanguage)'")
            return "[\(key)]"
        }
        
        // Récupérer la traduction
        let localizedString = NSLocalizedString(
            key,
            tableName: "Localizable",
            bundle: bundle,
            value: "",
            comment: ""
        )
        
        // Vérifier si la clé existe (si elle n'existe pas, NSLocalizedString retourne la clé)
        if localizedString == key {
            print("LocalizationManager: Missing translation for key '\(key)' in language '\(currentLanguage)'")
            return "[\(key)]"
        }
        
        return localizedString
    }
    
    // MARK: - Changement de langue
    public func setLanguage(_ language: String) {
        // Valider que la langue est supportée
        guard Self.supportedLanguages.contains(language) else {
            print("LocalizationManager: Unsupported language '\(language)'")
            return
        }
        
        // Mettre à jour la langue courante
        currentLanguage = language
        print("LocalizationManager: Language changed to '\(language)'")
    }
    
    // MARK: - Helper privé pour récupérer le bundle
    private func getLanguageBundle(for language: String) -> Bundle? {
        // Récupérer le path du bundle de langue
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj") else {
            return nil
        }
        
        // Créer le bundle
        return Bundle(path: path)
    }
}
