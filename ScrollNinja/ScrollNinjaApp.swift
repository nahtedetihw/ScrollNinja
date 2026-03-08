import SwiftUI

@main
struct ScrollNinjaApp: App {
    @StateObject private var scrollManager = ScrollManager()

    var body: some Scene {
        MenuBarExtra {
            ScrollNinjaContentView(scrollManager: scrollManager)
        } label: {
            if let nsImage = NSImage(named: "ScrollNinjaLogo") {
                Image(nsImage: nsImage)
                    .renderingMode(.template)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
