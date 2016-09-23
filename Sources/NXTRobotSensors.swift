//
//  NXTRobotSensors.swift
//  Robotary
//
//  Created by Matt on 8/17/16.
//

import RobotFoundation

/// Represents an NXT input port.
public enum NXTInputPort {
	case one
	case two
	case three
	case four
}

/// Represents an NXT sensor.
public class NXTSensor {
	fileprivate let robot: NXTRobot
	fileprivate let port: NXTInputPort

	required public init(robot: NXTRobot, port: NXTInputPort) {
		self.robot = robot
		self.port = port
	}

	fileprivate func readValue(_ handler: @escaping (Int?) -> ()) {
		let command = NXTGetInputValuesCommand(port: port.internalRep)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler(nil)
				break
			case .response(let response):
				guard let inputResponse = response as? NXTInputValuesResponse else {
					handler(nil)
					assertionFailure()
					break
				}

				handler(inputResponse.scaledValue)
			}
		}
	}

	fileprivate func readValue() -> Int? {
		var resultValue: Int?
		readValue { result in
			resultValue = result
		}
		robot.waitForPipeline()
		return resultValue
	}

	fileprivate func waitUntil(_ comparator: (Int?) -> Bool) -> RobotResponse {
		var lastValue: Int?
		var consecutiveFailures = 0
		repeat {
			let command = NXTGetInputValuesCommand(port: port.internalRep)
			robot.device.enqueueCommand(command) { result in
				assert(Thread.isMainThread)

				switch result {
				case .error:
					consecutiveFailures += 1
				case .response(let response):
					guard let inputResponse = response as? NXTInputValuesResponse else {
						consecutiveFailures += 1
						assertionFailure()
						break
					}

					guard let value = inputResponse.scaledValue else {
						consecutiveFailures += 1
						break
					}

					consecutiveFailures = 0
					lastValue = value
				}
			}

			robot.waitForPipeline()

			// Try again after the polling interval.
			Thread.sleep(forTimeInterval: kSensorPollingInterval)
		} while (consecutiveFailures != kMaxFailedSensorReadings && !comparator(lastValue))

		return consecutiveFailures == kMaxFailedSensorReadings ? .error : .success
	}

	fileprivate func notifyOn(_ comparator: @escaping (Int) -> Bool, handler: @escaping RobotResponseHandler) {
		notifyOn(comparator, consecutiveFailures: 0, handler: handler)
	}

	private func notifyOn(_ comparator: @escaping (Int) -> Bool, consecutiveFailures: Int, handler: @escaping RobotResponseHandler) {
		let command = NXTGetInputValuesCommand(port: port.internalRep)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			func handleLocalError() {
				// This is the 3rd failure.
				if consecutiveFailures == kMaxFailedSensorReadings - 1 {
					handler(.error)
					return
				}

				Timer.scheduledTimerWithTimeInterval(kSensorPollingInterval) {
					self.notifyOn(comparator, consecutiveFailures: consecutiveFailures + 1, handler: handler)
				}
			}

			switch result {
			case .error:
				handleLocalError()
			case .response(let response):
				// If this fails, try again after the polling interval.
				guard let inputResponse = response as? NXTInputValuesResponse else {
					handleLocalError()
					assertionFailure()
					break
				}

				guard let value = inputResponse.scaledValue else {
					handleLocalError()
					break
				}

				if comparator(value) {
					handler(.success)
					return
				}

				Timer.scheduledTimerWithTimeInterval(kSensorPollingInterval) {
					self.notifyOn(comparator, consecutiveFailures: 0, handler: handler)
				}
			}
		}
	}
}

