//
//  HealthKitTool.swift
//  SwiftMCP
//
//  Created by Atharva Vaidya on 3/20/25.
//

import Foundation
import HealthKit


/// A tool that provides access to HealthKit data through the MCP interface
@available(iOS 15, macOS 13.0, *)
public class HealthKitTool: MCPTool {
    public let methodName = "healthKit/getSteps"
    
    private let healthStore: HKHealthStore
    
    /// Initialize the HealthKit tool
    /// - Throws: MCPError if HealthKit is not available on the device
    public init() throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw MCPError.toolError("HealthKit is not available on this device")
        }
        self.healthStore = HKHealthStore()
    }
    
    /// Handle incoming requests for step count data
    /// - Parameters:
    ///   - params: Expected parameters:
    ///     - startDate: ISO8601 string representing the start date (optional, defaults to start of today)
    ///     - endDate: ISO8601 string representing the end date (optional, defaults to now)
    ///   - completion: Called with the step count result or an error
    public func handle(params: [String: Any], completion: @escaping (Result<Any, MCPError>) -> Void) {
        // Parse dates from parameters
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        
        let dateFormatter = ISO8601DateFormatter()
        
        let startDate = params["startDate"].flatMap { dateStr in
            (dateStr as? String).flatMap { dateFormatter.date(from: $0) }
        } ?? startOfToday
        
        let endDate = params["endDate"].flatMap { dateStr in
            (dateStr as? String).flatMap { dateFormatter.date(from: $0) }
        } ?? now
        
        // Request authorization for step count
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        healthStore.requestAuthorization(toShare: nil, read: [stepType]) { [weak self] success, error in
            if let error = error {
                completion(.failure(.toolError("HealthKit error: \(error.localizedDescription)")))
                return
            }
            
            guard success else {
                completion(.failure(.toolError("HealthKit authorization denied")))
                return
            }
            
            self?.queryStepCount(start: startDate, end: endDate, completion: completion)
        }
    }
    
    /// Query HealthKit for step count data
    private func queryStepCount(start: Date, end: Date, completion: @escaping (Result<Any, MCPError>) -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType,
                                    quantitySamplePredicate: predicate,
                                    options: .cumulativeSum) { _, statistics, error in
            if let error = error {
                completion(.failure(.toolError("HealthKit error: \(error.localizedDescription)")))
                return
            }
            
            guard let sum = statistics?.sumQuantity() else {
                completion(.success(["steps": 0]))
                return
            }
            
            let steps = sum.doubleValue(for: HKUnit.count())
            completion(.success([
                "steps": Int(steps),
                "startDate": ISO8601DateFormatter().string(from: start),
                "endDate": ISO8601DateFormatter().string(from: end)
            ]))
        }
        
        healthStore.execute(query)
    }
} 
