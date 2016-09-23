//
//  Note.swift
//  Robotary
//
//  Created by Matt on 1/30/16.
//

import Foundation

/// A data structure that represents note values.
public enum Note: Int {
	case C = 0
	case CSharp
	case D
	case DSharp
	case E
	case F
	case FSharp
	case G
	case GSharp
	case A
	case ASharp
	case B
}

/// Converts the given note and octave to a frequency that can be passed to one of the `playTone` methods.
public func noteToFrequency(_ note: Note, octave: Int) -> Int {
	let midiNumber = 24 + octave * 12 + note.rawValue
	return Int(Double(440) * pow(2, Double(midiNumber - 69) / 12))
}
