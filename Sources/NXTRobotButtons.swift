//
//  NXTRobotButtons.swift
//  Robotary
//
//  Created by Matt on 4/2/16.
//

import Foundation
import RobotFoundation

/// Represents one of the NXT's four on-brick button types.
public enum NXTButtonType {
	case left
	case enter
	case right
	case exit

	fileprivate var rawValue: UInt16 {
		switch self {
		case .left:
			return 2
		case .right:
			return 1
		case .enter:
			return 3
		case .exit:
			return 0
		}
	}
}

private let kButtonModule: UInt32 = 0x00040001

/// Represents one of the NXT's on-brick buttons.
public final class NXTButton {
	private let robot: NXTRobot
	private let button: NXTButtonType

	fileprivate init(robot: NXTRobot, button: NXTButtonType) {
		self.robot = robot
		self.button = button
	}

	/// Checks whether an on-brick button is pressed. Accessing this value blocks the caller.
	///
	/// - returns: `true` if the button is pressed, `false` if it is not, or `nil` if the state cannot be determined.
	public var isPressed: Bool? {
		var pressed: Bool?
		let command = NXTReadIOMapCommand(module: kButtonModule, offset: 32 + button.rawValue, bytesToRead: UInt16(MemoryLayout<UInt8>.size))
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// `pressed` is already `nil`
				break
			case .response(let response):
				guard let nxtResponse = response as? NXTIOMapResponse else {
					assertionFailure()
					break
				}

				let result = nxtResponse.contents.readUInt8AtIndex(0)
				pressed = result == 0x80
			}
		}
		robot.device.waitForOperations()
		return pressed
	}
}

extension NXTRobot {
	/// Provides access to the button of the given type.
	public func button(ofType type: NXTButtonType) -> NXTButton {
		return NXTButton(robot: self, button: type)
	}
}
