//
//  RobotCommunication.swift
//  Robotary
//
//  Created by Matt on 3/29/16.
//

public enum RobotResponse {
	case success
	case error
}

public enum RobotCommunicationError: Error {
	case invalidDeviceConfiguration
	case cannotOpenConnection
	case mismatchedDeviceClass
}
