//
//  CouncilSettingsView.swift
//  LLM Council
//
//  Created by Codex on 2026-03-08.
//

import SwiftUI

struct CouncilSettingsView: View {
    @AppStorage("council.theme.selection") private var selectedThemeRawValue = CouncilTheme.Selection.system.persistedValue

    private var selectedThemeBinding: Binding<CouncilTheme.Selection> {
        Binding(
            get: { CouncilTheme.Selection(persistedValue: selectedThemeRawValue) },
            set: { selectedThemeRawValue = $0.persistedValue }
        )
    }

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Window Theme", selection: selectedThemeBinding) {
                    ForEach(CouncilTheme.Selection.pickerOptions) { selection in
                        Text(selection.displayName).tag(selection)
                    }
                }
                .pickerStyle(.segmented)

                Text("Use the system appearance by default. Light and dark overrides remain available for review work.")
                    .font(CouncilTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Workspace") {
                Text("LLM Council stays local-first. Provider sessions live in isolated website data stores, and workspace state persists on-device.")
                    .font(CouncilTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
    }
}

struct CouncilSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CouncilSettingsView()
    }
}
