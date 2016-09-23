//
//  EV3RobotDrawing.swift
//  Robotary
//
//  Created by Matt on 2/2/16.
//

import Foundation
import RobotFoundation

/// Represents the 1-bit colorspace of EV3's LCD.
public enum EV3Color {
	case black
	case white
}

/// Represents font sizes that can be used for text drawing.
public enum EV3FontSize {
	case small
	case medium
	case large
}

/// Represents an on-screen point.
public struct Point {
	public let x: Int
	public let y: Int

	public init(x: Int, y: Int) {
		self.x = x
		self.y = y
	}
}

/// Represents an on-screen rectangular area.
public struct Rectangle {
	public let x: Int
	public let y: Int
	public let width: Int
	public let height: Int

	public init(x: Int, y: Int, width: Int, height: Int) {
		self.x = x
		self.y = y
		self.width = width
		self.height = height
	}

	public init(origin: Point, width: Int, height: Int) {
		self.x = origin.x
		self.y = origin.y
		self.width = width
		self.height = height
	}
}

private func fillColorFromColor(_ color: EV3Color) -> EV3FillColorConst {
	switch color {
	case .black:
		return .foreground
	case .white:
		return .background
	}
}

private func fontSizeConstFromSize(_ size: EV3FontSize) -> EV3FontSizeConst {
	switch size {
	case .small:
		return .small
	case .medium:
		return .medium
	case .large:
		return .large
	}
}

/// Represents the EV3's drawable surface.
public final class EV3Window {
	private let robot: EV3Robot

	fileprivate init(robot: EV3Robot) {
		self.robot = robot
	}

	private var isDrawingDeferred: Bool {
		return robot.deferredDrawingTransactions > 0
	}

	private func updateDisplay() {
		let command = EV3UpdateDisplayCommand()
		robot.device.enqueueCommand(command) { result in
			if case EV3CommandResult.error = result {
				print("The display could not be updated.")
			}
		}
	}

	/// Clears the bounds of window frame.
	///
	/// This method blocks the caller until drawing is finished.
	/// Drawing can be deferred by calling this method from within a display update batch.
	public func clear() {
		fill(color: .white)
	}

	/// Fills the bounds of window frame with the given color.
	///
	/// This method blocks the caller until drawing is finished.
	/// Drawing can be deferred by calling this method from within a display update batch.
	///
	/// - parameter color: The fill color.
	public func fill(color: EV3Color) {
		let command = EV3FillWindowCommand(color: fillColorFromColor(color))
		robot.device.enqueueCommand(command) { result in
			if case EV3CommandResult.error = result {
				print("The window area could not be filled.")
			}
		}

		if !isDrawingDeferred {
			updateDisplay()
			robot.device.waitForOperations()
		}
	}

	/// Fills a circle.
	///
	/// This method blocks the caller until drawing is finished.
	/// Drawing can be deferred by calling this method from within a display update batch.
	///
	/// **Note:** The EV3's display has a resolution of 178x128 pixels.
	///
	/// - parameter center: The position in pixels relative to the top-left corner of the screen.
	/// - parameter radius: The radius of the circle in pixels.
	/// - parameter color: The fill color.
	public func fillCircle(center: Point, radius: Int, color: EV3Color) {
		let command = EV3FillCircleCommand(color: fillColorFromColor(color), x: UInt16(center.x), y: UInt16(center.y), radius: UInt16(radius))
		robot.device.enqueueCommand(command) { result in
			if case EV3CommandResult.error = result {
				print("The circle could not be filled.")
			}
		}

		if !isDrawingDeferred {
			updateDisplay()
			robot.device.waitForOperations()
		}
	}

	/// Draws a circle with a 1 pixel edge.
	///
	/// This method blocks the caller until drawing is finished.
	/// Drawing can be deferred by calling this method from within a display update batch.
	///
	/// **Note:** The EV3's display has a resolution of 178x128 pixels.
	///
	/// - parameter center: The position in pixels relative to the top-left corner of the screen.
	/// - parameter radius: The radius of the circle in pixels.
	/// - parameter color: The stroke color.
	public func strokeCircle(center: Point, radius: Int, color: EV3Color) {
		let command = EV3DrawCircleCommand(color: fillColorFromColor(color), x: UInt16(center.x), y: UInt16(center.y), radius: UInt16(radius))
		robot.device.enqueueCommand(command) { result in
			if case EV3CommandResult.error = result {
				print("The circle could not be drawn.")
			}
		}

		if !isDrawingDeferred {
			updateDisplay()
			robot.device.waitForOperations()
		}
	}

