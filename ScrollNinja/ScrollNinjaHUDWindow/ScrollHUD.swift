//
//  ScrollHUD.swift
//  ScrollNinja
//
//  Created by Ethan Whited on 3/8/26.
//

import SwiftUI
import Combine

class ScrollHUD: NSPanel {
    class HUDState: ObservableObject {
        @Published var iconName: String = "circle.circle"
        @Published var isVisible: Bool = false
    }
    
    let state = HUDState()

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 60, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .mainMenu
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let hostingView = NSHostingView(rootView: HUDView(state: state))
        self.contentView = hostingView
    }
    
    func update(at point: CGPoint, dx: Int32, dy: Int32) {
        let threshold: Int32 = 15
        if abs(dy) > abs(dx) {
            state.iconName = dy > threshold ? "arrow.down.circle.fill" : (dy < -threshold ? "arrow.up.circle.fill" : "circle.circle")
        } else {
            state.iconName = dx > threshold ? "arrow.right.circle.fill" : (dx < -threshold ? "arrow.left.circle.fill" : "circle.circle")
        }
        
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let frame = NSRect(x: point.x - 30, y: screenHeight - point.y - 30, width: 60, height: 60)
        self.setFrame(frame, display: true)
        
        if !state.isVisible {
            state.isVisible = true
            self.makeKeyAndOrderFront(nil)
        }
    }
    
    func hide() {
        state.isVisible = false
        self.orderOut(nil)
    }
}
