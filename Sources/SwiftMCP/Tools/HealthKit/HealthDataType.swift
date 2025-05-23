//
//  HealthDataType.swift
//  SwiftMCP
//
//  Created by Atharva Vaidya on 3/20/25.
//

import Foundation
import HealthKit

/// Represents the various types of health data that can be queried through HealthKit
@available(iOS 15, macOS 13.0, *)
public enum HealthDataType: String, Codable {
    // Activity metrics
    case stepCount
    case distanceWalkingRunning
    case activeEnergyBurned
    case basalEnergyBurned
    case flightsClimbed
    case appleExerciseTime
    case appleMoveTime
    case appleStandTime
    case distanceCycling
    case distanceSwimming
    case vo2Max

    // Body measurements
    case height
    case bodyMass
    case bodyMassIndex
    case bodyFatPercentage
    case leanBodyMass
    case waistCircumference

    // Vital signs
    case heartRate
    case restingHeartRate
    case oxygenSaturation
    case bloodPressureDiastolic
    case bloodPressureSystolic
    case respiratoryRate
    case walkingHeartRateAverage
    case heartRateVariabilitySDNN
    case bodyTemperature

    // Lab and test results
    case bloodGlucose
    case insulinDelivery

    // Mobility
    case walkingSpeed
    case walkingStepLength
    case sixMinuteWalkTestDistance

    /// Returns the corresponding HKQuantityType for this health data type
    var quantityType: HKQuantityType {
        switch self {
        // Activity metrics
        case .stepCount:
            return HKQuantityType(.stepCount)
        case .distanceWalkingRunning:
            return HKQuantityType(.distanceWalkingRunning)
        case .activeEnergyBurned:
            return HKQuantityType(.activeEnergyBurned)
        case .basalEnergyBurned:
            return HKQuantityType(.basalEnergyBurned)
        case .flightsClimbed:
            return HKQuantityType(.flightsClimbed)
        case .appleExerciseTime:
            return HKQuantityType(.appleExerciseTime)
        case .appleMoveTime:
            return HKQuantityType(.appleMoveTime)
        case .appleStandTime:
            return HKQuantityType(.appleStandTime)
        case .distanceCycling:
            return HKQuantityType(.distanceCycling)
        case .distanceSwimming:
            return HKQuantityType(.distanceSwimming)
        case .vo2Max:
            return HKQuantityType(.vo2Max)
        // Body measurements
        case .height:
            return HKQuantityType(.height)
        case .bodyMass:
            return HKQuantityType(.bodyMass)
        case .bodyMassIndex:
            return HKQuantityType(.bodyMassIndex)
        case .bodyFatPercentage:
            return HKQuantityType(.bodyFatPercentage)
        case .leanBodyMass:
            return HKQuantityType(.leanBodyMass)
        case .waistCircumference:
            return HKQuantityType(.waistCircumference)
        // Vital signs
        case .heartRate:
            return HKQuantityType(.heartRate)
        case .restingHeartRate:
            return HKQuantityType(.restingHeartRate)
        case .walkingHeartRateAverage:
            return HKQuantityType(.walkingHeartRateAverage)
        case .heartRateVariabilitySDNN:
            return HKQuantityType(.heartRateVariabilitySDNN)
        case .oxygenSaturation:
            return HKQuantityType(.oxygenSaturation)
        case .bloodPressureDiastolic:
            return HKQuantityType(.bloodPressureDiastolic)
        case .bloodPressureSystolic:
            return HKQuantityType(.bloodPressureSystolic)
        case .respiratoryRate:
            return HKQuantityType(.respiratoryRate)
        case .bodyTemperature:
            return HKQuantityType(.bodyTemperature)
        // Lab and test results
        case .bloodGlucose:
            return HKQuantityType(.bloodGlucose)
        case .insulinDelivery:
            return HKQuantityType(.insulinDelivery)
        // Mobility
        case .walkingSpeed:
            return HKQuantityType(.walkingSpeed)
        case .walkingStepLength:
            return HKQuantityType(.walkingStepLength)
        case .sixMinuteWalkTestDistance:
            return HKQuantityType(.sixMinuteWalkTestDistance)
        }
    }

    /// Returns the appropriate unit for this health data type
    var unit: HKUnit {
        switch self {
        // Activity metrics
        case .stepCount, .flightsClimbed:
            return .count()
        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .sixMinuteWalkTestDistance:
            return .meter()
        case .activeEnergyBurned, .basalEnergyBurned:
            return .kilocalorie()
        case .appleExerciseTime, .appleMoveTime, .appleStandTime:
            return .minute()
        case .vo2Max:
            return HKUnit(from: "ml/kg/min")
        // Body measurements
        case .height, .waistCircumference:
            return .meter()
        case .bodyMass, .leanBodyMass:
            return .gramUnit(with: .kilo)
        case .bodyMassIndex:
            return .count()
        case .bodyFatPercentage:
            return .percent()
        // Vital signs
        case .heartRate, .restingHeartRate, .walkingHeartRateAverage:
            return .count().unitDivided(by: .minute())
        case .heartRateVariabilitySDNN:
            return .secondUnit(with: .milli)
        case .oxygenSaturation:
            return .percent()
        case .bloodPressureDiastolic, .bloodPressureSystolic:
            return .millimeterOfMercury()
        case .respiratoryRate:
            return .count().unitDivided(by: .minute())
        case .bodyTemperature:
            return .degreeCelsius()
        // Lab and test results
        case .bloodGlucose:
            return HKUnit(from: "mg/dL")
        case .insulinDelivery:
            return .internationalUnit()
        // Mobility
        case .walkingSpeed:
            return .meter().unitDivided(by: .second())
        case .walkingStepLength:
            return .meter()
        }
    }
}
