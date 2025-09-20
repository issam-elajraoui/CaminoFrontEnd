import Foundation
import CoreLocation
import MapKit



// MARK: - Modèle de suggestion d'adresse
struct AddressSuggestion: Identifiable, Hashable {
    let id: String
    let displayText: String
    let fullAddress: String
    let coordinate: CLLocationCoordinate2D
    let completion: MKLocalSearchCompletion? // NOUVEAU champ requis
    
    // Initializer avec completion optionnelle pour compatibilité
    init(id: String, displayText: String, fullAddress: String, coordinate: CLLocationCoordinate2D, completion: MKLocalSearchCompletion? = nil) {
        self.id = id
        self.displayText = displayText
        self.fullAddress = fullAddress
        self.coordinate = coordinate
        self.completion = completion
    }
    
    // Conformité à Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AddressSuggestion, rhs: AddressSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

