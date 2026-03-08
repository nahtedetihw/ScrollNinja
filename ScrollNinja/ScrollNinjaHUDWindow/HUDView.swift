//
//  HUDView.swift
//  ScrollNinja
//
//  Created by Ethan Whited on 3/8/26.
//

import SwiftUI

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
