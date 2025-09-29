import SwiftUI

// MARK: - Composant toggle de langue réutilisable
public struct LanguageToggle: View {
    @EnvironmentObject var localizationManager: LocalizationManager
//    @Binding var currentLanguage: String
    
//    public init(currentLanguage: Binding<String>) {
//        self._currentLanguage = currentLanguage
//    }
    
    public var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                localizationManager.setLanguage("en")
            }) {
                Text("EN")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(localizationManager.currentLanguage == "en" ? .white : .gray)
                    .frame(width: 40, height: 28)
                    .background(localizationManager.currentLanguage == "en" ? Color.red : Color.clear)
            }
            
            Button(action: {
                localizationManager.setLanguage("fr")
            }) {
                Text("FR")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(localizationManager.currentLanguage == "fr" ? .white : .gray)
                    .frame(width: 40, height: 28)
                    .background(localizationManager.currentLanguage == "fr" ? Color.red : Color.clear)
            }
        }
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
}
