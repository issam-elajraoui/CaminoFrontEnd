import Foundation
import CoreLocation
import SwiftUI

// MARK: - Annotation pour la carte
struct LocationAnnotation: Identifiable, Equatable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType
    
    enum AnnotationType {
        case pickup
        case destination
        
        var color: Color {
            switch self {
            case .pickup: return .green
            case .destination: return .red
            }
        }
    }
    static func == (lhs: LocationAnnotation, rhs: LocationAnnotation) -> Bool {
        return lhs.id == rhs.id
    }
}
