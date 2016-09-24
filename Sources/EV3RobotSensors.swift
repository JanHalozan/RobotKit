//
//  EV3RobotSensors.swift
//  Robotary
//
//  Created by Matt on 6/25/16.
//

import RobotFoundation

/// Represents the EV3's four input ports.
public enum EV3InputPort {
	case one, two, three, four
}

private extension EV3InputPort {
	var internalRep: EV3RawInputPort {
		switch self {
		case .one:
			return .one
		case .two:
			return .two
		case .three:
			return .three
		case .four:
			return .four
		}
	}
}

/// Represents an EV3 sensor.
public class EV3Sensor {
	fileprivate let robot: EV3Robot
	fileprivate let port: EV3InputPort

	fileprivate init(robot: EV3Robot, port: EV3InputPort) {
		self.robot = robot
		self.port = port
	}

	/// Returns the name of the sensor.
	///
	/// Note: this name is meant to be used for diagnostic purposes and is not intended to be displayed in user interfaces.
	///
	/// - returns: The name of the sensor, or `nil` if the reading failed.
	public var name: String? {
		let command = EV3GetSensorNameCommand(port: port.internalRep)
		var name: String?
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// `name` is already `nil`
				break
			case .responseGroup(let group):
				guard let stringResponse = group.firstResponse as? EV3StringResponse else {
					assertionFailure()
					break
				}

				name = stringResponse.string
			}
		}
		robot.waitForPipeline()
		return name
	}
}

/// Represents an EV3 touch sensor.
public final class EV3TouchSensor: EV3Sensor {
	/// Represents the current state of the touch sensor.
	public enum State {
		case pressed
		case released
	}

	/// Returns the current state of the touch sensor. This method blocks the caller until a response has been received.
	///
	/// - returns: The state of the touch sensor, or `nil` if the state cannot be determined.
	public var state: State? {
		var resultState: State?
		let command = EV3ReadTouchSensorCommand(port: port.internalRep)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// `resultState` is already `nil`
				break
			case .responseGroup(let group):
				guard let response = group.firstResponse as? EV3BooleanSensorResponse else {
					assertionFailure()
					break
				}

				if let value = response.value {
					if value {
						resultState = .pressed
					} else {
						resultState = .released
					}
				}

				// else `resultState` is already `nil`
			}
		}
		robot.waitForPipeline()
		return resultState
	}

	/// Asynchronously reads the current state of the touch sensor and invokes the given handler.
	///
	/// - parameter handler: The handler to invoke when the state is read.
	public func readState(_ handler: @escaping (State?) -> ()) {
		let command = EV3ReadTouchSensorCommand(port: port.internalRep)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler(nil)
			case .responseGroup(let group):
				guard let response = group.firstResponse as? EV3BooleanSensorResponse else {
					handler(nil)
					assertionFailure()
					break
				}

				if let value = response.value {
					if value {
						handler(.pressed)
					} else {
						handler(.released)
					}
				} else {
					handler(nil)
				}
			}
		}
	}

	/// Blocks the caller until the touch sensor is in the given state.
	///
	/// If reading the state fails three times, this method returns with an error code to prevent infinite blocking.
	///
	/// - parameter state: The touch sensor state to wait for.
	/// - returns: `success` if the operation completed successfully.
	public func waitUntil(_ state: State) -> RobotResponse {
		var lastState = State.released
		var consecutiveFailures = 0
		repeat {
			let command = EV3ReadTouchSensorCommand(port: port.internalRep)
			robot.device.enqueueCommand(command) { result in
				assert(Thread.isMainThread)

				switch result {
				case .error:
					consecutiveFailures += 1
				case .responseGroup(let group):
					guard let response = group.firstResponse as? EV3BooleanSensorResponse else {
						consecutiveFailures += 1
						assertionFailure()
						break
					}

					guard let value = response.value else {
						consecutiveFailures += 1
						break
					}

					consecutiveFailures = 0

					if value {
						lastState = .pressed
					} else {
						lastState = .released
					}
				}
			}

			robot.waitForPipeline()

			// Try again after the polling interval.
			Thread.sleep(forTimeInterval: kSensorPollingInterval)
		} while (consecutiveFailures != kMaxFailedSensorReadings && lastState != state)

		return consecutiveFailures == kMaxFailedSensorReadings ? .error : .success
	}

	/// Asynchronously notifies the caller when the touch sensor enters the given state.
	///
	/// If reading the state fails three times, the handler is invoked with an error code to prevent infinite waiting.
	///
	/// - parameter state: The touch sensor state to wait for.
	/// - parameter handler: The handler to invoke when the state matches the given state.
	public func notifyOn(_ state: State, handler: @escaping RobotResponseHandler) {
		notifyOn(state, consecutiveFailures: 0, handler: handler)
	}

	private func notifyOn(_ state: State, consecutiveFailures: Int, handler: @escaping RobotResponseHandler) {
		let command = EV3ReadTouchSensorCommand(port: port.internalRep)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			func handleLocalError() {
				// This is the 3rd failure.
				if consecutiveFailures == kMaxFailedSensorReadings - 1 {
					handler(.error)
					return
				}

				Timer.scheduledTimerWithTimeInterval(kSensorPollingInterval) {
					self.notifyOn(state, consecutiveFailures: consecutiveFailures + 1, handler: handler)
				}
			}

			switch result {
			case .error:
				handleLocalError()
			case .responseGroup(let group):
				// If this fails, try again after the polling interval.
				guard let response = group.firstResponse as? EV3BooleanSensorResponse else {
					handleLocalError()
					assertionFailure()
					break
				}

				guard let value = response.value else {
					handleLocalError()
					break
				}

				if value && state == .pressed {
					handler(.success)
					return
				} else if !value && state == .released {
					handler(.success)
					return
				}

				Timer.scheduledTimerWithTimeInterval(kSensorPollingInterval) {
					self.notifyOn(state, consecutiveFailures: 0, handler: handler)
				}
			}
		}
	}
}

