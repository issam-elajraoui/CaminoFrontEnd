import Foundation
import CoreLocation
import Combine

// MARK: - Gestionnaire d'autocomplétion d'adresses
@MainActor
class AddressAutocompleteManager: ObservableObject {
    // MARK: - Configuration
    private static let debounceDelay: TimeInterval = 0.5
    private static let minCharacters = 3
    private static let maxSuggestions = 5
    
    // MARK: - Published Properties
    @Published var suggestions: [AddressSuggestion] = []
    @Published var isSearching = false
    @Published var searchError: String? = nil
    
    // MARK: - Private Properties
    private let locationService: any LocationServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
    
    // MARK: - Initialisation
    init(locationService: any LocationServiceProtocol) {
        self.locationService = locationService
    }
    
    // MARK: - Recherche avec debounce
    func searchAddresses(for query: String, language: String) {
        // Annuler la recherche précédente
        searchTask?.cancel()
        
        // Nettoyer les résultats précédents
        suggestions = []
        searchError = nil
        
        // Validation de base
        let sanitizedQuery = sanitizeQuery(query)
        guard sanitizedQuery.count >= Self.minCharacters else {
            isSearching = false
            return
        }
        
        isSearching = true
        
        // Nouvelle recherche avec debounce
        searchTask = Task { [weak self] in
            do {
                // Attendre le délai de debounce
                try await Task.sleep(for: .milliseconds(Int(Self.debounceDelay * 1000)))
                
                // Vérifier si la tâche n'a pas été annulée
                guard !Task.isCancelled else { return }
                
                await self?.performAddressSearch(query: sanitizedQuery, language: language)
            } catch {
                // Task annulé ou erreur de sleep, ne rien faire
            }
        }
    }
    
    // MARK: - Recherche d'adresses
    private func performAddressSearch(query: String, language: String) async {
        do {
            // Utiliser le service de géolocalisation pour la recherche
            let coordinate = try await locationService.geocodeAddress(query)
            
            // Vérifier si la tâche n'a pas été annulée
            guard !Task.isCancelled else { return }
            
            // Créer la suggestion à partir du résultat
            let formattedAddress = try await locationService.reverseGeocode(coordinate)
            
            let suggestion = AddressSuggestion(
                id: UUID().uuidString,
                displayText: formattedAddress,
                fullAddress: formattedAddress,
                coordinate: coordinate
            )
            
            suggestions = [suggestion]
            isSearching = false
            
        } catch let error as LocationError {
            await handleSearchError(error, language: language)
        } catch {
            await handleSearchError(LocationError.unknown, language: language)
        }
    }
    
    // MARK: - Gestion des erreurs
    private func handleSearchError(_ error: LocationError, language: String) async {
        isSearching = false
        suggestions = []
        searchError = error.localizedDescription(language: language)
        
        // Effacer l'erreur après 3 secondes
        Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled {
                searchError = nil
            }
        }
    }
    
    // MARK: - Utilitaires
    private func sanitizeQuery(_ query: String) -> String {
        let maxLength = 200
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: ",-./()#'\""))
        
        let filtered = query.unicodeScalars
            .filter { allowedCharacters.contains($0) }
            .map(String.init)
            .joined()
        
        return String(filtered.prefix(maxLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func clearSuggestions() {
        searchTask?.cancel()
        suggestions = []
        searchError = nil
        isSearching = false
    }
}

// MARK: - Modèle de suggestion d'adresse
struct AddressSuggestion: Identifiable, Hashable {
    let id: String
    let displayText: String
    let fullAddress: String
    let coordinate: CLLocationCoordinate2D
    
    // Conformité à Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AddressSuggestion, rhs: AddressSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}
