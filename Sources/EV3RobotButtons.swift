//
//  EV3RobotButtons.swift
//  Robotary
//
//  Created by Matt on 2/2/16.
//

import Foundation
import RobotFoundation

/// Represents one of the EV3's on-brick buttons.
public final class EV3Button {
	private let robot: EV3Robot
	private let buttonType: EV3ButtonType

	fileprivate init(robot: EV3Robot, buttonType: EV3ButtonType) {
		self.robot = robot
		self.buttonType = buttonType
	}

	/// Checks whether an on-brick button is pressed. This method blocks the caller.
	///
	/// - returns: `true` if the button is pressed, `false` if it is not, or `nil` if the state cannot be determined.
	public var isPressed: Bool? {
		var pressed: Bool? = nil
		let command = EV3IsButtonPressedCommand(button: buttonConstFromButton(buttonType))
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// `pressed` is already `nil`
				break
			case .responseGroup(let responseGroup):
				guard let buttonResponse = responseGroup.firstResponse as? EV3ButtonPressedResponse else {
					assertionFailure()
					break
				}

				pressed = buttonResponse.pressed
			}
		}
		robot.device.waitForOperations()
		return pressed
	}
}

/// Represents one of the EV3's six on-brick button types.
public enum EV3ButtonType {
	case up
	case enter
	case down
	case right
	case left
	case back
}

private func buttonConstFromButton(_ button: EV3ButtonType) -> EV3ButtonConst {
	switch button {
	case .back:
		return .back
	case .down:
		return .down
	case .enter:
		return .enter
	case .left:
		return .left
	case .right:
		return .right
	case .up:
		return .up
	}
}

extension EV3Robot {
	/// Provides access to the button of the given type.
	public func button(ofType type: EV3ButtonType) -> EV3Button {
		return EV3Button(robot: self, buttonType: type)
	}

	/// Waits for an on-brick button to be pressed.
	///
	/// - returns: The type of button if the operation completed successfully, or `nil` otherwise.
	public func waitForButtonPress() -> EV3ButtonType? {
		var response: EV3ButtonType?

		let command = EV3WaitForButtonCommand()
		let testUp = EV3IsButtonPressedCommand(button: .up)
		let testDown = EV3IsButtonPressedCommand(button: .down)
		let testLeft = EV3IsButtonPressedCommand(button: .left)
		let testRight = EV3IsButtonPressedCommand(button: .right)
		let testBack = EV3IsButtonPressedCommand(button: .back)
		let testEnter = EV3IsButtonPressedCommand(button: .enter)
		device.enqueueCommands([command, testUp, testDown, testLeft, testRight, testBack, testEnter]) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// `response` is already set to `nil`
				break
			case .responseGroup(let group):
				guard group.responses.count == 7 else {
					// `response` is already set to `nil`
					break
				}

				if let upResponse = group.responses[1] as? EV3ButtonPressedResponse, upResponse.pressed {
					response = .up
				}
				else if let downResponse = group.responses[2] as? EV3ButtonPressedResponse, downResponse.pressed {
					response = .down
				}
				else if let leftResponse = group.responses[3] as? EV3ButtonPressedResponse, leftResponse.pressed {
					response = .left
				}
				else if let rightResponse = group.responses[4] as? EV3ButtonPressedResponse, rightResponse.pressed {
					response = .right
				}
				else if let backResponse = group.responses[5] as? EV3ButtonPressedResponse, backResponse.pressed {
					response = .back
				}
				else if let enterResponse = group.responses[6] as? EV3ButtonPressedResponse, enterResponse.pressed {
					response = .enter
				}
			}
		}
		device.waitForOperations()

		return response
	}
}
