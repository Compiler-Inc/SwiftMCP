//
//  HealthDataSample.swift
//  SwiftMCP
//
//  Created by Atharva Vaidya on 3/20/25.
//

import Foundation
import HealthKit

/// Represents a single health data sample with its value and timestamp
@available(iOS 15, macOS 13.0, *)
public struct HealthDataSample: Codable {
    /// The value of the health data sample
    public let value: Double

    /// The date when the sample was recorded
    public let date: Date

    /// Initialize from an HKQuantity and date
    /// - Parameters:
    ///   - quantity: The HealthKit quantity
    ///   - unit: The unit to convert the quantity to
    ///   - date: The date of the sample
    init(quantity: HKQuantity, unit: HKUnit, date: Date) {
        value = quantity.doubleValue(for: unit)
        self.date = date
    }
}
