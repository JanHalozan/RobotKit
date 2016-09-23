//
//  NXTRobot.swift
//  RobotKit
//
//  Created by Matt on 3/29/16.
//

import Foundation
import RobotFoundation

public final class NXTRobot: Robot {
	let device: NXTDevice

	public init() throws {
		let environment = ProcessInfo.processInfo.environment

		// The environment might contain other keys irrelevant to the device configuration, but this
		// is not a problem because they'll simply be ignored.
		guard let metaDevice = MetaDevice(stringDictionary: environment) else {
			throw RobotCommunicationError.invalidDeviceConfiguration
		}

		guard metaDevice.deviceClass == .NXT20 else {
			throw RobotCommunicationError.mismatchedDeviceClass
		}

		guard let nxtDevice = NXTDevice(metaDevice: metaDevice) else {
			throw RobotCommunicationError.invalidDeviceConfiguration
		}

		self.device = nxtDevice

		RobotManager.shared.registerRobot(self)
	}

	func prepareToExit() {
		device.waitForCriticalOperations()
	}
}