private extension NXTInputPort {
	var internalRep: RobotFoundation.NXTInputPort {
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

/// Represents an NXT touch sensor.
public final class NXTTouchSensor: NXTSensor {
	/// Represents the current state of the touch sensor.
	public enum State {
		case pressed
		case released
	}

	/// Returns the current state of the touch sensor. This method blocks the caller until a response has been received.
	///
	/// - returns: The state of the touch sensor, or `nil` if the state cannot be determined.
	public var state: State? {
		guard let result = readValue() else {
			return nil
		}

		switch result {
		case 1:
			return .pressed
		case 0:
			return .released
		default:
			return nil
		}
	}

	/// Asynchronously reads the current state of the touch sensor and invokes the given handler.
	///
	/// - parameter handler: The handler to invoke when the state is read.
	public func readState(_ handler: @escaping (State?) -> ()) {
		readValue { result in
			guard let value = result else {
				handler(nil)
				return
			}

			if value == 1 {
				handler(.pressed)
			} else if value == 0 {
				handler(.released)
			} else {
				handler(nil)
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
		return waitUntil { lastValue in
			guard let value = lastValue else {
				return false
			}

			if value == 1 && state == .pressed {
				return true
			} else if value == 0 && state == .released {
				return true
			} else {
				return false
			}
		}
	}

	/// Asynchronously notifies the caller when the touch sensor enters the given state.
	///
	/// If reading the state fails three times, the handler is invoked with an error code to prevent infinite waiting.
	///
	/// - parameter state: The touch sensor state to wait for.
	/// - parameter handler: The handler to invoke when the state matches the given state.
	public func notifyOn(_ state: State, handler: @escaping RobotResponseHandler) {
		notifyOn({ (value: Int) in
			if value == 1 && state == .pressed {
				return true
			} else if value == 0 && state == .released {
				return true
			}

			return false
		}, handler: handler)
	}
}

private extension NXTColorSensor.Color {
	init?(rawValue: Int) {
		switch rawValue {
		case 1:
			self = .black
		case 2:
			self = .blue
		case 3:
			self = .green
		case 4:
			self = .yellow
		case 5:
			self = .red
		case 6:
			self = .white
		default:
			return nil
		}
	}
}

/// Represents an NXT color sensor.
public final class NXTColorSensor: NXTSensor {
	/// Represents one of the 6 colors the color sensor can read.
	public enum Color {
		case black
		case blue
		case green
		case yellow
		case red
		case white
	}

	/// Returns the current color as read by the color sensor. This method blocks the caller until a response has been received.
	///
	/// - returns: One of six predefined colors, or `nil` if the color cannot be determined.
	public var color: Color? {
		guard let result = readValue() else {
			return nil
		}

		guard let color = Color(rawValue: result) else {
			return nil
		}

		return color
	}

	/// Asynchronously reads the current color as read by the color sensor and invokes the given handler.
	///
	/// - parameter handler: The handler to invoke when the state is read.
	public func readColor(_ handler: @escaping (Color?) -> ()) {
		readValue { result in
			guard let value = result else {
				handler(nil)
				return
			}

			handler(Color(rawValue: value))
		}
	}

	/// Blocks the caller until the color sensor reads the given color.
	///
	/// If reading the color fails three times, this method returns with an error code to prevent infinite blocking.
	///
	/// - parameter color: The color to wait for.
	/// - returns: `success` if the operation completed successfully.
	public func waitUntilColorIs(_ color: Color) -> RobotResponse {
		return waitUntil { lastValue in
			guard let value = lastValue else {
				return false
			}

			guard let currentColor = Color(rawValue: value) else {
				return false
			}

			return color == currentColor
		}
	}

	/// Asynchronously notifies the caller when the color sensor reads the given color.
	///
	/// If reading the color fails three times, the handler is invoked with an error code to prevent infinite waiting.
	///
	/// - parameter color: The color to wait for.
	/// - parameter handler: The handler to invoke when the color matches the given color.
	public func notifyWhenColorIs(_ color: Color, handler: @escaping RobotResponseHandler) {
		notifyOn({ value in
			guard let currentColor = Color(rawValue: value) else {
				return false
			}

			return currentColor == color
		}, handler: handler)
	}
}

private extension NXTLightSensor.Mode {
	var sensorType: NXTSensorType {
		switch self {
		case .reflective:
			return .lightActive
		case .ambient:
			return .lightInactive
		}
	}
}

/// Represents an NXT light sensor.
public final class NXTLightSensor: NXTSensor {
	/// Represents the current state of the light sensor.
	public enum Mode {
		case reflective
		case ambient
	}

	/// Returns the current value of the light sensor as a percent. This method blocks the caller until a response has been received.
	///
	/// - returns: The percentage as read by the light sensor, or `nil` if the reading failed.
	public var light: Int? {
		return readValue()
	}

	/// Asynchronously reads the current value of the light sensor and invokes the given handler.
	///
	/// - parameter handler: The handler to invoke once the percentage is read.
	public func readLight(_ handler: @escaping (Int?) -> ()) {
		readValue(handler)
	}

	/// Blocks the caller until the reading from the light sensor satisfies the given inequality.
	///
	/// If reading the value fails three times, this method returns with an error code to prevent infinite blocking.
	///
	/// - parameter relation: The relationship between new light values and the threshold.
	/// - parameter threshold: The threshold.
	/// - returns: `success` if the operation completed successfully.
	public func waitUntilLightIs(_ relation: ThresholdRelation, threshold: Int) -> RobotResponse {
		return waitUntil { lastValue in
			guard let value = lastValue else {
				return false
			}

			return relation.compare(value, threshold)
		}
	}

	/// Asynchronously notifies the caller when the light sensor reading satisfies the given inequality.
	///
	/// If reading the value fails three times, the handler is invoked with an error code to prevent infinite waiting.
	///
	/// - parameter relation: The relationship between new light values and the threshold.
	/// - parameter threshold: The threshold.
	/// - parameter handler: The handler to invoke when the condition is met.
	public func notifyWhenLightIs(_ relation: ThresholdRelation, threshold: Int, handler: @escaping RobotResponseHandler) {
		notifyOn({ value in
			return relation.compare(value, threshold)
		}, handler: handler)
	}
}

private extension NXTTemperatureSensor.Mode {
	var sensorMode: NXTSensorMode {
		switch self {
		case .celsius:
			return .celsius
		case .fahrenheit:
			return .fahrenheit
		}
	}
}

/// Represents an NXT temperature sensor.
public final class NXTTemperatureSensor: NXTSensor {
	/// Represents the current state of the temperature sensor.
	public enum Mode {
		case celsius
		case fahrenheit
	}

	/// Returns the current temperature as read by the temperature sensor. This method blocks the caller until a response has been received.
	///
	/// - returns: The temperature, or `nil` if the reading failed.
	public var temperature: Int? {
		return readValue()
	}

	/// Asynchronously reads the current temperature and invokes the given handler.
	///
	/// - parameter handler: The handler to invoke once the temperature is read.
	public func readTemperature(_ handler: @escaping (Int?) -> ()) {
		readValue(handler)
	}

	/// Blocks the caller until the temperature reading satisfies the given inequality.
	///
	/// If reading the value fails three times, this method returns with an error code to prevent infinite blocking.
	///
	/// - parameter relation: The relationship between new temperature values and the threshold.
	/// - parameter threshold: The threshold.
	/// - returns: `success` if the operation completed successfully.
	public func waitUntilTemperatureIs(_ relation: ThresholdRelation, threshold: Int) -> RobotResponse {
		return waitUntil { lastValue in
			guard let value = lastValue else {
				return false
			}

			return relation.compare(value, threshold)
		}
	}

	/// Asynchronously notifies the caller when the temperature reading satisfies the given inequality.
	///
	/// If reading the value fails three times, the handler is invoked with an error code to prevent infinite waiting.
	///
	/// - parameter relation: The relationship between new temperature values and the threshold.
	/// - parameter threshold: The threshold.
	/// - parameter handler: The handler to invoke when the condition is met.
	public func notifyWhenTemperatureIs(_ relation: ThresholdRelation, threshold: Int, handler: @escaping RobotResponseHandler) {
		notifyOn({ value in
			return relation.compare(value, threshold)
		}, handler: handler)
	}
}

/// Represents an NXT sound sensor.
public final class NXTSoundSensor: NXTSensor {
	/// Returns the current volume. This method blocks the caller until a response has been received.
	///
	/// - returns: The normalized dB value [0,1024), or `nil` if the reading failed.
	public var volume: Int? {
		return readValue()
	}

	/// Asynchronously reads the current volume and invokes the given handler.
	///
	/// - parameter handler: The handler to invoke once the normalized dBValue in range [0,1024) is read.
	public func readVolume(_ handler: @escaping (Int?) -> ()) {
		readValue(handler)
	}

	/// Blocks the caller until the volume satisfies the given inequality.
	///
	/// If reading the value fails three times, this method returns with an error code to prevent infinite blocking.
	///
	/// - parameter relation: The relationship between new volume levels and the threshold.
	/// - parameter threshold: The threshold.
	/// - returns: `success` if the operation completed successfully.
	public func waitUntilVolumeIs(_ relation: ThresholdRelation, threshold: Int) -> RobotResponse {
		return waitUntil { lastValue in
			guard let value = lastValue else {
				return false
			}

			return relation.compare(value, threshold)
		}
	}

	/// Asynchronously notifies the caller when the volume satisfies the given inequality.
	///
	/// If reading the value fails three times, the handler is invoked with an error code to prevent infinite waiting.
	///
	/// - parameter relation: The relationship between new volume levels and the threshold.
	/// - parameter threshold: The threshold.
	/// - parameter handler: The handler to invoke when the condition is met.
	public func notifyWhenVolumeIs(_ relation: ThresholdRelation, threshold: Int, handler: @escaping RobotResponseHandler) {
		notifyOn({ value in
			return relation.compare(value, threshold)
		}, handler: handler)
	}
}

private let kLSUltrasonicAddress = UInt8(0x02)
private let kLSSetUltrasonicMode = UInt8(0x41)
private let kLSSetUltrasonicModeContinuous = UInt8(0x2)
private let kLSReadUltrasonicByte0 = UInt8(0x42)
private let kUltrasonicPollInterval = TimeInterval(0.05)

/// Represents an NXT ultrasonic sensor.
public final class NXTUltrasonicSensor: NXTSensor {
	/// Returns the current distance (in centimeters). This method blocks the caller until a response has been received.
	///
	/// - returns: The distance in centimeters, or `nil` if the reading failed.
	public var distance: Int? {
		var result: Int?
		readDistance { distance in
			result = distance
		}
		robot.waitForPipeline()
		return result
	}

	/// Asynchronously reads the current distance (in centimeters) and invokes the given handler.
	///
	/// - parameter handler: The handler to invoke once the distance is read.
	public func readDistance(_ handler: @escaping (Int?) -> ()) {
		var modeData = Data()
		modeData.appendUInt8(kLSUltrasonicAddress)
		modeData.appendUInt8(kLSSetUltrasonicMode)
		modeData.appendUInt8(kLSSetUltrasonicModeContinuous)
		let request = NXTLSWriteCommand(port: port.internalRep, txData: modeData as Data, rxDataLength: 1)
		robot.device.enqueueCommand(request) { requestResponse in
			assert(Thread.isMainThread)

			switch requestResponse {
			case .error:
				handler(nil)
			case .response:
				self.sendUltrasonicPing(handler)
			}
		}
	}

	/// Blocks the caller until the ultrasonic sensor falls or exceeds a given distance threshold.
	///
	/// If reading the distance value fails ten times, this method returns with an error code to prevent infinite blocking.
	///
	/// - parameter relation: The relationship between new distance values and the threshold.
	/// - parameter threshold: The threshold.
	/// - returns: `success` if the operation completed successfully.
	public func waitUntilDistanceIs(_ relation: ThresholdRelation, threshold: Int) -> RobotResponse {
		var lastDistance: Int? = nil
		var firstRun = true
		var consecutiveFailures = 0
		repeat {
			if firstRun {
				// Do a full read sequence.
				readDistance { response in
					assert(Thread.isMainThread)
					lastDistance = response

					if response == nil {
						consecutiveFailures += 1
					} else {
						consecutiveFailures = 0
					}
				}
			} else {
				// Only send the ping.
				sendUltrasonicPing { response in
					assert(Thread.isMainThread)
					lastDistance = response

					if response == nil {
						consecutiveFailures += 1
					} else {
						consecutiveFailures = 0
					}
				}
			}
			robot.waitForPipeline()
			firstRun = false
		} while consecutiveFailures != kMaxFailedUltrasonicSensorReadings && (lastDistance == nil || !relation.compare(lastDistance!, threshold))

		return consecutiveFailures == kMaxFailedUltrasonicSensorReadings ? .error : .success
	}

	/// Asynchronously notifies the caller when the ultrasonic sensor falls or exceeds a given distance threshold.
	///
	/// If reading the distance value fails ten times, the handler is invoked with an error code to prevent infinite waiting.
	///
	/// - parameter relation: The relationship between new distance values and the threshold.
	/// - parameter threshold: The threshold.
	/// - parameter handler: The handler to invoke when the condition is met.
	public func notifyWhenDistanceIs(_ relation: ThresholdRelation, threshold: Int, handler: @escaping RobotResponseHandler) {
		readDistance { response in
			assert(Thread.isMainThread)

			guard let value = response else {
				self.notifyWhenDistanceIs(relation, threshold: threshold, consecutiveFailures: 1, handler: handler)
				return
			}

			guard relation.compare(value, threshold) else {
				self.notifyWhenDistanceIs(relation, threshold: threshold, consecutiveFailures: 0, handler: handler)
				return
			}

			handler(.success)
		}
	}

	private func notifyWhenDistanceIs(_ relation: ThresholdRelation, threshold: Int, consecutiveFailures: Int, handler: @escaping RobotResponseHandler) {
		if consecutiveFailures == kMaxFailedUltrasonicSensorReadings {
			handler(.error)
			return
		}

		// Do a full read sequence.
		sendUltrasonicPing { response in
			assert(Thread.isMainThread)

			guard let value = response else {
				self.notifyWhenDistanceIs(relation, threshold: threshold, consecutiveFailures: consecutiveFailures + 1, handler: handler)
				return
			}

			guard relation.compare(value, threshold) else {
				self.notifyWhenDistanceIs(relation, threshold: threshold, consecutiveFailures: 0, handler: handler)
				return
			}

			handler(.success)
		}
	}

	private func sendUltrasonicPing(_ handler: @escaping (Int?) -> ()) {
		var requestData = Data()
		requestData.appendUInt8(kLSUltrasonicAddress)
		requestData.appendUInt8(kLSReadUltrasonicByte0)
		let request = NXTLSWriteCommand(port: port.internalRep, txData: requestData as Data, rxDataLength: 1)
		robot.device.enqueueCommand(request) { requestResponse in
			assert(Thread.isMainThread)

			switch requestResponse {
			case .error(let error):
				if case NXTCommandError.commandError(let status) = error {
					if status == .undefinedError {
						// These are expected, retry later.
						Timer.scheduledTimerWithTimeInterval(kUltrasonicPollInterval) {
							self.sendUltrasonicPing(handler)
						}
						return
					}
				}

				handler(nil)
			case .response:
				self.waitForUltrasonicData(handler)
			}
		}
	}

	private func waitForUltrasonicData(_ handler: @escaping (Int?) -> ()) {
		let pollCommand = NXTLSGetStatusCommand(port: port.internalRep)
		robot.device.enqueueCommand(pollCommand) { pollResponse in
			assert(Thread.isMainThread)

			switch pollResponse {
			case .error(let error):
				if case NXTCommandError.commandError(let status) = error {
					if status == .undefinedError {
						// These are expected, retry later.
						Timer.scheduledTimerWithTimeInterval(kUltrasonicPollInterval) {
							self.waitForUltrasonicData(handler)
						}
						return
					}
				}

				handler(nil)
			case .response(let response):
				guard let statusResponse = response as? NXTLSStatusResponse else {
					assertionFailure()
					handler(nil)
					return
				}

				if statusResponse.bytesReady > 0 {
					// we have a response; read it!
					self.readUltrasonicResponse(handler)
				} else {
					// poll again in a bit.
					Timer.scheduledTimerWithTimeInterval(kUltrasonicPollInterval) {
						self.waitForUltrasonicData(handler)
					}
				}
			}
		}
	}

	private func readUltrasonicResponse(_ handler: @escaping (Int?) -> ()) {
		let readCommand = NXTLSReadCommand(port: port.internalRep)
		robot.device.enqueueCommand(readCommand) { response in
			assert(Thread.isMainThread)

			switch response {
			case .error:
				handler(nil)
			case .response(let response):
				guard let dataResponse = response as? NXTLSReadResponse else {
					handler(nil)
					assertionFailure()
					return
				}

				let distance = dataResponse.rxData.readUInt8AtIndex(0)
				if distance == 255 /* this is an error code */ {
					handler(nil)
				} else {
					handler(Int(distance))
				}
			}
		}
	}
}

/// Represents one of the 3 colors the NXT color sensor can emit.
public enum NXTEmittedColor {
	case none
	case red
	case green
	case blue
}

private extension NXTEmittedColor {
	var sensorType: NXTSensorType {
		switch self {
		case .none:
			return .colorNone
		case .blue:
			return .colorBlue
		case .green:
			return .colorGreen
		case .red:
			return .colorRed
		}
	}
}

public extension NXTRobot {
	private func accessSensor<T>(atPort port: NXTInputPort, type: NXTSensorType, mode: NXTSensorMode, handler: @escaping (T?) -> ()) where T: NXTSensor {
		let command = NXTSetInputModeCommand(port: port.internalRep, sensorType: type, sensorMode: mode)
		device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler(nil)
			case .response(let response):
				guard let _ = response as? NXTGenericResponse else {
					handler(nil)
					assertionFailure()
					return
				}

				handler(T(robot: self, port: port))
			}
		}

		// Let this run afterward, but don't wait on it.
		let resetCommand = NXTResetInputStateCommand(port: port.internalRep)
		device.enqueueCommand(resetCommand) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				NSLog("\(#function): could not reset the input port")
			case .response(let response):
				guard let _ = response as? NXTGenericResponse else {
					NSLog("\(#function): could not reset the input port (invalid response)")
					assertionFailure()
					return
				}
			}
		}
	}