	/// Fills a rectangle.
	///
	/// This method blocks the caller until drawing is finished.
	/// Drawing can be deferred by calling this method from within a display update batch.
	///
	/// **Note:** The EV3's display has a resolution of 178x128 pixels.
	///
	/// - parameter frame: The frame of the rectangle to fill, whose origin is specified relative to the top-left corner of the screen.
	/// - parameter color: The fill color.
	public func fillRectangle(_ frame: Rectangle, color: EV3Color) {
		let command = EV3FillRectCommand(color: fillColorFromColor(color), x: UInt16(frame.x), y: UInt16(frame.y), width: UInt16(frame.width), height: UInt16(frame.height))
		robot.device.enqueueCommand(command) { result in
			if case EV3CommandResult.error = result {
				print("The rectangle could not be filled.")
			}
		}

		if !isDrawingDeferred {
			updateDisplay()
			robot.device.waitForOperations()
		}
	}

	/// Draws a rectangle with 1 pixel edges.
	///
	/// This method blocks the caller until drawing is finished.
	/// Drawing can be deferred by calling this method from within a display update batch.
	///
	/// **Note:** The EV3's display has a resolution of 178x128 pixels.
	///
	/// - parameter frame: The frame of the rectangle to stroke, whose origin is specified relative to the top-left corner of the screen.
	/// - parameter color: The stroke color.
	public func strokeRectangle(_ frame: Rectangle, color: EV3Color) {
		let command = EV3DrawRectCommand(color: fillColorFromColor(color), x: UInt16(frame.x), y: UInt16(frame.y), width: UInt16(frame.width), height: UInt16(frame.height))
		robot.device.enqueueCommand(command) { result in
			if case EV3CommandResult.error = result {
				print("The rectangle could not be drawn.")
			}
		}

		if !isDrawingDeferred {
			updateDisplay()
			robot.device.waitForOperations()
		}
	}

	/// Inverts colors in a given frame.
	///
	/// Given the EV3 has a 1-bit display, this method causes black colors to become white and white colors to become black.
	///
	/// This method blocks the caller until drawing is finished.
	/// Drawing can be deferred by calling this method from within a display update batch.
	///
	/// **Note:** The EV3's display has a resolution of 178x128 pixels.
	///
	/// - parameter frame: The frame to invert, whose origin is specified relative to the top-left corner of the screen.
	public func invertColors(inFrame frame: Rectangle) {
		let command = EV3InvertRectCommand(x: UInt16(frame.x), y: UInt16(frame.y), width: UInt16(frame.width), height: UInt16(frame.height))
		robot.device.enqueueCommand(command) { result in
			if case EV3CommandResult.error = result {
				print("The area could not be inverted.")
			}
		}

		if !isDrawingDeferred {
			updateDisplay()
			robot.device.waitForOperations()
		}
	}

	/// Draws a single pixel.
	///
	/// This method blocks the caller until drawing is finished.
	/// Drawing can be deferred by calling this method from within a display update batch.
	///
	/// **Note:** The EV3's display has a resolution of 178x128 pixels.
	///
	/// - parameter point: The position in pixels relative to the top-left corner of the screen.
	/// - parameter color: The fill color.
	public func drawPixel(at point: Point, color: EV3Color) {
		let command = EV3DrawPixelCommand(color: fillColorFromColor(color), x: UInt16(point.x), y: UInt16(point.y))
		robot.device.enqueueCommand(command) { result in
			if case EV3CommandResult.error = result {
				print("The pixel could not be drawn.")
			}
		}

		if !isDrawingDeferred {
			updateDisplay()
			robot.device.waitForOperations()
		}
	}

	/// Draws a line with a thickness of 1 pixel.
	///
	/// This method blocks the caller until drawing is finished.
	/// Drawing can be deferred by calling this method from within a display update batch.
	///
	/// **Note:** The EV3's display has a resolution of 178x128 pixels.
	///
	/// - parameter start: The start position in pixels relative to the top-left corner of the screen.
	/// - parameter end: The end position in pixels relative to the top-left corner of the screen.
	/// - parameter color: The fill color.
	public func drawLine(from start: Point, to end: Point, color: EV3Color) {
		let command = EV3DrawLineCommand(color: fillColorFromColor(color), x1: UInt16(start.x), y1: UInt16(start.y), x2: UInt16(end.x), y2: UInt16(end.y))
		robot.device.enqueueCommand(command) { result in
			if case EV3CommandResult.error = result {
				print("The line could not be drawn.")
			}
		}

		if !isDrawingDeferred {
			updateDisplay()
			robot.device.waitForOperations()
		}
	}

