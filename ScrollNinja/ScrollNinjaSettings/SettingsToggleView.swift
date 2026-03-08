//
//  SettingsToggleView.swift
//  ScrollNinja
//
//  Created by Ethan Whited on 3/8/26.
//

import SwiftUI

struct SettingsToggleView: View {
    @ObservedObject var scrollManager: ScrollManager
    var color: Color
    var icon: String
    var title: String
    var subtitle: String
    @Binding var toggle: Bool

    var body: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
                    .aspectRatio(1.0, contentMode: .fit)
                    .frame(height: 35)
                Image(systemName: icon)
                    .renderingMode(.template)
                    .foregroundColor(.white)
                    .font(.title)
            }
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $toggle)
                .toggleStyle(.switch)
                .tint(.green)
        }
    }
}
