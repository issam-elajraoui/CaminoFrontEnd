import Foundation

// MARK: - Erreurs de recherche
enum RideSearchError: Error, LocalizedError {
    case networkError
    case timeout
    case noDriversFound
    case invalidLocation
    case serviceUnavailable
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection failed"
        case .timeout:
            return "Search timeout"
        case .noDriversFound:
            return "No drivers available in your area"
        case .invalidLocation:
            return "Invalid pickup or destination"
        case .serviceUnavailable, .unknown:
            return "Service temporarily unavailable"
        }
    }
}
