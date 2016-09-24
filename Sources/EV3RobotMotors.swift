//
//  EV3RobotMotors.swift
//  Robotary
//
//  Created by Matt on 2/13/16.
//

import Foundation
import RobotFoundation

public enum EV3MotorsError: Error {
	case tooManyMotors
}

/// Represents a combination of the EV3's four output ports.
public struct EV3OutputPorts: OptionSet {
	public let rawValue: UInt8
	public init(rawValue: UInt8) {
		self.rawValue = rawValue
	}

	public static let A = EV3OutputPorts(rawValue: 1)
	public static let B = EV3OutputPorts(rawValue: 2)
	public static let C = EV3OutputPorts(rawValue: 4)
	public static let D = EV3OutputPorts(rawValue: 8)
}

private extension EV3OutputPorts {
	var internalRep: EV3OutputPortOptions {
		return EV3OutputPortOptions(rawValue: rawValue)
	}

	var internalSingularRep: EV3OutputPort {
		if contains(.A) {
			return .a
		} else if contains(.B) {
			return .b
		} else if contains(.C) {
			return .c
		} else if contains(.D) {
			return .d
		} else {
			fatalError()
		}
	}

	var hasExactlyOne: Bool {
		let possibilities: [EV3OutputPorts] = [.A, .B, .C, .D]
		var count = 0
		for value in possibilities where contains(value) {
			count += 1
		}
		return count == 1
	}
}

/// Represents a set of EV3's motors.
public final class EV3Motors {
	private let robot: EV3Robot
	private let ports: EV3OutputPorts

	fileprivate init(robot: EV3Robot, ports: EV3OutputPorts) {
		self.robot = robot
		self.ports = ports
	}

