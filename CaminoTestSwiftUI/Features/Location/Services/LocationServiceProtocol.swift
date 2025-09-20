//
//  LocationServiceProtocol.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-09-20.
//

import Foundation
import CoreLocation
import MapKit

// MARK: - Protocole LocationServiceProtocol
@MainActor
public protocol LocationServiceProtocol: ObservableObject {
    var currentLocation: CLLocationCoordinate2D? { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    var isLocationAvailable: Bool { get }
    
    func requestLocationPermission()
    func startLocationUpdates()
    func stopLocationUpdates()
    func geocodeAddress(_ address: String) async throws -> CLLocationCoordinate2D
    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> String
}