private extension EV3ReadLightType {
	init(mode: EV3LightSensor.Mode) {
		switch mode {
		case .ambient:
			self = .ambient
		case .reflected:
			self = .reflected
		}
	}
}

private extension EV3LightSensor.Color {
	init(sensorColor: EV3SensorColor) {
		switch sensorColor {
		case .black:
			self = .black
		case .blue:
			self = .blue
		case .brown:
			self = .brown
		case .green:
			self = .green
		case .none:
			self = .none
		case .red:
			self = .red
		case .white:
			self = .white
		case .yellow:
			self = .yellow
		}
	}
}

/// Represents an EV3 light sensor.
public final class EV3LightSensor: EV3Sensor {
	/// Represents the type of light the EV3 light sensor can read.
	public enum Mode {
		case reflected
		case ambient
	}

	/// Represents one of the fixed color values the EV3 light sensor can read.
	public enum Color {
		case none, black, blue, green, yellow, red, white, brown
	}

	/// Returns the current amount of light (as a percent) from the light sensor. This method blocks the caller until a response has been received.
	///
	/// - parameter mode: Denotes whether ambient or reflected light is being sensed.
	/// - returns: The amount of light, or `nil` if the value cannot be determined.
	public func light(forMode mode: Mode) -> Int? {
		var lightResult: Int?
		let command = EV3ReadLightCommand(port: port.internalRep, lightType: EV3ReadLightType(mode: mode))
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// `lightResult` is already `nil`
				break
			case .responseGroup(let group):
				guard let response = group.firstResponse as? EV3PercentByteResponse else {
					assertionFailure()
					break
				}

				guard let percent = response.percent else {
					// `lightResult` is already `nil`
					break
				}

				lightResult = Int(percent)
			}
		}
		robot.waitForPipeline()
		return lightResult
	}

	/// Returns the current color from the light sensor. Accessing this value blocks the caller until a response has been received.
	///
	/// - returns: The color constant, or `nil` if the value cannot be determined.
	public var color: Color? {
		var color: Color?
		let command = EV3ReadColorCommand(port: port.internalRep)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// `color` is already `nil`
				break
			case .responseGroup(let group):
				guard let response = group.firstResponse as? EV3ColorResponse else {
					assertionFailure()
					break
				}

				color = Color(sensorColor: response.color)
			}
		}
		robot.waitForPipeline()
		return color
	}

	/// Asynchronously reads the amount of light (as a percent) with the light sensor and invokes the given handler.
	///
	/// - parameter mode: Denotes whether ambient or reflected light is being sensed.
	/// - parameter handler: The handler to invoke when the state is read.
	public func readLight(mode: Mode, handler: @escaping (Int?) -> ()) {
		let command = EV3ReadLightCommand(port: port.internalRep, lightType: EV3ReadLightType(mode: mode))
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler(nil)
			case .responseGroup(let group):
				guard let response = group.firstResponse as? EV3PercentByteResponse else {
					handler(nil)
					assertionFailure()
					return
				}

				guard let percent = response.percent else {
					handler(nil)
					return
				}

				handler(Int(percent))
			}
		}
	}

	/// Asynchronously reads the color with the light sensor and invokes the given handler.
	///
	/// - parameter handler: The handler to invoke when the color is read.
	public func readColor(_ handler: @escaping (Color?) -> ()) {
		let command = EV3ReadColorCommand(port: port.internalRep)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler(nil)
			case .responseGroup(let group):
				guard let response = group.firstResponse as? EV3ColorResponse else {
					handler(nil)
					assertionFailure()
					return
				}

				handler(Color(sensorColor: response.color))
			}
		}
	}

	/// Blocks the caller until the light sensor falls or exceeds a given light threshold.
	///
	/// If reading the light value fails three times, this method returns with an error code to prevent infinite blocking.
	///
	/// - parameter relation: The relationship between new light values and the threshold.
	/// - parameter threshold: The threshold.
	/// - parameter mode: Denotes whether ambient or reflected light is being sensed.
	/// - returns: `success` if the operation completed successfully.
	public func waitUntilLightIs(_ relation: ThresholdRelation, threshold: Int, forMode mode: Mode) -> RobotResponse {
		var lastValue = 0
		var consecutiveFailures = 0
		repeat {
			let command = EV3ReadLightCommand(port: port.internalRep, lightType: EV3ReadLightType(mode: mode))
			robot.device.enqueueCommand(command) { result in
				assert(Thread.isMainThread)

				switch result {
				case .error:
					consecutiveFailures += 1
				case .responseGroup(let group):
					guard let response = group.firstResponse as? EV3PercentByteResponse else {
						consecutiveFailures += 1
						assertionFailure()
						break
					}

					guard let percent = response.percent else {
						consecutiveFailures += 1
						break
					}

					consecutiveFailures = 0
					lastValue = Int(percent)
				}
			}

			robot.waitForPipeline()

			// Try again after the polling interval.
			Thread.sleep(forTimeInterval: kSensorPollingInterval)
		} while (consecutiveFailures != kMaxFailedSensorReadings && !relation.compare(lastValue, threshold))

		return consecutiveFailures == kMaxFailedSensorReadings ? .error : .success
	}

	/// Blocks the caller until the light sensor reads the given color.
	///
	/// If reading the color value fails three times, this method returns with an error code to prevent infinite blocking.
	/// - parameter color: The color to wait for.
	/// - returns: `success` if the operation completed successfully.
	public func waitUntilColorIs(_ color: Color) -> RobotResponse {
		var lastColor = Color.none
		var consecutiveFailures = 3
		repeat {
			let command = EV3ReadColorCommand(port: port.internalRep)
			robot.device.enqueueCommand(command) { result in
				assert(Thread.isMainThread)

				switch result {
				case .error:
					consecutiveFailures += 1
				case .responseGroup(let group):
					guard let response = group.firstResponse as? EV3ColorResponse else {
						consecutiveFailures += 1
						assertionFailure()
						break
					}

					consecutiveFailures = 0
					lastColor = Color(sensorColor: response.color)
				}
			}

			robot.waitForPipeline()

			// Try again after the polling interval.
			Thread.sleep(forTimeInterval: kSensorPollingInterval)
		} while (consecutiveFailures != kMaxFailedSensorReadings && lastColor != color)

		return consecutiveFailures == kMaxFailedSensorReadings ? .error : .success
	}

	/// Asynchronously notifies the caller when the light sensor falls or exceeds a given light threshold.
	///
	/// If reading the light value fails three times, the handler is invoked with an error code to prevent infinite waiting.
	///
	/// - parameter relation: The relationship between new light values and the threshold.
	/// - parameter threshold: The threshold.
	/// - parameter mode: Denotes whether ambient or reflected light is being sensed.
	/// - parameter handler: The handler to invoke when the condition is met.
	public func notifyWhenLightIs(_ relation: ThresholdRelation, threshold: Int, forMode mode: Mode, handler: @escaping RobotResponseHandler) {
		notifyWhenLightIs(relation, threshold: threshold, forMode: mode, consecutiveFailures: 0, handler: handler)
	}

	private func notifyWhenLightIs(_ relation: ThresholdRelation, threshold: Int, forMode mode: Mode, consecutiveFailures: Int, handler: @escaping RobotResponseHandler) {
		let command = EV3ReadLightCommand(port: port.internalRep, lightType: EV3ReadLightType(mode: mode))
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			func handleLocalError() {
				// This is the 3rd failure.
				if consecutiveFailures == kMaxFailedSensorReadings - 1 {
					handler(.error)
					return
				}

				Timer.scheduledTimerWithTimeInterval(kSensorPollingInterval) {
					self.notifyWhenLightIs(relation, threshold: threshold, forMode: mode, consecutiveFailures: consecutiveFailures + 1, handler: handler)
				}
			}

			switch result {
			case .error:
				handleLocalError()
			case .responseGroup(let group):
				guard let response = group.firstResponse as? EV3PercentByteResponse else {
					handleLocalError()
					assertionFailure()
					break
				}

				guard let percent = response.percent else {
					handleLocalError()
					break
				}

				if relation.compare(Int(percent), threshold) {
					handler(.success)
					return
				}

				Timer.scheduledTimerWithTimeInterval(kSensorPollingInterval) {
					self.notifyWhenLightIs(relation, threshold: threshold, forMode: mode, consecutiveFailures: 0, handler: handler)
				}
			}
		}
	}

	/// Asynchronously notifies the caller when the light sensor reads the given color.
	///
	/// If reading the color value fails three times, the handler is invoked with an error code to prevent infinite waiting.
	///
	/// - parameter color: The color to wait for.
	/// - parameter handler: The handler to invoke when the color matches the given color.
	public func notifyWhenColorIs(_ color: Color, handler: @escaping RobotResponseHandler) {
		notifyWhenColorIs(color, consecutiveFailures: 0, handler: handler)
	}

	private func notifyWhenColorIs(_ color: Color, consecutiveFailures: Int, handler: @escaping RobotResponseHandler) {
		let command = EV3ReadColorCommand(port: port.internalRep)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			func handleLocalError() {
				// This is the 3rd failure.
				if consecutiveFailures == kMaxFailedSensorReadings - 1 {
					handler(.error)
					return
				}

				Timer.scheduledTimerWithTimeInterval(kSensorPollingInterval) {
					self.notifyWhenColorIs(color, consecutiveFailures: consecutiveFailures + 1, handler: handler)
				}
			}

			switch result {
			case .error:
				handleLocalError()
			case .responseGroup(let group):
				guard let response = group.firstResponse as? EV3ColorResponse else {
					handleLocalError()
					assertionFailure()
					break
				}

				if color == Color(sensorColor: response.color) {
					handler(.success)
					return
				}

				Timer.scheduledTimerWithTimeInterval(kSensorPollingInterval) {
					self.notifyWhenColorIs(color, consecutiveFailures: 0, handler: handler)
				}
			}
		}
	}
}

