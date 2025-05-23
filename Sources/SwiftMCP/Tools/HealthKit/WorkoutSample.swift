//
//  WorkoutSample.swift
//  SwiftMCP
//
//  Created by Atharva Vaidya on 3/20/25.
//

import CoreLocation
import Foundation
import HealthKit

/// Represents a workout sample with its metadata and route if available
@available(iOS 15, macOS 13.0, *)
public struct WorkoutSample: Codable {
    /// The type of workout (e.g., running, cycling)
    public let workoutActivityType: String

    /// The start date of the workout
    public let startDate: Date

    /// The end date of the workout
    public let endDate: Date

    /// The duration of the workout in seconds
    public let duration: Double

    /// The total distance in meters (if available)
    public let totalDistance: Double?

    /// The total energy burned in kilocalories (if available)
    public let totalEnergyBurned: Double?

    /// The route coordinates if available
    public let route: [LocationCoordinate]?

    /// Initialize from an HKWorkout
    init(from workout: HKWorkout, route: [CLLocation]? = nil) {
        workoutActivityType = workout.workoutActivityType.name
        startDate = workout.startDate
        endDate = workout.endDate
        duration = workout.duration
        totalDistance = workout.totalDistance?.doubleValue(for: .meter())
        totalEnergyBurned = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
        self.route = route?.map { LocationCoordinate(from: $0) }
    }
}

@available(iOS 15, macOS 13.0, *)
extension HKWorkoutActivityType {
    /// All supported workout types
    static var supported: [HKWorkoutActivityType] {
        [
            .running,
            .cycling,
            .walking,
            .swimming,
            .hiking,
            .yoga,
            .functionalStrengthTraining,
            .traditionalStrengthTraining,
            .crossTraining,
            .mixedCardio,
            .highIntensityIntervalTraining,
            .rowing,
            .elliptical,
            .stairClimbing,
            .pilates,
            .cardioDance,
            .cooldown,
            .americanFootball,
            .baseball,
            .basketball,
            .boxing,
            .climbing,
            .golf,
            .hockey,
            .soccer,
            .tennis,
            .volleyball,
            .waterFitness,
            .other,
        ]
    }

    /// String representation of the workout type
    var name: String {
        switch self {
        case .running: return "running"
        case .cycling: return "cycling"
        case .walking: return "walking"
        case .swimming: return "swimming"
        case .hiking: return "hiking"
        case .yoga: return "yoga"
        case .functionalStrengthTraining: return "strength_training"
        case .traditionalStrengthTraining: return "strength_training"
        case .crossTraining: return "cross_training"
        case .mixedCardio: return "mixed_cardio"
        case .highIntensityIntervalTraining: return "hiit"
        case .rowing: return "rowing"
        case .elliptical: return "elliptical"
        case .stairClimbing: return "stair_climbing"
        case .pilates: return "pilates"
        case .dance: return "dance"
        case .cooldown: return "cooldown"
        case .americanFootball: return "american_football"
        case .baseball: return "baseball"
        case .basketball: return "basketball"
        case .boxing: return "boxing"
        case .climbing: return "climbing"
        case .golf: return "golf"
        case .hockey: return "hockey"
        case .soccer: return "soccer"
        case .tennis: return "tennis"
        case .volleyball: return "volleyball"
        case .waterFitness: return "water_fitness"
        default: return "other"
        }
    }
}
