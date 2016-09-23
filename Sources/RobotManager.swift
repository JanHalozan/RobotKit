//
//  RobotManager.swift
//  Robotary
//
//  Created by Matt on 9/6/16.
//  Copyright © 2016 Robotary. All rights reserved.
//

import Foundation

private struct WeakRobot: Hashable {
	weak var robot: Robot?

	var hashValue: Int {
		return 0
	}
}

private func==(lhs: WeakRobot, rhs: WeakRobot) -> Bool {
	return lhs.robot === rhs.robot
}

final class RobotManager {
	private var robots = Set<WeakRobot>()

	static let shared = RobotManager()

	func registerRobot(_ robot: Robot) {
		robots.insert(WeakRobot(robot: robot))
	}

	func prepareToExit() {
		for robot in robots {
			robot.robot?.prepareToExit()
		}
	}
}

public func __unsafePrepareToExit() {
	RobotManager.shared.prepareToExit()
}
