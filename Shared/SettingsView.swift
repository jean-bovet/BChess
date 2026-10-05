//
//  SettingsView.swift
//  BChess (macOS)
//
//  Created by Jean Bovet on 4/17/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("useTranspositionTable") private var ttTable = false

    @AppStorage("showEngineStatistics") private var showStatistics = false

    var body: some View {
        Form {
            Toggle("Use Transposition Table (Beta)", isOn: $ttTable)
            Toggle("Show engine statistics", isOn: $showStatistics)
        }
        .padding(20)
        .frame(width: 350, height: 120)
    }
}

#Preview {
    SettingsView()
}