	/// Provides access to a touch sensor at the given port.
	///
	/// Note: This call will block the caller until the port is validated.
	///
	/// - parameter port: The port of the sensor.
	/// - returns: A reference to the sensor, or `nil` if it cannot be validated.
	public func touchSensor(atPort port: NXTInputPort) -> NXTTouchSensor? {
		var touchSensor: NXTTouchSensor?
		accessSensor(atPort: port, type: .switch, mode: .boolean) { (sensor: NXTTouchSensor?) in
			touchSensor = sensor
		}
		waitForPipeline()

		return touchSensor
	}

	/// Asynchronously provides access to a touch sensor at the given port.
	///
	/// - parameter port: The port of the sensor.
	/// - parameter handler: The handler to invoke with the sensor, or `nil` if it cannot be validated.
	public func accessTouchSensor(atPort port: NXTInputPort, handler: @escaping (NXTTouchSensor?) -> ()) {
		accessSensor(atPort: port, type: .switch, mode: .boolean, handler: handler)
	}

	/// Provides access to a light sensor at the given port.
	///
	/// Note: This call will block the caller until the port is validated.
	///
	/// - parameter port: The port of the sensor.
	/// - parameter mode: Indicates whether to read ambient or reflective light.
	/// - returns: A reference to the sensor, or `nil` if it cannot be validated.
	public func lightSensor(atPort port: NXTInputPort, mode: NXTLightSensor.Mode) -> NXTLightSensor? {
		var lightSensor: NXTLightSensor?
		accessSensor(atPort: port, type: mode.sensorType, mode: .percentFull) { (sensor: NXTLightSensor?) in
			lightSensor = sensor
		}
		waitForPipeline()

		return lightSensor
	}