	/// Draws a dashed line with a thickness of 1 pixel.
	///
	/// This method blocks the caller until drawing is finished.
	/// Drawing can be deferred by calling this method from within a display update batch.
	///
	/// **Note:** The EV3's display has a resolution of 178x128 pixels.
	///
	/// - parameter start: The start position in pixels relative to the top-left corner of the screen.
	/// - parameter end: The end position in pixels relative to the top-left corner of the screen.
	/// - parameter color: The fill color.
	/// - parameter runLength: The length of runs of pixels in the given fill color.
	/// - parameter gapLength: The length of the gaps between runs.
	public func drawDashedLine(from start: Point, to end: Point, color: EV3Color, runLength: Int, gapLength: Int) {
		let command = EV3DrawDotlineCommand(color: fillColorFromColor(color), x1: UInt16(start.x), y1: UInt16(start.y), x2: UInt16(end.x), y2: UInt16(end.y), onPixels: UInt16(runLength), offPixels: UInt16(gapLength))
		robot.device.enqueueCommand(command) { result in
			if case EV3CommandResult.error = result {
				print("The dashed line could not be drawn.")
			}
		}

		if !isDrawingDeferred {
			updateDisplay()
			robot.device.waitForOperations()
		}
	}

	/// Draws a bitmap of type RGF.
	///
	/// This method treats the bitmap as a mask and lets you draw it with any supported color.
	///
	/// Example:
	///
	/// ```
	/// // Draws the LEGO Mindstorms logo in the top-left corner of the window.
	/// let robot = EV3Robot()
	/// robot.drawBitmapAtPath("../sys/ui/mindstorms.rgf", point: Point(x: 0, y: a.statusBarHeight), withColor: .Black)
	/// ```
	///
	/// This method blocks the caller until drawing is finished.
	/// Drawing can be deferred by calling this method from within a display update batch.
	///
	/// **Note:** The EV3's display has a resolution of 178x128 pixels.
	///
	/// - parameter filePath: The path of the bitmap relative to the `sys` directory on the EV3.
	/// - parameter point: The position in pixels relative to the top-left corner of the screen.
	/// - parameter color: The fill color.
	public func drawBitmap(filePath: String, at point: Point, color: EV3Color) {
		let command = EV3DrawBitmapCommand(color: fillColorFromColor(color), x: UInt16(point.x), y: UInt16(point.y), name: filePath)
		robot.device.enqueueCommand(command) { result in
			if case EV3CommandResult.error = result {
				print("The bitmap could not be drawn.")
			}
		}

		if !isDrawingDeferred {
			updateDisplay()
			robot.device.waitForOperations()
		}
	}

	/// Draws text.
	///
	/// This method blocks the caller until drawing is finished.
	/// Drawing can be deferred by calling this method from within a display update batch.
	///
	/// **Note:** The EV3's display has a resolution of 178x128 pixels.
	///
	/// - parameter text: The text to draw.
	/// - parameter fontSize: The font size to use for drawing.
	/// - parameter point: The position in pixels relative to the top-left corner of the screen.
	/// - parameter color: The fill color.
	public func drawText(_ text: String, fontSize: EV3FontSize, at point: Point, color: EV3Color) {
		let command = EV3DrawTextCommand(color: fillColorFromColor(color), x: UInt16(point.x), y: UInt16(point.y), string: text, fontSize: fontSizeConstFromSize(fontSize))
		robot.device.enqueueCommand(command) { result in
			if case EV3CommandResult.error = result {
				print("The text could not be drawn.")
			}
		}

		if !isDrawingDeferred {
			updateDisplay()
			robot.device.waitForOperations()
		}
	}

	/// Returns the width of the EV3's display resolution in pixels.
	public var displayWidth: Int {
		return Int(EV3DisplayWidth)
	}

	/// Returns the height of the EV3's display resolution in pixels.
	public var displayHeight: Int {
		return Int(EV3DisplayHeight)
	}

	/// Returns the height of the EV3's status bar in pixels.
	public var statusBarHeight: Int {
		return Int(EV3TopLineHeight)
	}

	private func setStatusBarEnabled(_ enabled: Bool) {
		let command = EV3EnableToplineCommand(enable: enabled)
		robot.device.enqueueCommand(command) { result in
			if case EV3CommandResult.error = result {
				print("The status bar could not be toggled.")
			}
		}

		updateDisplay()
		robot.device.waitForOperations()
	}

	/// Displays the status bar typically found near the top edge of the screen.
	public func showStatusBar() {
		setStatusBarEnabled(true)
	}

	/// Hides the status bar typically found near the top edge of the screen.
	public func hideStatusBar() {
		setStatusBarEnabled(false)
	}

	/// Waits until all drawing operations have completed before updating the display.
	///
	/// By default, the EV3's display is refreshed after every drawing operation. To improve performance and reduce flickering, multiple draw calls can be batched together using this method. The display will only be refreshed once at the end of the drawing cycle.
	///
	/// - parameter updateBlock: The block in which drawing updates happen.
	public func batchDisplayUpdates(_ updateBlock: () -> ()) {
		robot.deferredDrawingTransactions += 1
		updateBlock()
		robot.deferredDrawingTransactions -= 1

		assert(robot.deferredDrawingTransactions >= 0)
		
		updateDisplay()
		robot.device.waitForOperations()
	}
}

extension EV3Robot {
	/// Provides access to on-screen drawing functionality.
	public var window: EV3Window {
		return EV3Window(robot: self)
	}
}
