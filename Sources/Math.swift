//
//  Math.swift
//  Robotary
//
//  Created by Matt on 7/8/16.
//

import Foundation

public let π = M_PI

// MARK: - Rounding

/// Returns the integer value closest to `x`.
public func round(_ x: Double) -> Int {
	return Int(Darwin.round(x))
}

/// Returns the integer value closest to `x`.
public func round(_ x: Float) -> Int {
	return Int(Darwin.round(x))
}

/// Returns the greatest integer value not greater than `x`.
public func floor(_ x: Double) -> Int {
	return Int(Darwin.floor(x))
}

/// Returns the greatest integer value not greater than `x`.
public func floor(_ x: Float) -> Int {
	return Int(Darwin.floor(x))
}

/// Returns the smallest integer value greater than `x`.
public func ceil(_ x: Double) -> Int {
	return Int(Darwin.ceil(x))
}

/// Returns the smallest integer value greater than `x`.
public func ceil(_ x: Float) -> Int {
	return Int(Darwin.ceil(x))
}

// MARK: - Trigonometry (Double)

private func degreesToRadians(_ degrees: Double) -> Double {
	return degrees * M_PI / 180.0
}

/// Computes the sine of `radians`.
public func sin(radians: Double) -> Double {
	return Darwin.sin(radians)
}

/// Computes the sine of `degrees`.
public func sin(degrees: Double) -> Double {
	return Darwin.sin(degreesToRadians(degrees))
}

/// Computes the arc sine of `radians`.
public func arcsin(radians: Double) -> Double {
	return Darwin.asin(radians)
}

/// Computes the arc sine of `degrees`.
public func arcsin(degrees: Double) -> Double {
	return Darwin.asin(degreesToRadians(degrees))
}

/// Computes the cosine of `radians`.
public func cos(radians: Double) -> Double {
	return Darwin.cos(radians)
}

/// Computes the cosine of `degrees`.
public func cos(degrees: Double) -> Double {
	return Darwin.cos(degreesToRadians(degrees))
}

/// Computes the arc cosine of `radians`.
public func arccos(radians: Double) -> Double {
	return Darwin.acos(radians)
}

/// Computes the arc cosine of `degrees`.
public func arccos(degrees: Double) -> Double {
	return Darwin.acos(degreesToRadians(degrees))
}

/// Computes the tangent of `radians`.
public func tan(radians: Double) -> Double {
	return Darwin.tan(radians)
}

/// Computes the tangent of `degrees`.
public func tan(degrees: Double) -> Double {
	return Darwin.tan(degreesToRadians(degrees))
}

/// Computes the arc tangent of `radians`.
public func arctan(radians: Double) -> Double {
	return Darwin.atan(radians)
}

/// Computes the arc tangent of `degrees`.
public func arctan(degrees: Double) -> Double {
	return Darwin.atan(degreesToRadians(degrees))
}

// MARK: - Trigonometry (Float)

private func degreesToRadians(_ degrees: Float) -> Float {
	return degrees * Float(M_PI) / 180.0
}

/// Computes the sine of `radians`.
public func sin(radians: Float) -> Float {
	return Darwin.sin(radians)
}

/// Computes the sine of `degrees`.
public func sin(degrees: Float) -> Float {
	return Darwin.sin(degreesToRadians(degrees))
}

/// Computes the arc sine of `radians`.
public func arcsin(radians: Float) -> Float {
	return Darwin.asin(radians)
}

/// Computes the arc sine of `degrees`.
public func arcsin(degrees: Float) -> Float {
	return Darwin.asin(degreesToRadians(degrees))
}

/// Computes the cosine of `radians`.
public func cos(radians: Float) -> Float {
	return Darwin.cos(radians)
}

/// Computes the cosine of `degrees`.
public func cos(degrees: Float) -> Float {
	return Darwin.cos(degreesToRadians(degrees))
}

/// Computes the arc cosine of `radians`.
public func arccos(radians: Float) -> Float {
	return Darwin.acos(radians)
}

/// Computes the arc cosine of `degrees`.
public func arccos(degrees: Float) -> Float {
	return Darwin.acos(degreesToRadians(degrees))
}

/// Computes the tangent of `radians`.
public func tan(radians: Float) -> Float {
	return Darwin.tan(radians)
}

/// Computes the tangent of `degrees`.
public func tan(degrees: Float) -> Float {
	return Darwin.tan(degreesToRadians(degrees))
}

/// Computes the arc tangent of `radians`.
public func arctan(radians: Float) -> Float {
	return Darwin.atan(radians)
}

/// Computes the arc tangent of `degrees`.
public func arctan(degrees: Float) -> Float {
	return Darwin.atan(degreesToRadians(degrees))
}
