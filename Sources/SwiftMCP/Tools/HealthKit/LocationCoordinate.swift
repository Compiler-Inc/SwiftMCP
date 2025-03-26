//
//  LocationCoordinate.swift
//  SwiftMCP
//
//  Created by Atharva Vaidya on 3/20/25.
//

import CoreLocation

/// Represents a location coordinate in a workout route
public struct LocationCoordinate: Codable {
    /// Latitude in degrees
    public let latitude: Double

    /// Longitude in degrees
    public let longitude: Double

    /// Altitude in meters
    public let altitude: Double

    /// Timestamp of the coordinate
    public let timestamp: Date

    /// Initialize from a CLLocation
    init(from location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        altitude = location.altitude
        timestamp = location.timestamp
    }
}