/// Represents an EV3 infrared sensor.
public final class EV3InfraredSensor: EV3Sensor {
	/// Returns the current proximity normalized from 0 to 1. Accessing this value blocks the caller until a response has been received.
	///
	/// - returns: The proximity reading, or `nil` if the value cannot be determined.
	public var proximity: Double? {
		var proximityResult: Double?
		let command = EV3ReadIRProximityCommand(port: port.internalRep)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// `proximityResult` is already `nil`
				break
			case .responseGroup(let group):
				guard let response = group.firstResponse as? EV3PercentByteResponse else {
					assertionFailure()
					break
				}

				guard let percent = response.percent else {
					// `proximityResult` is already `nil`
					break
				}

				proximityResult = Double(percent) / 100.0
			}
		}
		robot.waitForPipeline()
		return proximityResult
	}

	/// Asynchronously reads the proximity (normalized from 0 to 1) with the infrared sensor and invokes the given handler.
	///
	/// - parameter handler: The handler to invoke when the state is read.
	public func readProximity(_ handler: @escaping (Double?) -> ()) {
		let command = EV3ReadIRProximityCommand(port: port.internalRep)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler(nil)
			case .responseGroup(let group):
				guard let response = group.firstResponse as? EV3PercentByteResponse else {
					handler(nil)
					assertionFailure()
					return
				}

				guard let percent = response.percent else {
					handler(nil)
					return
				}

				handler(Double(percent) / 100.0)
			}
		}
	}

	/// Blocks the caller until the infrared sensor falls or exceeds a given proximity threshold.
	///
	/// If reading the proximity value fails three times, this method returns with an error code to prevent infinite blocking.
	///
	/// - parameter relation: The relationship between new proximity values and the threshold.
	/// - parameter threshold: The threshold.
	/// - returns: `success` if the operation completed successfully.
	public func waitUntilProximityIs(_ relation: ThresholdRelation, threshold: Double) -> RobotResponse {
		var lastValue = 0.0
		var consecutiveFailures = 3
		repeat {
			let command = EV3ReadIRProximityCommand(port: port.internalRep)
			robot.device.enqueueCommand(command) { result in
				assert(Thread.isMainThread)

				switch result {
				case .error:
					consecutiveFailures += 1
				case .responseGroup(let group):
					guard let response = group.firstResponse as? EV3PercentByteResponse else {
						consecutiveFailures += 1
						assertionFailure()
						break
					}

					guard let percent = response.percent else {
						consecutiveFailures += 1
						break
					}

					consecutiveFailures = 0
					lastValue = Double(percent) / 100.0
				}
			}

			robot.waitForPipeline()

			// Try again after the polling interval.
			Thread.sleep(forTimeInterval: kSensorPollingInterval)
		} while (consecutiveFailures != kMaxFailedSensorReadings && !relation.compare(lastValue, threshold))

		return consecutiveFailures == kMaxFailedSensorReadings ? .error : .success
	}

	/// Asynchronously notifies the caller when the infrared sensor falls or exceeds a given proximity threshold.
	///
	/// If reading the proximity value fails three times, the handler is invoked with an error code to prevent infinite waiting.
	///
	/// - parameter relation: The relationship between new proximity values and the threshold.
	/// - parameter threshold: The threshold.
	/// - parameter handler: The handler to invoke when the condition is met.
	public func notifyWhenProximityIs(_ relation: ThresholdRelation, threshold: Double, handler: @escaping RobotResponseHandler) {
		notifyWhenProximityIs(relation, threshold: threshold, consecutiveFailures: 0, handler: handler)
	}

	private func notifyWhenProximityIs(_ relation: ThresholdRelation, threshold: Double, consecutiveFailures: Int, handler: @escaping RobotResponseHandler) {
		let command = EV3ReadIRProximityCommand(port: port.internalRep)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			func handleLocalError() {
				// This is the 3rd failure.
				if consecutiveFailures == kMaxFailedSensorReadings - 1 {
					handler(.error)
					return
				}

				Timer.scheduledTimerWithTimeInterval(kSensorPollingInterval) {
					self.notifyWhenProximityIs(relation, threshold: threshold, consecutiveFailures: consecutiveFailures + 1, handler: handler)
				}
			}

			switch result {
			case .error:
				handleLocalError()
			case .responseGroup(let group):
				guard let response = group.firstResponse as? EV3PercentByteResponse else {
					handleLocalError()
					assertionFailure()
					break
				}

				guard let percent = response.percent else {
					handleLocalError()
					break
				}

				if relation.compare(Double(percent) / 100.0, threshold) {
					handler(.success)
					return
				}

				Timer.scheduledTimerWithTimeInterval(kSensorPollingInterval) {
					self.notifyWhenProximityIs(relation, threshold: threshold, consecutiveFailures: 0, handler: handler)
				}
			}
		}
	}
}

