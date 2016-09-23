//
//  Utilities.swift
//  Robotary
//
//  Created by Matt on 2/1/16.
//

import Foundation

public typealias RobotResponseHandler = (RobotResponse) -> ()

/// Generates a random integer in the given range.
public func randomInt(inRange range: Range<Int>) -> Int {
	let length = range.count
	assert(length >= 0)

	return range.lowerBound + Int(arc4random_uniform(UInt32(length)))
}

/// Blocks the caller for the given amount of milliseconds.
///
/// - parameter milliseconds: The duration in milliseconds.
public func wait(milliseconds: Int) {
	let s = TimeInterval(milliseconds) / 1000
	let endDate = Date(timeIntervalSinceNow: s)

	while Date() < endDate {
		RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: endDate)
	}
}

/// Blocks the caller for the given amount of seconds.
///
/// - parameter seconds: The duration in seconds.
public func wait(seconds: Int) {
	wait(milliseconds: seconds * 1000)
}

/// Blocks the caller until the program is stopped.
///
/// This is useful for event-driven programs.
public func waitIndefinitely() {
	while true {
		RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: .distantFuture)
	}
}

/// Exits the program immediately.
public func exit() -> Never  {
	exit(0)
}

extension EV3Robot {
	/// Blocks the caller until all pending operations finish processing.
	public func waitForPipeline() {
		device.waitForOperations()
	}
}

extension NXTRobot {
	/// Blocks the caller until all pending operations finish processing.
	public func waitForPipeline() {
		device.waitForOperations()
	}
}

func verboseClamp(_ value: Int, _ label: String, _ minValue: Int, _ maxValue: Int) -> Int {
	var trueValue = value

	if trueValue < minValue {
		debugPrint("The \(label) of \(value) is smaller than the minimum allowed value of \(minValue). Using \(minValue).")
		trueValue = minValue
	}

	if trueValue > maxValue {
		debugPrint("The \(label) of \(value) is larger than the maximum allowed value of \(maxValue). Using \(maxValue).")
		trueValue = maxValue
	}

	return trueValue
}
