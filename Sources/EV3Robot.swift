//
//  EV3Robot.swift
//  RobotKit
//
//  Created by Matt on 1/10/16.
//

import Foundation
import RobotFoundation

#if os(iOS)
import ExternalAccessory
#endif

public final class EV3Robot: Robot {
	let device: EV3Device

	// Used by EV3RobotDrawing
	var deferredDrawingTransactions = 0

#if os(OSX)
	public init() throws {
		let environment = ProcessInfo.processInfo.environment

		// The environment might contain other keys irrelevant to the device configuration, but this
		// is not a problem because they'll simply be ignored.
		guard let metaDevice = MetaDevice(stringDictionary: environment) else {
			throw RobotCommunicationError.invalidDeviceConfiguration
		}

		guard metaDevice.deviceClass == .EV3 else {
			throw RobotCommunicationError.mismatchedDeviceClass
		}

		guard let ev3Device = EV3Device(metaDevice: metaDevice) else {
			throw RobotCommunicationError.invalidDeviceConfiguration
		}

		self.device = ev3Device

		RobotManager.shared.registerRobot(self)
	}
#else
	public init() throws {
		let manager = EAAccessoryManager.shared()
		let transport = ExternalAccessoryTransport(accessory: manager.connectedAccessories.first!, protocolString: "COM.LEGO.MINDSTORMS.EV3")
		self.device = EV3Device(transport: transport)
		RobotManager.shared.registerRobot(self)
	}
#endif

	func prepareToExit() {
		device.waitForCriticalOperations()
	}
}