/// Represents an EV3 ultrasonic sensor.
public final class EV3UltrasonicSensor: EV3Sensor {
	/// Returns the current distance in centimeters. Accessing this value blocks the caller until a response has been received.
	///
	/// - returns: The distance reading, or `nil` if the value cannot be determined.
	public var distance: Double? {
		var distanceResult: Double?
		let command = EV3ReadUltrasonicSensorCommand(port: port.internalRep)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// `distanceResult` is already `nil`
				break
			case .responseGroup(let group):
				guard let response = group.firstResponse as? EV3FloatResponse else {
					assertionFailure()
					break
				}

				distanceResult = Double(response.value)
			}
		}
		robot.waitForPipeline()
		return distanceResult
	}

	/// Asynchronously reads the distance in centimeters with the ultrasonic sensor and invokes the given handler.
	///
	/// - parameter handler: The handler to invoke when the distance is read.
	public func readDistance(_ handler: @escaping (Double?) -> ()) {
		let command = EV3ReadUltrasonicSensorCommand(port: port.internalRep)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler(nil)
			case .responseGroup(let group):
				guard let response = group.firstResponse as? EV3FloatResponse else {
					handler(nil)
					assertionFailure()
					break
				}

				handler(Double(response.value))
			}
		}
	}

	/// Blocks the caller until the ultrasonic sensor falls or exceeds a given distance threshold.
	///
	/// If reading the distance value fails three times, this method returns with an error code to prevent infinite blocking.
	///
	/// - parameter relation: The relationship between new distance values and the threshold.
	/// - parameter threshold: The threshold.
	/// - returns: `success` if the operation completed successfully.
	public func waitUntilDistanceIs(_ relation: ThresholdRelation, threshold: Double) -> RobotResponse {
		var lastValue = 0.0
		var consecutiveFailures = 0
		repeat {
			let command = EV3ReadUltrasonicSensorCommand(port: port.internalRep)
			robot.device.enqueueCommand(command) { result in
				assert(Thread.isMainThread)

				switch result {
				case .error:
					consecutiveFailures += 1
				case .responseGroup(let group):
					guard let response = group.firstResponse as? EV3FloatResponse else {
						consecutiveFailures += 1
						assertionFailure()
						break
					}

					consecutiveFailures = 0
					lastValue = Double(response.value) / 100.0
				}
			}

			robot.waitForPipeline()

			// Try again after the polling interval.
			Thread.sleep(forTimeInterval: kSensorPollingInterval)
		} while (consecutiveFailures != kMaxFailedSensorReadings && !relation.compare(lastValue, threshold))

		return consecutiveFailures == kMaxFailedSensorReadings ? .error : .success
	}

	/// Asynchronously notifies the caller when the ultrasonic sensor falls or exceeds a given distance threshold.
	///
	/// If reading the distance value fails three times, the handler is invoked with an error code to prevent infinite waiting.
	///
	/// - parameter relation: The relationship between new distance values and the threshold.
	/// - parameter threshold: The threshold.
	/// - parameter handler: The handler to invoke when the condition is met.
	public func notifyWhenDistanceIs(_ relation: ThresholdRelation, threshold: Double, handler: @escaping RobotResponseHandler) {
		notifyWhenDistanceIs(relation, threshold: threshold, consecutiveFailures: 0, handler: handler)
	}

	private func notifyWhenDistanceIs(_ relation: ThresholdRelation, threshold: Double, consecutiveFailures: Int, handler: @escaping RobotResponseHandler) {
		let command = EV3ReadUltrasonicSensorCommand(port: port.internalRep)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			func handleLocalError() {
				// This is the 3rd failure.
				if consecutiveFailures == kMaxFailedSensorReadings - 1 {
					handler(.error)
					return
				}

				Timer.scheduledTimerWithTimeInterval(kSensorPollingInterval) {
					self.notifyWhenDistanceIs(relation, threshold: threshold, consecutiveFailures: consecutiveFailures + 1, handler: handler)
				}
			}

			switch result {
			case .error:
				handleLocalError()
			case .responseGroup(let group):
				guard let response = group.firstResponse as? EV3FloatResponse else {
					handleLocalError()
					assertionFailure()
					break
				}

				if relation.compare(Double(response.value) / 100.0, threshold) {
					handler(.success)
					return
				}

				Timer.scheduledTimerWithTimeInterval(kSensorPollingInterval) {
					self.notifyWhenDistanceIs(relation, threshold: threshold, consecutiveFailures: 0, handler: handler)
				}
			}
		}
	}
}