	/// Asynchronously provides access to a light sensor at the given port.
	///
	/// - parameter port: The port of the sensor.
	/// - parameter mode: Indicates whether to read ambient or reflective light.
	/// - parameter handler: The handler to invoke with the sensor, or `nil` if it cannot be validated.
	public func accessLightSensor(atPort port: NXTInputPort, mode: NXTLightSensor.Mode, handler: @escaping (NXTLightSensor?) -> ()) {
		accessSensor(atPort: port, type: mode.sensorType, mode: .percentFull, handler: handler)
	}

	/// Provides access to a temperature sensor at the given port.
	///
	/// Note: This call will block the caller until the port is validated.
	///
	/// - parameter port: The port of the sensor.
	/// - parameter mode: Indicates whether to perform readings in Celsius or Fahrenheit.
	/// - returns: A reference to the sensor, or `nil` if it cannot be validated.
	public func temperatureSensor(atPort port: NXTInputPort, mode: NXTTemperatureSensor.Mode) -> NXTTemperatureSensor? {
		var temperatureSensor: NXTTemperatureSensor?
		accessSensor(atPort: port, type: .temperature, mode: mode.sensorMode) { (sensor: NXTTemperatureSensor?) in
			temperatureSensor = sensor
		}
		waitForPipeline()

		return temperatureSensor
	}

