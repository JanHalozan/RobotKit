//
//  NXTRobotMotors.swift
//  Robotary
//
//  Created by Matt on 8/16/16.
//

import RobotFoundation

private let kOutputModuleID: UInt32 = 0x00020001

public enum NXTMotorsError: Error {
	case noPorts
	case requiresTwoPorts
	case tooManyPorts
}

/// Represents a combination of the NXT's three output ports.
public struct NXTOutputPorts: OptionSet {
	public let rawValue: UInt8
	public init(rawValue: UInt8) {
		self.rawValue = rawValue
	}

	public static let A = NXTOutputPorts(rawValue: 1)
	public static let B = NXTOutputPorts(rawValue: 2)
	public static let C = NXTOutputPorts(rawValue: 4)
}

/// Represents a single NXT output port.
public enum NXTOutputPort {
	case A, B, C
}

private extension NXTOutputPorts {
	var count: Int {
		var sum = 0
		if contains(.A) {
			sum += 1
		}
		if contains(.B) {
			sum += 1
		}
		if contains(.C) {
			sum += 1
		}
		return sum
	}
}

private extension NXTOutputPort {
	var internalRep: RobotFoundation.NXTOutputPort {
		switch self {
		case .A:
			return .a
		case .B:
			return .b
		case .C:
			return .c
		}
	}
}

/// Represents a set of NXT's motors.
public final class NXTMotors {
	private let robot: NXTRobot
	private let ports: NXTOutputPorts

	fileprivate init(robot: NXTRobot, ports: NXTOutputPorts) {
		self.robot = robot
		self.ports = ports
	}

	/// Begins driving the motors at the specified ports with the given power and turn ratio.
	///
	/// Two ports must be specified in order to run motors in sync with each other given a turn ratio.
	/// This method does not block the caller.
	///
	/// - parameter power: The power in range [-100, 100].
	/// - parameter turnRatio: The turn ratio in range [-100, 100].
	/// - parameter handler: The optional completion handler that indicates whether the operation succeeded.
	public func beginDrive(power: Int, turnRatio: Int, handler: RobotResponseHandler? = nil) throws {
		assert(ports.count == 2)

		let truePower = verboseClamp(power, "power", -100, 100)
		let trueRatio = verboseClamp(turnRatio, "turn ratio", -100, 100)

		func beginOnPort(_ port: RobotFoundation.NXTOutputPort) {
			let command = NXTSetOutputStateCommand(port: port, power: Int8(truePower), outputMode: [.MotorOn, .Brake, .Regulated], regulationMode: .motorSync, turnRatio: Int8(trueRatio), runState: .running, tachoLimit: 0)
			robot.device.enqueueCommand(command) { result in
				assert(Thread.isMainThread)

				switch result {
				case .error:
					handler?(.error)
				case .response:
					handler?(.success)
				}
			}
		}

		if ports.contains(.A) {
			beginOnPort(.a)
		}

		if ports.contains(.B) {
			beginOnPort(.b)
		}

		if ports.contains(.C) {
			beginOnPort(.c)
		}
	}

	/// Stops the motors.
	///
	/// This method returns immediately.
	///
	/// - parameter applyBrakes: If `true`, brakes will be applied; otherwise, the motors will coast to a stop.
	/// - parameter handler: The optional completion handler that indicates whether the operation succeeded.
	public func stop(applyBrakes: Bool, handler: RobotResponseHandler? = nil) {
		func stopOnPort(_ port: RobotFoundation.NXTOutputPort) {
			let command = NXTSetOutputStateCommand(port: port, power: 0, outputMode: applyBrakes ? [.Brake, .Regulated] : [.Regulated], regulationMode: .motorSync, turnRatio: 0, runState: .idle, tachoLimit: 0)
			robot.device.enqueueCommand(command) { result in
				assert(Thread.isMainThread)

				switch result {
				case .error:
					handler?(.error)
				case .response:
					handler?(.success)
				}
			}
		}

		if ports.contains(.A) {
			stopOnPort(.a)
		}

		if ports.contains(.B) {
			stopOnPort(.b)
		}

		if ports.contains(.C) {
			stopOnPort(.c)
		}
	}
}

