//
//   AddressSearchViewModel.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-29.
//

import Foundation
import MapKit
import Combine
import CoreLocation

// MARK: - ViewModel dédié à la recherche d'adresses
@MainActor
class AddressSearch: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var suggestions: [AddressSuggestion] = []
    @Published var isLoadingSuggestions = false
    @Published var suggestionError: String? = nil
    
    // MARK: - Private Properties
    private lazy var searchCompleter: MKLocalSearchCompleter = {
        let completer = MKLocalSearchCompleter()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        return completer
    }()
    
    private var searchTask: Task<Void, Never>?
    private let maxSuggestions = 7
    
    // MARK: - Configuration
    private var searchRegion: MKCoordinateRegion?
    
    // MARK: - Public Methods
    
    /// Configure la région de recherche pour les suggestions
    func configureSearchRegion(center: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 50000,
            longitudinalMeters: 50000
        )
        searchRegion = region
        searchCompleter.region = region
    }
    
    /// Recherche des suggestions d'adresses
    func searchAddress(_ query: String) {
        // Annuler la recherche précédente
        searchTask?.cancel()
        
        // Reset l'état
        suggestions = []
        suggestionError = nil
        
        // Sanitizer la query
        let sanitizedQuery = sanitizeQuery(query)
        
        // Vérifier longueur minimale
        guard sanitizedQuery.count >= 3 else {
            isLoadingSuggestions = false
            return
        }
        
        // Démarrer le chargement
        isLoadingSuggestions = true
        
        // Debounce de 500ms
        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                
                await self?.performSearch(query: sanitizedQuery)
            } catch {
                // Task annulé
            }
        }
    }
    
    /// Résout les coordonnées d'une suggestion via MKLocalSearch
    func resolveCoordinates(
        for suggestion: AddressSuggestion
    ) async -> AddressSuggestion {
        
        // Si pas de completion, retourner tel quel
        guard let completion = suggestion.completion else {
            return suggestion
        }
        
        // Résoudre via MKLocalSearch
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let localSearch = MKLocalSearch(request: searchRequest)
        
        do {
            let response = try await localSearch.start()
            
            if let mapItem = response.mapItems.first {
                let coordinate = mapItem.placemark.coordinate
                
                // Formater avec le placemark complet
                let formattedAddress = formatAddress(from: mapItem.placemark)
                
                // Retourner suggestion avec adresse complète
                return AddressSuggestion(
                    id: suggestion.id,
                    displayText: formattedAddress,
                    fullAddress: formattedAddress,
                    coordinate: coordinate,
                    completion: completion
                )
            }
        } catch {
            print("❌ AddressSearch: Error resolving coordinates - \(error)")
        }
        
        // Retourner original si échec
        return suggestion
    }
    
    /// Nettoie les ressources
    func cleanup() {
        searchTask?.cancel()
        searchTask = nil
        suggestions = []
        isLoadingSuggestions = false
        suggestionError = nil
    }
    
    // MARK: - Private Methods
    
    private func performSearch(query: String) async {
        searchCompleter.queryFragment = query
    }
    
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
    
    private func formatCompletionForDisplay(_ completion: MKLocalSearchCompletion) -> String {
        return formatAddress(from: completion)
//        let title = completion.title
//        let subtitle = completion.subtitle
//        
//        if subtitle.isEmpty || title.contains(subtitle) {
//            return title
//        }
//        
//        return "\(title), \(subtitle)"
    }
    
    private func handleSearchError(_ error: Error) {
        isLoadingSuggestions = false
        suggestions = []
        
        suggestionError = LocalizationManager.shared.currentLanguage == "fr" ?
            "Erreur de recherche d'adresse" :
            "Address search error"
        
        // Auto-clear l'erreur après 3 secondes
        Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run { [weak self] in
                if !Task.isCancelled {
                    self?.suggestionError = nil
                }
            }
        }
    }
    
    // MARK: - Address Formatting
    /// Formatte une adresse au format unifié depuis la Carte
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        // Partie 1: "1154 Tischart Cres"
        if let number = sanitizeComponent(placemark.subThoroughfare),
           let street = sanitizeComponent(placemark.thoroughfare) {
            components.append("\(number) \(street)")
        } else if let street = sanitizeComponent(placemark.thoroughfare) {
            components.append(street)
        }
        
        // Partie 2: "Gloucester, ON K1B 5P5"
        //var locationParts: [String] = []
        if let city = sanitizeComponent(placemark.locality) {
            components.append(city)
        }
        var provincePostal: [String] = []
        if let province = sanitizeComponent(placemark.administrativeArea) {
            provincePostal.append(province)
        }
        if let postal = sanitizeComponent(placemark.postalCode) {
            provincePostal.append(postal)
        }
        
        if !provincePostal.isEmpty {
            components.append(provincePostal.joined(separator: " "))
        }
        
        return components.isEmpty ? "Adresse inconnue" : components.joined(separator: ", ")
    }

    /// Formatte une adresse depuis MKLocalSearchCompletion
    private func formatAddress(from completion: MKLocalSearchCompletion) -> String {
        let title = sanitizeComponent(completion.title) ?? ""
        let subtitle = sanitizeComponent(completion.subtitle) ?? ""
        
        if subtitle.isEmpty {
            return title
        }
        
        // Parser subtitle: "Gloucester, ON, Canada"
        let parts = subtitle.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        
        // Reconstruire au format unifié
        // var result = title
        var components: [String] = [title]
        if let city = parts.first {
            components.append(city)
        }
        if parts.count > 1 {
            components.append(parts[1]) // Province
        }
        
        return components.joined(separator: ", ")
    }
    
    private func sanitizeComponent(_ value: String?) -> String? {
        guard let value = value else { return nil }
        
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let maxLength = 100
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: ",-./()#'"))
        
        let filtered = trimmed.unicodeScalars
            .filter { allowedCharacters.contains($0) }
            .map(String.init)
            .joined()
        
        let final = String(filtered.prefix(maxLength))
        return final.isEmpty ? nil : final
    }
}

// MARK: - MKLocalSearchCompleterDelegate
extension AddressSearch: MKLocalSearchCompleterDelegate {
    
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
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
            
            suggestions = Array(newSuggestions.prefix(maxSuggestions))
            isLoadingSuggestions = false
        }
    }
    
    nonisolated func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            print(" AddressSearch: MKLocalSearchCompleter error - \(error)")
            handleSearchError(error)
        }
    }
}
