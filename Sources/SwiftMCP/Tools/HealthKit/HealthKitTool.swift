//
//  HealthKitTool.swift
//  SwiftMCP
//
//  Created by Atharva Vaidya on 3/20/25.
//

import Foundation
import HealthKit
import CoreLocation

/// A tool that provides access to HealthKit data through the MCP interface
@available(iOS 15, macOS 13.0, *)
public class HealthKitTool: MCPTool {
    public let methodName = "healthKit"
    
    private let healthStore: HKHealthStore
    
    /// Initialize the HealthKit tool
    /// - Throws: MCPError if HealthKit is not available on the device
    public init() throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw MCPError.toolError("HealthKit is not available on this device")
        }
        self.healthStore = HKHealthStore()
    }
    
    /// Handle incoming requests for health data
    /// - Parameters:
    ///   - params: Expected parameters:
    ///     For getData:
    ///       - action: "getData"
    ///       - dataType: String representing the HealthDataType to query
    ///       - timeRange: Optional string specifying the time range (today, yesterday, this_week, last_week, etc.)
    ///       - duration: Optional string specifying a duration (e.g., "P7D" for last 7 days)
    ///     For getWorkouts:
    ///       - action: "getWorkouts"
    ///       - workoutType: Optional string specifying the type of workout to filter by
    ///       - includeRoutes: Optional boolean indicating whether to include route data
    ///       - timeRange/duration: Same as getData
    public func handle(params: [String: Any]) async throws -> [String: Any] {
        guard let action = params["action"] as? String else {
            throw MCPError.invalidParams("Missing 'action' parameter")
        }
        
        switch action {
        case "getData":
            return try await handleGetData(params: params)
        case "getWorkouts":
            return try await handleGetWorkouts(params: params)
        default:
            throw MCPError.invalidParams("Invalid action: \(action)")
        }
    }
    
    /// Handle getData requests
    private func handleGetData(params: [String: Any]) async throws -> [String: Any] {
        // Validate and parse data type
        guard let dataTypeStr = params["dataType"] as? String,
              let dataType = HealthDataType(rawValue: dataTypeStr) else {
            throw MCPError.invalidParams("Invalid or missing dataType parameter")
        }
        
        let timeRange = params["timeRange"] as? String
        let duration = params["duration"] as? String
        
        // Calculate date range
        let (startDate, endDate) = calculateDateRange(timeRange: timeRange, duration: duration)
        
        // Request authorization for the specific data type
        let quantityType = dataType.quantityType
        
        try await healthStore.requestAuthorization(toShare: [], read: [quantityType])
        
        let samples = try await fetchHealthData(
            type: quantityType,
            unit: dataType.unit,
            start: startDate,
            end: endDate
        )
        
        return [
            "dataType": dataType.rawValue,
            "unit": dataType.unit.unitString,
            "samples": samples.map { [
                "value": $0.value,
                "date": ISO8601DateFormatter().string(from: $0.date)
            ]}
        ]
    }
    
    /// Handle getWorkouts requests
    private func handleGetWorkouts(params: [String: Any]) async throws -> [String: Any] {
        let timeRange = params["timeRange"] as? String
        let duration = params["duration"] as? String
        let workoutType = params["workoutType"] as? String
        let includeRoutes = params["includeRoutes"] as? Bool ?? false
        
        // Calculate date range
        let (startDate, endDate) = calculateDateRange(timeRange: timeRange, duration: duration)
        
        // Request authorization for workouts and routes if needed
        var typesToRead: Set<HKObjectType> = [HKObjectType.workoutType()]
        if includeRoutes {
            typesToRead.insert(HKSeriesType.workoutRoute())
        }
        
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        
        // Create workout predicate
        var predicates: [NSPredicate] = []
        
        if let startDate = startDate {
            predicates.append(HKQuery.predicateForSamples(withStart: startDate, end: endDate))
        }
        
        if let workoutType = workoutType,
           let activityType = HKWorkoutActivityType.supported.first(where: { $0.name == workoutType }) {
            predicates.append(HKQuery.predicateForWorkouts(with: activityType))
        }
        
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        // Fetch workouts
        let workouts = try await fetchWorkouts(predicate: predicate)
        
        // If routes are requested, fetch them for each workout
        var workoutSamples: [WorkoutSample] = []
        if includeRoutes {
            for workout in workouts {
                if let route = try? await fetchWorkoutRoute(for: workout) {
                    workoutSamples.append(WorkoutSample(from: workout, route: route))
                } else {
                    workoutSamples.append(WorkoutSample(from: workout))
                }
            }
        } else {
            workoutSamples = workouts.map { WorkoutSample(from: $0) }
        }
        
        // Convert workouts to dictionary format
        return [
            "workouts": workoutSamples.map { workout in
                var workoutDict: [String: Any] = [
                    "type": workout.workoutActivityType,
                    "startDate": ISO8601DateFormatter().string(from: workout.startDate),
                    "endDate": ISO8601DateFormatter().string(from: workout.endDate),
                    "duration": workout.duration
                ]
                
                if let distance = workout.totalDistance {
                    workoutDict["distance"] = distance
                }
                
                if let calories = workout.totalEnergyBurned {
                    workoutDict["calories"] = calories
                }
                
                if let route = workout.route {
                    workoutDict["route"] = route.map { coordinate in
                        [
                            "latitude": coordinate.latitude,
                            "longitude": coordinate.longitude,
                            "altitude": coordinate.altitude,
                            "timestamp": ISO8601DateFormatter().string(from: coordinate.timestamp)
                        ]
                    }
                }
                
                return workoutDict
            }
        ]
    }
    
    /// Fetch workouts matching the given predicate
    private func fetchWorkouts(predicate: NSPredicate) async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }
            
            healthStore.execute(query)
        }
    }

    private func fetchWorkoutRoute(for workout: HKWorkout) async throws -> [CLLocation] {
        // First, get the route object
        let routeType = HKSeriesType.workoutRoute()
        let routePredicate = HKQuery.predicateForObjects(from: workout)
        
        let routes = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkoutRoute], Error>) in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: routePredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: samples as? [HKWorkoutRoute] ?? [])
            }
            
            healthStore.execute(query)
        }
        
        guard let route = routes.first else {
            return []
        }
        
        // Then, get the route data
        let locationStore = LocationStore()
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKWorkoutRouteQuery(route: route) { query, newLocations, done, error in
                Task {
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    if let newLocations = newLocations {
                        await locationStore.append(newLocations)
                    }
                    
                    if done {
                        let allLocations = await locationStore.getAllLocations()
                        continuation.resume(returning: allLocations)
                    }
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Calculate the date range based on the provided time range or duration
    private func calculateDateRange(timeRange: String?, duration: String?) -> (start: Date?, end: Date) {
        let now = Date()
        var startDate: Date?
        let endDate = now
        
        if let timeRange = timeRange?.lowercased() {
            switch timeRange {
            case "today":
                startDate = Calendar.current.startOfDay(for: now)
            case "yesterday":
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
                startDate = Calendar.current.startOfDay(for: yesterday)
            case "this_week":
                startDate = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
            case "last_week":
                if let thisWeekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) {
                    startDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)
                }
            case "this_month":
                startDate = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now))
            case "last_month":
                if let thisMonthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now)) {
                    startDate = Calendar.current.date(byAdding: .month, value: -1, to: thisMonthStart)
                }
            default:
                break
            }
        } else if let duration = duration {
            // Parse ISO 8601 duration format (e.g., P1D, P7D, P1M, P1Y)
            if duration.hasPrefix("P"),
               let value = Int(duration.dropFirst().dropLast()),
               let unit = duration.last {
                let calendarUnit: Calendar.Component
                switch unit {
                case "D": calendarUnit = .day
                case "W": calendarUnit = .weekOfYear
                case "M": calendarUnit = .month
                case "Y": calendarUnit = .year
                default: calendarUnit = .day
                }
                startDate = Calendar.current.date(byAdding: calendarUnit, value: -value, to: now)
            }
        }
        
        return (startDate, endDate)
    }
    
    /// Fetch health data for the specified parameters
    private func fetchHealthData(type: HKQuantityType, unit: HKUnit, start: Date?, end: Date) async throws -> [HealthDataSample] {
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        
        if type.aggregationStyle == .discreteArithmetic {
            return try await fetchDiscreteData(type: type, unit: unit, predicate: predicate)
        } else {
            return try await fetchCumulativeData(type: type, unit: unit, predicate: predicate)
        }
    }
    
    /// Fetch discrete health data (e.g., heart rate, step count)
    private func fetchDiscreteData(type: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async throws -> [HealthDataSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let healthSamples = (samples as? [HKQuantitySample])?.map { sample in
                    HealthDataSample(quantity: sample.quantity, unit: unit, date: sample.endDate)
                } ?? []
                
                continuation.resume(returning: healthSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch cumulative health data (e.g., distance, energy burned)
    private func fetchCumulativeData(type: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async throws -> [HealthDataSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let statistics = statistics,
                      let sum = statistics.sumQuantity() else {
                    continuation.resume(returning: [])
                    return
                }
                
                let sample = HealthDataSample(quantity: sum, unit: unit, date: Date())
                continuation.resume(returning: [sample])
            }
            
            healthStore.execute(query)
        }
    }
}

/// Fetch route data for a workout
fileprivate actor LocationStore {
    private var locations: [CLLocation] = []
    
    func append(_ newLocations: [CLLocation]) {
        locations.append(contentsOf: newLocations)
    }
    
    func getAllLocations() -> [CLLocation] {
        return locations
    }
}