/// Represents a single NXT motor.
public final class NXTMotor {
	private let robot: NXTRobot
	private let port: NXTOutputPort

	fileprivate init(robot: NXTRobot, port: NXTOutputPort) {
		self.robot = robot
		self.port = port
	}

	/// Begins driving the motor at the specified port with the given power.
	///
	/// This method does not block the caller.
	///
	/// - parameter power: The power in range [-100, 100].
	/// - parameter handler: The optional completion handler that indicates whether the operation succeeded.
	public func beginDrive(power: Int, handler: RobotResponseHandler? = nil) throws {
		let truePower = verboseClamp(power, "power", -100, 100)

		let command = NXTSetOutputStateCommand(port: port.internalRep, power: Int8(truePower), outputMode: [.MotorOn, .Brake, .Regulated], regulationMode: .motorSpeed, turnRatio: 0, runState: .running, tachoLimit: 0)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler?(.error)
			case .response:
				handler?(.success)
			}
		}
	}

	/// Returns the instantaneous speed of the motor.
	///
	/// The returned speed is in range [-100,100], where negative values indicate going in reverse.
	///
	/// - returns: The instantaneous speed, or `nil` if the reading failed.
	public var instantaneousSpeed: Int? {
		let offset = UInt16(port.internalRep.rawValue * 32 + 21)
		let command = NXTReadIOMapCommand(module: kOutputModuleID, offset: offset, bytesToRead: 1)
		var speed: Int?
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// `speed` is already `nil`
				break
			case .response(let response):
				guard let mapResponse = response as? NXTIOMapResponse else {
					// `speed` is already `nil`
					assertionFailure()
					break
				}

				guard mapResponse.contents.count == 1 else {
					// `speed` is already `nil`
					assertionFailure()
					break
				}

				speed = Int(mapResponse.contents.readInt8AtIndex(0))
			}
		}

		robot.device.waitForOperations()

		return speed
	}

	/// Checks whether the motor is overloaded.
	///
	/// - returns: A boolean indicating whether the motor is overloaded, or `nil` if the reading failed.
	public var isOverloaded: Bool? {
		let offset = UInt16(port.internalRep.rawValue * 32 + 27)
		let command = NXTReadIOMapCommand(module: kOutputModuleID, offset: offset, bytesToRead: 1)
		var overloaded: Bool?
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// `overloaded` is already `nil`
				break
			case .response(let response):
				guard let mapResponse = response as? NXTIOMapResponse else {
					// `overloaded` is already `nil`
					assertionFailure()
					break
				}

				guard mapResponse.contents.count == 1 else {
					// `overloaded` is already `nil`
					assertionFailure()
					break
				}

				overloaded = mapResponse.contents.readInt8AtIndex(0) == 1 ? true : false
			}
		}

		robot.device.waitForOperations()

		return overloaded
	}

	/// Stops the motor.
	///
	/// This method returns immediately.
	///
	/// - parameter applyBrakes: If `true`, brakes will be applied; otherwise, the motor will coast to a stop.
	/// - parameter handler: The optional completion handler that indicates whether the operation succeeded.
	public func stop(applyBrakes: Bool, handler: RobotResponseHandler? = nil) {
		let command = NXTSetOutputStateCommand(port: port.internalRep, power: 0, outputMode: applyBrakes ? [.Brake, .Regulated] : [.Regulated], regulationMode: .motorSpeed, turnRatio: 0, runState: .idle, tachoLimit: 0)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler?(.error)
			case .response:
				handler?(.success)
			}
		}
	}
}

public extension NXTRobot {
	/// Provides access to motors at the given ports.
	///
	/// Two ports must be specified.
	///
	/// - parameter ports: The ports of the motors.
	public func motors(atPorts ports: NXTOutputPorts) throws -> NXTMotors {
		guard ports.count == 2 else {
			throw NXTMotorsError.requiresTwoPorts
		}

		return NXTMotors(robot: self, ports: ports)
	}

	/// Provides access to motor at the given port.
	///
	/// - parameter port: The port of the motor.
	public func motor(atPort port: NXTOutputPort) -> NXTMotor {
		return NXTMotor(robot: self, port: port)
	}
}
