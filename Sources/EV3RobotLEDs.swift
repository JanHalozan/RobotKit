//
//  EV3RobotLEDs.swift
//  Robotary
//
//  Created by Matt on 2/1/16.
//

import Foundation
import RobotFoundation

/// Represents the EV3's LED colors.
public enum EV3LEDColor {
	case green
	case red
	case orange
}

/// Represents the EV3's LED effects.
public enum EV3LEDEffect {
	case normal
	case flash
	case pulse
}

extension EV3Robot {
	/// Changes the brick's LEDs to the given color with the given effect.
	///
	/// This call does not block the caller.
	///
	/// - parameter color: Green, red, or orange.
	/// - parameter effect: Normal, flashing, or pulsing.
	/// - parameter handler: The optional completion handler that indicates whether the operation succeeded.
	public func setLEDColor(_ color: EV3LEDColor, effect: EV3LEDEffect, handler: RobotResponseHandler? = nil) {
		let pattern: EV3LEDPattern

		switch color {
		case .green:
			switch effect {
			case .flash:
				pattern = .flashingGreen
			case .normal:
				pattern = .green
			case .pulse:
				pattern = .pulsingGreen
			}
		case .orange:
			switch effect {
			case .flash:
				pattern = .flashingOrange
			case .normal:
				pattern = .orange
			case .pulse:
				pattern = .pulsingOrange
			}
		case .red:
			switch effect {
			case .flash:
				pattern = .flashingRed
			case .normal:
				pattern = .red
			case .pulse:
				pattern = .pulsingRed
			}
		}

		let command = EV3SetLEDCommand(pattern: pattern)
		device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler?(.error)
			case .responseGroup:
				handler?(.success)
			}
		}
	}

	/// Turns off the brick's LEDs.
	///
	/// This call does not block the caller.
	///
	/// - parameter handler: The optional completion handler that indicates whether the operation succeeded.
	public func turnOffLEDs(_ handler: RobotResponseHandler? = nil) {
		let command = EV3SetLEDCommand(pattern: .none)
		device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler?(.error)
			case .responseGroup:
				handler?(.success)
			}
		}
	}
}
