//
//  ScrollManager.swift
//  ScrollNinja
//
//  Created by Ethan Whited on 3/8/26.
//

import SwiftUI
import ServiceManagement
import Combine

class ScrollManager: ObservableObject {
    @AppStorage("isEnabled") var isEnabled: Bool = true
    @AppStorage("showHUD") var showHUD: Bool = true
    
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled {
        didSet {
            do {
                if launchAtLogin { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch { print("Launch update failed: \(error)") }
        }
    }
    
    private let friction: Double = 0.90
    private let velocityThreshold: Double = 0.5
    
    private var isScrolling = false
    private var anchorPoint: CGPoint = .zero
    private var scrollTimer: Timer?
    private var velX: Double = 0
    private var velY: Double = 0
    private var eventTap: CFMachPort?
    
    private let hud = ScrollHUD()

    init() { startEventTap() }

    func startEventTap() {
        let mask = (1 << NX_OMOUSEDOWN) | (1 << NX_OMOUSEUP) | (1 << NX_OMOUSEDRAGGED) | (1 << NX_MOUSEMOVED)
        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: UInt64(mask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let manager = Unmanaged<ScrollManager>.fromOpaque(refcon!).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tapPort = manager.eventTap { CGEvent.tapEnable(tap: tapPort, enable: true) }
                    return Unmanaged.passRetained(event)
                }
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            }, userInfo: observer
        ) else { return }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.eventTap = tap
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if !isEnabled { return Unmanaged.passRetained(event) }
        let mouseButton = event.getIntegerValueField(.mouseEventButtonNumber)
        
        if type == .otherMouseDown && mouseButton == 2 {
            isScrolling = true
            anchorPoint = event.location
            startScrollTimer()
            return nil
        }

        if type == .otherMouseUp && mouseButton == 2 {
            isScrolling = false
            DispatchQueue.main.async { self.hud.hide() }
            return nil
        }

        if isScrolling {
            let currentPoint = event.location
            let rawDx = Int32(currentPoint.x - anchorPoint.x)
            let rawDy = Int32(currentPoint.y - anchorPoint.y)
            
            velX = Double(rawDx) * -1 / 7
            velY = Double(rawDy) * -1 / 7
            
            if showHUD {
                DispatchQueue.main.async {
                    self.hud.update(at: self.anchorPoint, dx: rawDx, dy: rawDy)
                }
            }
            return nil
        }
        return Unmanaged.passRetained(event)
    }

    private func startScrollTimer() {
        scrollTimer?.invalidate()
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            if !self.isScrolling {
                self.velX *= self.friction
                self.velY *= self.friction
                
                if abs(self.velX) < self.velocityThreshold && abs(self.velY) < self.velocityThreshold {
                    self.stopScrollTimer()
                    return
                }
            }
            
            let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                                      wheel1: Int32(self.velY), wheel2: Int32(self.velX), wheel3: 0)
            scrollEvent?.post(tap: .cghidEventTap)
        }
    }

    private func stopScrollTimer() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        velX = 0; velY = 0
    }
}