	/// Begins driving the motors with the given speed and turn ratio for the given duration.
	///
	/// This method returns after the drive begins.
	///
	/// - parameter duration: The duration of the drive in milliseconds.
	/// - parameter speed: The speed in range [-100, 100]. Negative values indicate going in reverse.
	/// - parameter turnRatio: The left/right turn ratio in range [-200, 200].
	/// - parameter brakeWhenDone: If `True`, brakes should be applied after the drive; otherwise, the motors will coast to a stop.
	/// - parameter handler: The optional completion handler that indicates whether the operation succeeded.
	public func beginDrive(forDuration duration: Int, speed: Int, turnRatio: Int, brakeWhenDone: Bool, handler: RobotResponseHandler? = nil) {
		let clampedSpeed = verboseClamp(speed, "speed", -100, 100)
		let clampedTurnRatio = verboseClamp(turnRatio, "turn ratio", -200, 200)

		let command = EV3TimedDriveCommand(ports: ports.internalRep, speed: Int8(clampedSpeed), turnRatio: Int16(clampedTurnRatio), duration: UInt32(duration), shouldBrakeWhenDone: brakeWhenDone)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler?(.error)
			case .responseGroup:
				handler?(.success)
			}
		}
	}

	/// Begins driving the motors with the given speed and turn ratio for the given angle (in degrees).
	///
	/// For example, to drive for one full wheel turn, an angle of 360 should be passed.
	/// If the circumference of the wheel is known, the angle necessary to drive a given distance can be computed.
	///
	/// This method returns after the drive begins.
	///
	/// - parameter angle: The angle (in degrees).
	/// - parameter speed: The speed in range [-100, 100]. Negative values indicate going in reverse.
	/// - parameter turnRatio: The left/right turn ratio in range [-200, 200].
	/// - parameter brakeWhenDone: If `True`, brakes should be applied after the drive; otherwise, the motors will coast to a stop.
	/// - parameter handler: The optional completion handler that indicates whether the operation succeeded.
	public func beginDrive(forAngle angle: Int, speed: Int, turnRatio: Int, brakeWhenDone: Bool, handler: RobotResponseHandler? = nil) {
		let clampedSpeed = verboseClamp(speed, "speed", -100, 100)
		let clampedTurnRatio = verboseClamp(turnRatio, "turn ratio", -200, 200)

		let command = EV3AngledDriveCommand(ports: ports.internalRep, speed: Int8(clampedSpeed), turnRatio: Int16(clampedTurnRatio), angle: UInt32(angle), shouldBrakeWhenDone: brakeWhenDone)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler?(.error)
			case .responseGroup:
				handler?(.success)
			}
		}
	}

	/// Tests whether the motors are busy.
	///
	/// If you want to wait for motors to become available, using the `waitForMotors` method is more efficient than repeatedly polling `busy`.
	///
	/// - returns: `true` if motors are busy and `false` if they are not. `nil` is returned if the state cannot be determined.
	public var isBusy: Bool? {
		let command = EV3TestOutputCommand(ports: ports.internalRep)
		var boolResult: Bool?
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// `boolResult` is already `nil`
				break
			case .responseGroup(let responseGroup):
				guard let booleanResponse = responseGroup.firstResponse as? EV3BooleanResponse else {
					assertionFailure()
					break
				}

				boolResult = booleanResponse.value
			}
		}

		robot.waitForPipeline()

		return boolResult
	}

	/// Runs the motors with the given speed.
	///
	/// This method returns after the command finishes processing.
	///
	/// - parameter speed: The speed in range [-100, 100]. Negative values indicate going in reverse.
	/// - parameter handler: The optional completion handler that indicates whether the operation succeeded.
	public func setSpeed(_ speed: Int, handler: RobotResponseHandler? = nil) {
		var goOn = false
		let clampedSpeed = verboseClamp(speed, "speed", -100, 100)

		let speedCommand = EV3SetMotorSpeedCommand(ports: ports.internalRep, speed: Int8(clampedSpeed))
		robot.device.enqueueCommand(speedCommand) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler?(.error)
			case .responseGroup:
				goOn = true
			}
		}

		robot.waitForPipeline()

		guard goOn else {
			return
		}

		let command = EV3StartMotorCommand(ports: ports.internalRep)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler?(.error)
			case .responseGroup:
				handler?(.success)
			}
		}

		robot.waitForPipeline()
	}

	/// Sets the speed of the motors with precise scheduling of the ramp up, constant, and ramp down phases.
	/// This is an advanced operation.
	///
	/// Calling this method with times that are not monotonically-increasing will throw an error.
	///
	/// - parameter speed: The speed in range [-100, 100]. Negative values indicate going in reverse.
	/// - parameter rampUpDuration: The duration of the ramp up phase (in milliseconds).
	/// - parameter constantDuration: The duration of the constant phase (in milliseconds).
	/// - parameter rampDownDuration: The duration of the ramp down phase (in milliseconds).
	/// - parameter brakeWhenDone: Indicates whether the motors should brake or coast to a stop after the ramp down phase.
	/// - parameter handler: The optional completion handler that indicates whether the operation succeeded.
	public func scheduleSpeed(_ speed: Int, rampUpDuration: Int, constantDuration: Int, rampDownDuration: Int, brakeWhenDone: Bool, handler: RobotResponseHandler? = nil) {
		let clampedSpeed = verboseClamp(speed, "speed", -100, 100)
		let command = EV3ScheduleSpeedCommand(ports: ports.internalRep, speed: Int8(clampedSpeed), time1: UInt32(rampUpDuration), time2: UInt32(constantDuration), time3: UInt32(rampDownDuration), stopType: brakeWhenDone ? .brake : .coast)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler?(.error)
			case .responseGroup:
				handler?(.success)
			}
		}

		robot.waitForPipeline()
	}

	/// Runs the motors with the given power.
	///
	/// This method returns after the command finishes processing.
	///
	/// - parameter power: The power in range [-100, 100]. Negative values indicate going in reverse.
	/// - parameter handler: The optional completion handler that indicates whether the operation succeeded.
	public func setPower(_ power: Int, handler: RobotResponseHandler? = nil) {
		var goOn = false
		let clampedPower = verboseClamp(power, "power", -100, 100)

		let powerCommand = EV3SetMotorPowerCommand(ports: ports.internalRep, power: Int8(clampedPower))
		robot.device.enqueueCommand(powerCommand) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler?(.error)
			case .responseGroup:
				goOn = true
			}
		}

		robot.waitForPipeline()

		guard goOn else {
			return
		}

		let command = EV3StartMotorCommand(ports: ports.internalRep)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler?(.error)
			case .responseGroup:
				handler?(.success)
			}
		}

		robot.waitForPipeline()
	}

	/// Sets the power of the motors with precise scheduling of the ramp up, constant, and ramp down phases.
	/// This is an advanced operation.
	///
	/// Calling this method with times that are not monotonically-increasing will throw an error.
	///
	/// - parameter power: The power in range [-100, 100]. Negative values indicate going in reverse.
	/// - parameter rampUpDuration: The duration of the ramp up phase (in milliseconds).
	/// - parameter constantDuration: The duration of the constant phase (in milliseconds).
	/// - parameter rampDownDuration: The duration of the ramp down phase (in milliseconds).
	/// - parameter brakeWhenDone: Indicates whether the motors should brake or coast to a stop after the ramp down phase.
	/// - parameter handler: The optional completion handler that indicates whether the operation succeeded.
	public func schedulePower(_ power: Int, rampUpDuration: Int, constantDuration: Int, rampDownDuration: Int, brakeWhenDone: Bool, handler: RobotResponseHandler? = nil) {
		let clampedPower = verboseClamp(power, "power", -100, 100)
		let command = EV3SchedulePowerCommand(ports: ports.internalRep, power: Int8(clampedPower), time1: UInt32(rampUpDuration), time2: UInt32(constantDuration), time3: UInt32(rampDownDuration), stopType: brakeWhenDone ? .brake : .coast)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler?(.error)
			case .responseGroup:
				handler?(.success)
			}
		}

		robot.waitForPipeline()
	}

	/// Stops the motors.
	///
	/// This method returns immediately.
	///
	/// - parameter applyBrakes: If `true`, brakes will be applied; otherwise, the motors will coast to a stop.
	/// - parameter handler: The optional completion handler that indicates whether the operation succeeded.
	public func stop(applyBrakes: Bool, handler: RobotResponseHandler? = nil) {
		let command = EV3StopMotorCommand(port: ports.internalRep, stopType: applyBrakes ? .brake : .coast)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler?(.error)
			case .responseGroup:
				handler?(.success)
			}
		}
	}

	/// Waits until the motors are no longer busy.
	///
	/// Using this method is more efficient than repeatedly polling `busy`.
	///
	/// - returns: `success` if the operation completed successfully.
	public func waitUntilReady() -> RobotResponse {
		var response = RobotResponse.error

		let command = EV3OutputReadyCommand(ports: ports.internalRep)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// Error is already set.
				break
			case .responseGroup:
				response = .success
			}
		}

		robot.waitForPipeline()

		return response
	}

	/// Returns the instantaneous speed of the motor.
	///
	/// Note that this call can only be made for an `EV3Motors` set containing exactly one motor.
	///
	/// The returned speed is in range [-100,100], where negative values indicate going in reverse.
	///
	/// - returns: The instantaneous speed, or `nil` if the reading failed.
	public func readInstantaneousSpeed() throws -> Int? {
		guard ports.hasExactlyOne else {
			throw EV3MotorsError.tooManyMotors
		}

		let command = EV3ReadOutputCommand(port: ports.internalSingularRep)
		var speed: Int?
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// `speed` is already `nil`
				break
			case .responseGroup(let responseGroup):
				guard let outputResponse = responseGroup.firstResponse as? EV3OutputSpeedTachoResponse else {
					assertionFailure()
					break
				}

				speed = Int(outputResponse.speed)
			}
		}

		robot.waitForPipeline()

		return speed
	}
}

public extension EV3Robot {
	/// Provides access to motors at the given ports.
	///
	/// - parameter ports: The ports of the motors.
	public func motors(atPorts ports: EV3OutputPorts) -> EV3Motors {
		return EV3Motors(robot: self, ports: ports)
	}
}
