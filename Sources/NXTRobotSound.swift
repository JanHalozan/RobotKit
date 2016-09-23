//
//  EV3RobotSound.swift
//  Robotary
//
//  Created by Matt on 1/30/16.
//

import Foundation
import RobotFoundation

private let kSoundModule: UInt32 = 0x00080001
private let kSoundModuleFlags: UInt16 = 26

/// Represents the NXT's sound system.
public final class NXTSound {
	private let robot: NXTRobot

	fileprivate init(robot: NXTRobot) {
		self.robot = robot
	}

	/// Plays a single tone at the given frequency for the given duration.
	/// This method blocks the caller for the duration of the tone.
	///
	/// `NoteToFrequency` can be used to convert MIDI notes to frequencies.
	///
	/// - parameter frequency: The frequency of the tone to play in Hz (in range 200 - 14000).
	/// - parameter duration: The duration of the tone in milliseconds.
	public func playTone(frequency: Int, duration: Int) -> RobotResponse {
		var robotResponse = RobotResponse.error
		beginPlayingTone(frequency: frequency, duration: duration) { response in
			robotResponse = response
		}
		robot.waitForPipeline()
		wait(milliseconds: duration)

		return robotResponse
	}

	/// Plays a single tone at the given frequency for the given duration.
	///
	/// `NoteToFrequency` can be used to convert MIDI notes to frequencies.
	///
	/// - parameter frequency: The frequency of the tone to play in Hz (in range 200 - 14000).
	/// - parameter duration: The duration of the tone in milliseconds.
	/// - parameter handler: The callback that will be called once the command completes.
	public func beginPlayingTone(frequency: Int, duration: Int, handler: RobotResponseHandler? = nil) {
		let command = NXTPlayToneCommand(frequency: UInt16(frequency), duration: UInt16(duration))
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler?(.error)
			case .response(let response):
				guard let _ = response as? NXTGenericResponse else {
					handler?(.error)
					return
				}

				handler?(.success)
			}
		}
	}

	/// Plays the given sound file (in RSO format).
	///
	/// **Note:** Sound files can be uploaded to the NXT with Robotary's File Browser tool.
	///
	/// - parameter name: The file name of the sound file **including** the `rso` extension.
	/// - parameter loop: `True` if the sound file should loop until stopped.
	/// - parameter handler: The callback that will be called once the command completes.
	public func beginPlayingFile(name: String, loop: Bool, handler: RobotResponseHandler? = nil) {
		let command = NXTPlaySoundFileCommand(filename: name, loop: loop)
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler?(.error)
			case .response(let response):
				guard let _ = response as? NXTGenericResponse else {
					handler?(.error)
					return
				}

				handler?(.success)
			}
		}
	}

	/// Stops the currently-playing tone or sound file.
	public func stop(_ handler: RobotResponseHandler? = nil) {
		let command = NXTStopPlaybackCommand()
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				handler?(.error)
			case .response:
				handler?(.success)
			}
		}
	}

	/// Returns `True` if a tone or sound file is currently playing.
	///
	/// **Note**: Accessing this value blocks the caller until a response from the hardware is retrieved.
	/// **Warning**: Polling this value should be avoided.
	public var isPlaying: Bool? {
		var playingState: Bool?

		let command = NXTReadIOMapCommand(module: kSoundModule, offset: kSoundModuleFlags, bytesToRead: UInt16(MemoryLayout<UInt8>.size))
		robot.device.enqueueCommand(command) { result in
			assert(Thread.isMainThread)

			switch result {
			case .error:
				// `playingState` is already `nil`
				break
			case .response(let response):
				guard let nxtResponse = response as? NXTIOMapResponse else {
					assertionFailure()
					return
				}

				if nxtResponse.contents.readUInt8AtIndex(0) == 0x2 /* Running */ {
					playingState = true
				} else {
					playingState = false
				}
			}
		}

		robot.device.waitForOperations()

		return playingState
	}
}

public extension NXTRobot {
	/// Provides access to the NXT's sound system.
	public var sound: NXTSound {
		return NXTSound(robot: self)
	}
}
