//
//  ScrollNinjaContentView.swift
//  ScrollNinja
//
//  Created by Ethan Whited on 3/8/26.
//

import SwiftUI

struct ScrollNinjaContentView: View {
    @ObservedObject var scrollManager: ScrollManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(Font.largeTitle.bold())
                .padding(.bottom, 5)

            SettingsToggleView(scrollManager:scrollManager, color:.blue, icon:"gear", title:"Enable", subtitle:"Enable/Disable auto-scroll.", toggle:$scrollManager.isEnabled)
            
            SettingsToggleView(scrollManager:scrollManager, color:.pink, icon:"pointer.arrow.ipad", title:"Indicator", subtitle:"Show/Hide the arrow indicators.", toggle:$scrollManager.showHUD)
            
            SettingsToggleView(scrollManager:scrollManager, color:.indigo, icon:"keyboard.fill", title:"Launch", subtitle:"Allow/Disallow ScrollNinja to launch at login.", toggle:$scrollManager.launchAtLogin)
            
            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit ScrollNinja", systemImage: "power")
                    .font(Font.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .tint(.red)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle)
            .padding()
            
            Divider()

            HStack {
                Spacer()
                if let nsImage = NSImage(named: "AppIcon") {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .cornerRadius(4)
                }
                Text("ScrollNinja 1.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(20)
        .frame(width: 300)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
    }
}


// MARK: - Preview
#Preview {
    ScrollNinjaContentView(scrollManager: ScrollManager())
}
