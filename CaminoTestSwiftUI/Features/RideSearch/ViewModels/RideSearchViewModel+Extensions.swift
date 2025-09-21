import Foundation
import MapKit

// MARK: - Extension du ViewModel pour MKLocalSearchCompleterDelegate
extension RideSearchViewModel: MKLocalSearchCompleterDelegate {
    
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            // Convertir les résultats en AddressSuggestion
            let newSuggestions = completer.results.compactMap { completion -> AddressSuggestion? in
                let displayText = formatCompletionForDisplay(completion)
                
                return AddressSuggestion(
                    id: UUID().uuidString,
                    displayText: displayText,
                    fullAddress: completion.title + ", " + completion.subtitle,
                    coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    completion: completion
                )
            }
            
            suggestions = Array(newSuggestions.prefix(7))
            showSuggestions = !suggestions.isEmpty
            isLoadingSuggestions = false
        }
    }
       
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            print("MKLocalSearchCompleter error: \(error.localizedDescription)")
            await handleAutocompleteError(error)
        }
    }
    
    // MARK: - Formatage des résultats de completion
    private func formatCompletionForDisplay(_ completion: MKLocalSearchCompletion) -> String {
        let title = completion.title
        let subtitle = completion.subtitle
        
        // Si le subtitle est vide ou redondant, utiliser seulement le titre
        if subtitle.isEmpty || title.contains(subtitle) {
            return title
        }
        
        // Sinon, combiner titre et sous-titre
        return "\(title), \(subtitle)"
    }
}
