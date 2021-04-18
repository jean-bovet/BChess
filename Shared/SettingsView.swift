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

    var body: some View {
        Form {
            Toggle("Use Transposition Table (Beta)", isOn: $ttTable)
        }
        .padding(20)
        .frame(width: 350, height: 100)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