/// Represents an EV3 gyro sensor.
public final class EV3GyroSensor: EV3Sensor {
	/// Returns the current angle in degrees ranging [-180, 180]. Accessing this value blocks the caller until a response has been received.
	///
	/// - returns: The angle, or `nil` if the value cannot be determined.
	public var angle: Float? {
		var result: Float?
		readAngle { value in
			result = value
		}
		robot.waitForPipeline()
		return result
	}

	/// Returns the current rotation rate in degrees/s ranging [-440, 440]. Accessing this value blocks the caller until a response has been received.
	///
	/// - returns: The rotation rate, or `nil` if the value cannot be determined.
	public var rotationRate: Float? {
		var result: Float?
		readRotationRate { value in
			result = value
		}
		robot.waitForPipeline()
		return result
	}

	/// Asynchronously reads the angle (in degrees ranging [-180, 180]) with the gyro sensor and invokes the given handler.
	///
	/// - parameter handler: The handler to invoke when the value is read.
	public func readAngle(_ handler: @escaping (Float?) -> ()) {
		let command = EV3ReadGyroCommand(port: port.internalRep, mode: .angle)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler(nil)
			case .responseGroup(let group):
				guard let response = group.firstResponse as? EV3FloatResponse else {
					handler(nil)
					assertionFailure()
					return
				}

				handler(response.value)
			}
		}
	}

	/// Asynchronously reads the rotation rate (in degrees ranging [-440, 440]) with the gyro sensor and invokes the given handler.
	///
	/// - parameter handler: The handler to invoke when the value is read.
	public func readRotationRate(_ handler: @escaping (Float?) -> ()) {
		let command = EV3ReadGyroCommand(port: port.internalRep, mode: .rate)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler(nil)
			case .responseGroup(let group):
				guard let response = group.firstResponse as? EV3FloatResponse else {
					handler(nil)
					assertionFailure()
					return
				}

				handler(response.value)
			}
		}
	}

	/// Blocks the caller until the gyro sensor reads an angle that falls or exceeds a given threshold.
	///
	/// If reading the angle fails three times, this method returns with an error code to prevent infinite blocking.
	///
	/// - parameter relation: The relationship between new angular values and the threshold.
	/// - parameter threshold: The threshold in degrees.
	/// - returns: `success` if the operation completed successfully.
	public func waitUntilAngleIs(_ relation: ThresholdRelation, threshold: Float) -> RobotResponse {
		var lastValue: Float = 0.0
		var consecutiveFailures = 3
		repeat {
			readAngle { value in
				if let value = value {
					lastValue = value
					consecutiveFailures = 0
				} else {
					consecutiveFailures += 1
				}
			}

			robot.waitForPipeline()

			// Try again after the polling interval.
			Thread.sleep(forTimeInterval: kSensorPollingInterval)
		} while (consecutiveFailures != kMaxFailedSensorReadings && !relation.compare(lastValue, threshold))

		return consecutiveFailures == kMaxFailedSensorReadings ? .error : .success
	}

	/// Asynchronously notifies the caller when the gyro sensor reads an angle that falls or exceeds the given threshold.
	///
	/// If reading the angle fails three times, the handler is invoked with an error code to prevent infinite waiting.
	///
	/// - parameter relation: The relationship between new angular values and the threshold.
	/// - parameter threshold: The threshold in degrees.
	/// - parameter handler: The handler to invoke when the condition is met.
	public func notifyWhenAngleIs(_ relation: ThresholdRelation, threshold: Float, handler: @escaping RobotResponseHandler) {
		notifyWhenAngleIs(relation, threshold: threshold, consecutiveFailures: 0, handler: handler)
	}

	private func notifyWhenAngleIs(_ relation: ThresholdRelation, threshold: Float, consecutiveFailures: Int, handler: @escaping RobotResponseHandler) {
		readAngle { response in
			assert(Thread.isMainThread)

			guard let response = response else {
				// This is the 3rd failure.
				if consecutiveFailures == kMaxFailedSensorReadings - 1 {
					handler(.error)
					return
				}

				Timer.scheduledTimerWithTimeInterval(kSensorPollingInterval) {
					self.notifyWhenAngleIs(relation, threshold: threshold, consecutiveFailures: consecutiveFailures + 1, handler: handler)
				}

				return
			}

			guard relation.compare(response, threshold) else {
				Timer.scheduledTimerWithTimeInterval(kSensorPollingInterval) {
					self.notifyWhenAngleIs(relation, threshold: threshold, consecutiveFailures: 0, handler: handler)
				}
				return
			}

			handler(.success)
		}
	}
}

