import SwiftUI
import CoreGraphics
import ApplicationServices
import ServiceManagement
import Combine

@main
struct ScrollNinjaApp: App {
    @StateObject private var scrollManager = ScrollManager()

    var body: some Scene {
        MenuBarExtra {
            Toggle("Enable Auto-Scroll", isOn: $scrollManager.isEnabled)
            
            Toggle("Show Visual Indicator", isOn: $scrollManager.showHUD)
                .disabled(!scrollManager.isEnabled)
            
            Divider()
            
            Toggle("Launch at Login", isOn: $scrollManager.launchAtLogin)
            
            Divider()
            
            Button("Quit ScrollNinja") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: "move.3d")
                .symbolVariant(scrollManager.isEnabled ? .none : .slash)
        }
    }
}

// MARK: - HUD Window
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

struct HUDView: View {
    @ObservedObject var state: ScrollHUD.HUDState
    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .clipShape(Circle())
            Image(systemName: state.iconName)
                .font(.system(size: 35, weight: .semibold))
                .foregroundColor(.white)
        }
        .opacity(state.isVisible ? 1 : 0)
        .scaleEffect(state.isVisible ? 1 : 0.8)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Scroll Logic
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
    
    // Momentum Constants
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
            // Let the timer handle the momentum decay
            return nil
        }

        if isScrolling {
            let currentPoint = event.location
            let rawDx = Int32(currentPoint.x - anchorPoint.x)
            let rawDy = Int32(currentPoint.y - anchorPoint.y)
            
            // Invert and calculate velocity
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
            // Decay logic if user released the button
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