	/// Asynchronously provides access to a temperature sensor at the given port.
	///
	/// - parameter port: The port of the sensor.
	/// - parameter mode: Indicates whether to perform readings in Celsius or Fahrenheit.
	/// - parameter handler: The handler to invoke with the sensor, or `nil` if it cannot be validated.
	public func accessTemperatureSensor(atPort port: NXTInputPort, mode: NXTTemperatureSensor.Mode, handler: @escaping (NXTTemperatureSensor?) -> ()) {
		accessSensor(atPort: port, type: .temperature, mode: mode.sensorMode, handler: handler)
	}

	/// Provides access to a sound sensor at the given port.
	///
	/// Note: This call will block the caller until the port is validated.
	///
	/// - parameter port: The port of the sensor.
	/// - returns: A reference to the sensor, or `nil` if it cannot be validated.
	public func soundSensor(atPort port: NXTInputPort) -> NXTSoundSensor? {
		var soundSensor: NXTSoundSensor?
		accessSensor(atPort: port, type: .sounddB, mode: .raw) { (sensor: NXTSoundSensor?) in
			soundSensor = sensor
		}
		waitForPipeline()

		return soundSensor
	}

	/// Asynchronously provides access to a sound sensor at the given port.
	///
	/// - parameter port: The port of the sensor.
	/// - parameter handler: The handler to invoke with the sensor, or `nil` if it cannot be validated.
	public func accessSoundSensor(atPort port: NXTInputPort, handler: @escaping (NXTSoundSensor?) -> ()) {
		accessSensor(atPort: port, type: .sounddB, mode: .raw, handler: handler)
	}

