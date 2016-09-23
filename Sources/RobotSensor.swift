//
//  RobotSensor.swift
//  Robotary
//
//  Created by Matt on 8/17/16.
//

import Foundation

let kSensorPollingInterval = TimeInterval(0.1)
let kMaxFailedSensorReadings = 3
let kMaxFailedUltrasonicSensorReadings = 10

public enum ThresholdRelation {
	case lessThanOrEqualTo
	case greaterThanOrEqualTo
}

extension ThresholdRelation {
	func compare(_ left: Int, _ rhs: Int) -> Bool {
		switch self {
		case .lessThanOrEqualTo:
			return left <= rhs
		case .greaterThanOrEqualTo:
			return left >= rhs
		}
	}

	func compare(_ left: Double, _ rhs: Double) -> Bool {
		switch self {
		case .lessThanOrEqualTo:
			return left <= rhs
		case .greaterThanOrEqualTo:
			return left >= rhs
		}
	}

	func compare(_ left: Float, _ rhs: Float) -> Bool {
		switch self {
		case .lessThanOrEqualTo:
			return left <= rhs
		case .greaterThanOrEqualTo:
			return left >= rhs
		}
	}
}
