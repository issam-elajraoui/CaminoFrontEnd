import Foundation
import MapKit
import CoreLocation

// MARK: - Configuration de recherche
struct RideSearchConfig {
    static let baseURL = "http://10.2.2.181:8083/ride"
    static let matchingURL = "http://10.2.2.181:9002"
    static let timeout: TimeInterval = 20
    static let maxRetries = 2
    static let ottawaRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.4215, longitude: -75.6972),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    )
}