	/// Provides access to an ultrasonic sensor at the given port.
	///
	/// Note: This call will block the caller until the port is validated.
	///
	/// - parameter port: The port of the sensor.
	/// - returns: A reference to the sensor, or `nil` if it cannot be validated.
	public func ultrasonicSensor(atPort port: NXTInputPort) -> NXTUltrasonicSensor? {
		var ultrasonicSensor: NXTUltrasonicSensor?
		accessSensor(atPort: port, type: .lowSpeed9V, mode: .raw) { (sensor: NXTUltrasonicSensor?) in
			ultrasonicSensor = sensor
		}
		waitForPipeline()

		return ultrasonicSensor
	}

	/// Asynchronously provides access to an ultrasonic sensor at the given port.
	///
	/// - parameter port: The port of the sensor.
	/// - parameter handler: The handler to invoke with the sensor, or `nil` if it cannot be validated.
	public func accessUltrasonicSensor(atPort port: NXTInputPort, handler: @escaping (NXTUltrasonicSensor?) -> ()) {
		accessSensor(atPort: port, type: .lowSpeed9V, mode: .raw, handler: handler)
	}

	/// Provides access to a color sensor at the given port.
	///
	/// Note: This call will block the caller until the port is validated.
	///
	/// - parameter port: The port of the sensor.
	/// - returns: A reference to the sensor, or `nil` if it cannot be validated.
	public func colorSensor(atPort port: NXTInputPort) -> NXTColorSensor? {
		var colorSensor: NXTColorSensor?
		accessSensor(atPort: port, type: .colorFull, mode: .raw) { (sensor: NXTColorSensor?) in
			colorSensor = sensor
		}
		waitForPipeline()

		return colorSensor
	}

	/// Asynchronously provides access to a color sensor at the given port.
	///
	/// - parameter port: The port of the sensor.
	/// - parameter handler: The handler to invoke with the sensor, or `nil` if it cannot be validated.
	public func accessColorSensor(atPort port: NXTInputPort, handler: @escaping (NXTColorSensor?) -> ()) {
		accessSensor(atPort: port, type: .colorFull, mode: .raw, handler: handler)
	}

	/// Asynchronously emits the given color with the NXT color sensor at the given port.
	///
	/// - parameter color: The color to emit.
	/// - parameter port: The port of the sensor.
	/// - parameter handler: The handler to invoke if the operation completed successfully.
	public func emitColor(_ color: NXTEmittedColor, withColorSensorAtPort port: NXTInputPort, handler: @escaping RobotResponseHandler) {
		accessSensor(atPort: port, type: color.sensorType, mode: .raw) { (sensor: NXTColorSensor?) in
			handler(sensor != nil ? .success : .error)
		}
	}
}
