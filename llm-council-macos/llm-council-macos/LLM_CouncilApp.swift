//
//  LLM_CouncilApp.swift
//  LLM Council
//
//

import SwiftUI

@main
struct LLM_CouncilApp: App {
    @StateObject private var workspaceStore = WorkspaceStore()
    private let adapters = ProviderAdapterRegistry.adapters

    var body: some Scene {
        WindowGroup {
            ContentView(store: workspaceStore, adapters: adapters)
                .environment(\.font, CouncilTypography.body)
        }
        .commands {
            SidebarCommands()
            if #available(macOS 14.0, *) {
                InspectorCommands()
            }
            CouncilCommands(store: workspaceStore)
        }
        Settings {
            CouncilSettingsView()
                .environment(\.font, CouncilTypography.body)
        }
    }
}

private struct CouncilCommands: Commands {
    @ObservedObject var store: WorkspaceStore

    var body: some Commands {
        CommandMenu("Council") {
            Button("Send Prompt to Selected Providers") {
                store.requestSendCurrentPrompt()
            }
            .keyboardShortcut(.return, modifiers: [.command])

            Button(store.focusModeEnabled ? "Compare Visible Providers" : "Focus Selected Provider") {
                store.toggleFocusMode()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Button("New Chat in Visible Providers") {
                store.requestNewChatOnAllTargets()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("Toggle Inspector") {
                NotificationCenter.default.post(name: .councilToggleInspector, object: nil)
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])

            Button("Equalize Pane Widths") {
                NotificationCenter.default.post(name: .councilEqualizePanes, object: nil)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Button("Save Workspace Screenshot") {
                NotificationCenter.default.post(name: .councilCaptureWorkspaceScreenshot, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Divider()

            Button("Previous Pane Set") {
                NotificationCenter.default.post(name: .councilPageVisibleProvidersPrevious, object: nil)
            }
            .keyboardShortcut("[", modifiers: [.command])

            Button("Next Pane Set") {
                NotificationCenter.default.post(name: .councilPageVisibleProvidersNext, object: nil)
            }
            .keyboardShortcut("]", modifiers: [.command])

            Button("Zoom In Panes") {
                store.zoomIn()
            }
            .keyboardShortcut("=", modifiers: [.command])

            Button("Zoom Out Panes") {
                store.zoomOut()
            }
            .keyboardShortcut("-", modifiers: [.command])

            Button("Actual Size") {
                store.resetZoom()
            }
            .keyboardShortcut("0", modifiers: [.command])

            Divider()

            Button("Show Shortcut Legend") {
                NotificationCenter.default.post(name: .councilShowShortcutLegend, object: nil)
            }
            .keyboardShortcut("/", modifiers: [.command])

            ForEach(store.layoutPresets) { preset in
                Button("Apply \(preset.title)") {
                    store.applyLayoutPreset(preset)
                }
            }
        }
    }
}
