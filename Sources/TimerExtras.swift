//
//  TimerExtras.swift
//  Robotary
//
//  Created by Matt on 6/25/16.
//

import Foundation

typealias EmptyTimerHandler = () -> ()

private final class TimerBlockHandler {
	let block: EmptyTimerHandler

	init(block: @escaping EmptyTimerHandler) {
		self.block = block
	}

	@objc func fire(_ timer: Timer) {
		block()
	}
}

extension Timer {
	@discardableResult class func scheduledTimerWithTimeInterval(_ interval: TimeInterval, block: @escaping EmptyTimerHandler) -> Timer {
		let handler = TimerBlockHandler(block: block)
		let timer = Timer(timeInterval: interval, target: handler, selector: #selector(TimerBlockHandler.fire), userInfo: nil, repeats: false)
		timer.fire()
		return timer
	}
}
