//
//  NXTUtilities.swift
//  Robotary
//
//  Created by Matt on 9/23/16.
//

import Foundation

extension NXTRobot {
	/// Blocks the caller until all pending operations finish processing.
	public func waitForPipeline() {
		device.waitForOperations()
	}
}