public extension EV3Robot {
	private func sensorType(atPort port: EV3InputPort) -> EV3SensorType? {
		let command = EV3GetSensorTypeCommand(port: port.internalRep)
		var type: EV3SensorType?
		device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// `type` is already `nil`
				break
			case .responseGroup(let group):
				guard let typeResponse = group.firstResponse as? EV3SensorTypeModeResponse else {
					assertionFailure()
					return
				}

				type = typeResponse.type
			}
		}
		device.waitForOperations()
		return type
	}

	/// Provides access to a touch sensor at the given port.
	///
	/// Note: This call will block the caller until the port is validated.
	///
	/// - parameter port: The port of the sensor.
	/// - returns: A reference to the sensor, or `nil` if it cannot be validated.
	public func touchSensor(atPort port: EV3InputPort) -> EV3TouchSensor? {
		let type = sensorType(atPort: port)

		guard let theType = type, theType == .touch else {
			return nil
		}

		return EV3TouchSensor(robot: self, port: port)
	}

	/// Asynchronously provides access to a touch sensor at the given port.
	///
	/// - parameter port: The port of the sensor.
	/// - parameter handler: The handler to invoke with the sensor, or `nil` if it cannot be validated.
	public func accessTouchSensor(atPort port: EV3InputPort, handler: @escaping (EV3TouchSensor?) -> ()) {
		let command = EV3GetSensorTypeCommand(port: port.internalRep)
		device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler(nil)
			case .responseGroup(let group):
				guard let typeResponse = group.firstResponse as? EV3SensorTypeModeResponse else {
					handler(nil)
					assertionFailure()
					return
				}

				guard let type = typeResponse.type, type == .touch else {
					handler(nil)
					return
				}

				handler(EV3TouchSensor(robot: self, port: port))
			}
		}
	}

	/// Provides access to a light sensor at the given port.
	///
	/// Note: This call will block the caller until the port is validated.
	///
	/// - parameter port: The port of the sensor.
	/// - returns: A reference to the sensor, or `nil` if it cannot be validated.
	public func lightSensor(atPort port: EV3InputPort) -> EV3LightSensor? {
		let type = sensorType(atPort: port)

		guard let theType = type, theType == .light else {
			return nil
		}

		return EV3LightSensor(robot: self, port: port)
	}

	/// Asynchronously provides access to a light sensor at the given port.
	///
	/// - parameter port: The port of the sensor.
	/// - parameter handler: The handler to invoke with the sensor, or `nil` if it cannot be validated.
	public func accessLightSensor(atPort port: EV3InputPort, handler: @escaping (EV3LightSensor?) -> ()) {
		let command = EV3GetSensorTypeCommand(port: port.internalRep)
		device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler(nil)
			case .responseGroup(let group):
				guard let typeResponse = group.firstResponse as? EV3SensorTypeModeResponse else {
					handler(nil)
					assertionFailure()
					return
				}

				guard let type = typeResponse.type, type == .light else {
					handler(nil)
					return
				}

				handler(EV3LightSensor(robot: self, port: port))
			}
		}
	}

	/// Provides access to an infrared sensor at the given port.
	///
	/// Note: This call will block the caller until the port is validated.
	///
	/// - parameter port: The port of the sensor.
	/// - returns: A reference to the sensor, or `nil` if it cannot be validated.
	public func infraredSensor(atPort port: EV3InputPort) -> EV3InfraredSensor? {
		let type = sensorType(atPort: port)

		guard let theType = type, theType == .ir else {
			return nil
		}

		return EV3InfraredSensor(robot: self, port: port)
	}

	/// Asynchronously provides access to an infrared sensor at the given port.
	///
	/// - parameter port: The port of the sensor.
	/// - parameter handler: The handler to invoke with the sensor, or `nil` if it cannot be validated.
	public func accessInfraredSensor(atPort port: EV3InputPort, handler: @escaping (EV3InfraredSensor?) -> ()) {
		let command = EV3GetSensorTypeCommand(port: port.internalRep)
		device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler(nil)
			case .responseGroup(let group):
				guard let typeResponse = group.firstResponse as? EV3SensorTypeModeResponse else {
					handler(nil)
					assertionFailure()
					return
				}

				guard let type = typeResponse.type, type == .ir else {
					handler(nil)
					return
				}

				handler(EV3InfraredSensor(robot: self, port: port))
			}
		}
	}

	/// Provides access to an ultrasonic sensor at the given port.
	///
	/// Note: This call will block the caller until the port is validated.
	///
	/// - parameter port: The port of the sensor.
	/// - returns: A reference to the sensor, or `nil` if it cannot be validated.
	public func ultrasonicSensor(atPort port: EV3InputPort) -> EV3UltrasonicSensor? {
		let type = sensorType(atPort: port)

		guard let theType = type, theType == .ultrasound else {
			return nil
		}

		return EV3UltrasonicSensor(robot: self, port: port)
	}

	/// Asynchronously provides access to an ultrasonic sensor at the given port.
	///
	/// - parameter port: The port of the sensor.
	/// - parameter handler: The handler to invoke with the sensor, or `nil` if it cannot be validated.
	public func accessUltrasonicSensor(atPort port: EV3InputPort, handler: @escaping (EV3UltrasonicSensor?) -> ()) {
		let command = EV3GetSensorTypeCommand(port: port.internalRep)
		device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler(nil)
			case .responseGroup(let group):
				guard let typeResponse = group.firstResponse as? EV3SensorTypeModeResponse else {
					handler(nil)
					assertionFailure()
					return
				}

				guard let type = typeResponse.type, type == .ultrasound else {
					handler(nil)
					return
				}

				handler(EV3UltrasonicSensor(robot: self, port: port))
			}
		}
	}

	/// Provides access to a gyro sensor at the given port.
	///
	/// Note: This call will block the caller until the port is validated.
	///
	/// - parameter port: The port of the sensor.
	/// - returns: A reference to the sensor, or `nil` if it cannot be validated.
	public func gyroSensor(atPort port: EV3InputPort) -> EV3GyroSensor? {
		let type = sensorType(atPort: port)

		guard let theType = type, theType == .gyro else {
			return nil
		}

		return EV3GyroSensor(robot: self, port: port)
	}

	/// Asynchronously provides access to a gyro sensor at the given port.
	///
	/// - parameter port: The port of the sensor.
	/// - parameter handler: The handler to invoke with the sensor, or `nil` if it cannot be validated.
	public func accessGyroSensor(atPort port: EV3InputPort, handler: @escaping (EV3GyroSensor?) -> ()) {
		let command = EV3GetSensorTypeCommand(port: port.internalRep)
		device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler(nil)
			case .responseGroup(let group):
				guard let typeResponse = group.firstResponse as? EV3SensorTypeModeResponse else {
					handler(nil)
					assertionFailure()
					return
				}

				guard let type = typeResponse.type, type == .gyro else {
					handler(nil)
					return
				}

				handler(EV3GyroSensor(robot: self, port: port))
			}
		}
	}
}
