//
//  EV3RobotSound.swift
//  Robotary
//
//  Created by Matt on 1/30/16.
//

import Foundation
import RobotFoundation

/// Represents the EV3's sound system.
public final class EV3Sound {
	private let robot: EV3Robot

	fileprivate init(robot: EV3Robot) {
		self.robot = robot
	}

	/// Plays a single tone at the given frequency for the given duration and blocks until the tone finishes playing.
	///
	/// To play tones asynchronously, use `beginPlayingTone`.
	///
	/// `NoteToFrequency` can be used to convert MIDI notes to frequencies.
	///
	/// - parameter frequency: The frequency of the tone to play in Hz (in range 250 - 10000).
	/// - parameter duration: The duration of the tone in milliseconds.
	/// - parameter volume: The volume of the tone (in range 0 - 100).
	/// - returns: `success` if the operation completed successfully.
	public func playTone(frequency: Int, duration: Int, volume: Int = 100) -> RobotResponse {
		var response = RobotResponse.error

		let command = EV3PlayToneCommand(volume: UInt8(volume), frequency: UInt16(frequency), duration: UInt16(duration))
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// `response` is already set to `error`
				break
			case .responseGroup:
				response = .success
			}
		}

		let waitCommand = EV3WaitForSoundCommand()
		robot.device.enqueueCommand(waitCommand) { _ in
			// As long as the play tone operation worked okay, we don't care if we didn't wait.
		}

		robot.device.waitForOperations()

		return response
	}

	/// Plays a single tone at the given frequency for the given duration.
	///
	/// `NoteToFrequency` can be used to convert MIDI notes to frequencies.
	///
	/// - parameter frequency: The frequency of the tone to play in Hz (in range 250 - 10000).
	/// - parameter duration: The duration of the tone in milliseconds.
	/// - parameter volume: The volume of the tone (in range 0 - 100).
	/// - parameter handler: The callback that will be called once the command completes.
	public func beginPlayingTone(frequency: Int, duration: Int, volume: Int, handler: RobotResponseHandler? = nil) {
		let command = EV3PlayToneCommand(volume: UInt8(volume), frequency: UInt16(frequency), duration: UInt16(duration))
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler?(.error)
			case .responseGroup:
				handler?(.success)
			}
		}
	}

	/// Plays the given sound file (in RSF format) and blocks until it finishes playing.
	///
	/// To play sound files asynchronously, use `beginPlayingFile`.
	///
	/// **Note:** Sound files can be uploaded to the EV3 with Robotary's File Browser tool.
	///
	/// - parameter path: The path of the sound file **without** the `rsf` extension and relative to the `sys` directory.
	/// - parameter volume: The volume of the tone (in range 0 - 100).
	/// - returns: `success` if the operation completed successfully.
	public func playFile(path: String, volume: UInt8 = 100) -> RobotResponse {
		guard let command = EV3PlaySoundFileCommand(path: path, volume: UInt8(volume)) else {
			return .error
		}

		var response = RobotResponse.error

		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// `response` is already set to `error`
				break
			case .responseGroup:
				response = .success
			}
		}

		let waitCommand = EV3WaitForSoundCommand()
		robot.device.enqueueCommand(waitCommand) { _ in
			// As long as the play file operation worked okay, we don't care if we didn't wait.
		}

		robot.device.waitForOperations()

		return response
	}

	/// Plays the given sound file (in RSF format).
	///
	/// **Note:** Sound files can be uploaded to the EV3 with Robotary's File Browser tool.
	///
	/// - parameter path: The path of the sound file **without** the `rsf` extension and relative to the `sys` directory.
	/// - parameter volume: The volume of the tone (in range 0 - 100).
	/// - parameter handler: The callback that will be called once the command completes.
	public func beginPlayingFile(path: String, volume: UInt8, handler: RobotResponseHandler? = nil) {
		guard let command = EV3PlaySoundFileCommand(path: path, volume: UInt8(volume)) else {
			handler?(.error)
			return
		}
		
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler?(.error)
			case .responseGroup:
				handler?(.success)
			}
		}
	}

	/// Blocks the caller until the current tone or sound file finishes playing.
	///
	/// If there are no sounds playing, this method returns immediately.
	///
	/// - returns: `success` if the operation completed successfully.
	public func waitUntilStopped() -> RobotResponse {
		var response = RobotResponse.error

		let waitCommand = EV3WaitForSoundCommand()
		robot.device.enqueueCommand(waitCommand) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// `response` is already set to `error`
				break
			case .responseGroup:
				response = .success
			}
		}
		robot.device.waitForOperations()

		return response
	}

	/// Stops playing the current tone or sound file, if any. This method does not block the caller.
	///
	/// - parameter handler: The callback that will be called once the command completes.
	public func stop(_ handler: RobotResponseHandler? = nil) {
		let stopSoundCommand = EV3StopSoundCommand()
		robot.device.enqueueCommand(stopSoundCommand) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler?(.error)
			case .responseGroup:
				handler?(.success)
			}
		}
	}

	/// Checks if a tone or sound file is currently being played. This method blocks the caller until a response has been received.
	///
	/// - returns: `true` if sound is playing, and `false` if sound is not playing. `nil` is returned if the state of playback cannot be determined.
	public var isPlaying: Bool? {
		var playing: Bool? = nil
		let command = EV3TestSoundCommand()
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// `playing` is already `nil`
				break
			case .responseGroup(let responseGroup):
				guard let ev3Response = responseGroup.firstResponse as? EV3BooleanResponse else {
					assertionFailure()
					break
				}

				playing = ev3Response.value
			}
		}

		robot.device.waitForOperations()
		
		return playing
	}
}

extension EV3Robot {
	/// Provides access to the EV3's sound system.
	public var sound: EV3Sound {
		return EV3Sound(robot: self)
	}
}
