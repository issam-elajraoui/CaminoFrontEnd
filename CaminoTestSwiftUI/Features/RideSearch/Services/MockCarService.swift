//
//  MockCarService.swift
//  CaminoTestSwiftUI
//
//  Created by Issam EL MOUJAHID on 2025-10-04.
//

import Foundation
import CoreLocation

class MockCarService {
    
    static let shared = MockCarService()
    
    private init() {}
    
    func generateMockCars(around center: CLLocationCoordinate2D, count: Int = 15) -> [CarVehicle] {
        var Cars: [CarVehicle] = []
        
        for i in 0..<count {
            let latOffset = Double.random(in: -0.02...0.02)
            let lonOffset = Double.random(in: -0.02...0.02)
            
            let coordinate = CLLocationCoordinate2D(
                latitude: center.latitude + latOffset,
                longitude: center.longitude + lonOffset
            )
            
            guard MapboxConfig.isValidCoordinate(coordinate) else { continue }
            
            let statuses: [CarStatus] = [.available, .available, .available, .busy, .offline]
            let status = statuses.randomElement() ?? .available
            
            let heading = Double.random(in: 0...360)
            
            let Car = CarVehicle(
                id: "Car-\(i)",
                coordinate: coordinate,
                status: status,
                heading: heading
            )
            
            Cars.append(Car)
        }
        
        return Cars
    }
}
