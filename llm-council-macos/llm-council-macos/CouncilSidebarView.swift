//
//  CouncilSidebarView.swift
//  LLM Council
//
//  Created by Codex on 2026-03-08.
//

import SwiftUI

struct CouncilSidebarView: View {
    @ObservedObject var chrome: WorkspaceChromeState
    @State private var isClearHistoryConfirmationPresented = false

    let activeProviderCount: Int
    let totalProviderCount: Int
    let providers: [ProviderDefinition]
    let paneStates: [ProviderID: ProviderPaneState]
    let historyEntries: [PromptHistoryEntry]
    let promptPresets: [PromptPreset]
    let savedSessions: [SavedWorkspaceSession]
    let onSelectWorkspace: () -> Void
    let onSelectProvider: (ProviderID) -> Void
    let onSetProviderVisible: (ProviderID, Bool) -> Void
    let onToggleProviderInclude: (ProviderID) -> Void
    let onApplyHistory: (PromptHistoryEntry) -> Void
    let onDeleteHistoryEntry: (PromptHistoryEntry) -> Void
    let onClearHistory: () -> Void
    let onApplyPreset: (PromptPreset) -> Void
    let onRestoreSession: (SavedWorkspaceSession) -> Void

    var body: some View {
        List(selection: sidebarSelectionBinding) {
            workspaceSection
            providersSection

            if shouldShowGetStarted {
                getStartedSection
            } else {
                historySection
                presetsSection
                savedSessionsSection
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(.bar)
        .navigationTitle("Council")
        .confirmationDialog(
            "Clear history?",
            isPresented: $isClearHistoryConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) {
                chrome.revealSection(.history)
                onClearHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all prompt history entries from the sidebar.")
        }
        .onChange(of: chrome.sidebarSelection) { _, selection in
            switch selection {
            case .workspace:
                onSelectWorkspace()
            case .providers:
                chrome.selectProviders()
            case let .provider(providerID):
                onSelectProvider(providerID)
            case .history, .presets, .savedSessions, nil:
                break
            }
        }
    }

    private var sidebarSelectionBinding: Binding<WorkspaceSidebarSelection?> {
        Binding(
            get: { chrome.sidebarSelection },
            set: { chrome.sidebarSelection = $0 }
        )
    }

    private var workspaceSection: some View {
        Section("Workspace") {
            SidebarSelectionRow(
                title: "Current Workspace",
                subtitle: "\(activeProviderCount) of \(totalProviderCount) providers visible",
                providerID: nil,
                selection: .workspace,
                currentSelection: chrome.sidebarSelection
            )
            .tag(WorkspaceSidebarSelection.workspace)
        }
    }

    private var providersSection: some View {
        Section("Providers") {
            ForEach(providers) { provider in
                SidebarSelectionRow(
                    title: provider.displayName,
                    subtitle: providerSubtitle(for: provider.id),
                    providerID: provider.id,
                    selection: .provider(provider.id),
                    currentSelection: chrome.sidebarSelection,
                    state: rowState(for: provider.id),
                    onToggleSend: {
                        onToggleProviderInclude(provider.id)
                    }
                )
                .tag(WorkspaceSidebarSelection.provider(provider.id))
                .contextMenu {
                    if paneState(for: provider.id).isVisible {
                        Button("Hide Provider") {
                            onSetProviderVisible(provider.id, false)
                        }
                    } else {
                        Button("Reveal Provider") {
                            onSetProviderVisible(provider.id, true)
                            onSelectProvider(provider.id)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if !historyEntries.isEmpty {
            Section {
                ForEach(historyEntries.prefix(8)) { entry in
                    Button {
                        chrome.revealSection(.history)
                        onApplyHistory(entry)
                    } label: {
                        SidebarActionRow(
                            title: entry.text,
                            subtitle: entry.createdAt.formatted(date: .abbreviated, time: .shortened),
                            systemName: "clock.arrow.circlepath"
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            onDeleteHistoryEntry(entry)
                        }
                    }
                }
            } header: {
                HStack(spacing: CouncilSpacing.sm) {
                    Text("History")
                    Spacer()
                    Button("Clear") {
                        isClearHistoryConfirmationPresented = true
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    @ViewBuilder
    private var presetsSection: some View {
        if !promptPresets.isEmpty {
            Section("Presets") {
                ForEach(promptPresets.prefix(8)) { preset in
                    Button {
                        chrome.revealSection(.presets)
                        onApplyPreset(preset)
                    } label: {
                        SidebarActionRow(
                            title: preset.title,
                            subtitle: preset.prompt,
                            systemName: "bookmark"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var savedSessionsSection: some View {
        if !savedSessions.isEmpty {
            Section("Saved Sessions") {
                ForEach(savedSessions.prefix(8)) { session in
                    Button {
                        chrome.revealSection(.savedSessions)
                        onRestoreSession(session)
                    } label: {
                        SidebarActionRow(
                            title: session.name,
                            subtitle: session.updatedAt.formatted(date: .abbreviated, time: .shortened),
                            systemName: "externaldrive"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var getStartedSection: some View {
        Section {
            VStack(alignment: .leading, spacing: CouncilSpacing.sm) {
                Label("Get Started", systemImage: "sparkles")
                    .font(CouncilTypography.sectionTitle)
                Text("Select a provider, type a prompt in the composer, and save presets or sessions as you work.")
                    .font(CouncilTypography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, CouncilSpacing.xs)
        }
    }

    private var shouldShowGetStarted: Bool {
        historyEntries.isEmpty && promptPresets.isEmpty && savedSessions.isEmpty && activeProviderCount == 0
    }

    private func paneState(for providerID: ProviderID) -> ProviderPaneState {
        paneStates[providerID] ?? ProviderPaneState.initialState(for: providerID)
    }

    private func providerSubtitle(for providerID: ProviderID) -> String {
        let paneState = paneState(for: providerID)
        if paneState.isVisible {
            return paneState.automationState.message
        }
        return "Hidden"
    }

    private func rowState(for providerID: ProviderID) -> SidebarSelectionRow.RowState {
        let paneState = paneState(for: providerID)
        if paneState.isVisible {
            return paneState.isIncludedInSend ? .sendEnabled : .visibleOnly
        }
        return .hidden
    }
}

private struct SidebarSelectionRow: View {
    enum RowState {
        case sendEnabled
        case visibleOnly
        case hidden
    }

    let title: String
    let subtitle: String
    let providerID: ProviderID?
    let selection: WorkspaceSidebarSelection
    let currentSelection: WorkspaceSidebarSelection?
    var state: RowState? = nil
    var onToggleSend: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: CouncilSpacing.md) {
            ProviderSidebarGlyph(providerID: providerID, isSelected: currentSelection == selection)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CouncilTypography.detail)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                Text(subtitle)
                    .font(CouncilTypography.meta)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: CouncilSpacing.sm)

            if let state {
                trailingView(for: state)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func trailingView(for state: RowState) -> some View {
        switch state {
        case .sendEnabled:
            Button("Send") {
                onToggleSend?()
            }
            .buttonStyle(.borderless)
            .font(CouncilTypography.compactPill)
            .foregroundStyle(currentSelection == selection ? Color.primary : Color.accentColor)
            .help("Exclude this provider from the shared send action.")
        case .visibleOnly:
            Button("View") {
                onToggleSend?()
            }
            .buttonStyle(.borderless)
            .font(CouncilTypography.meta)
            .foregroundStyle(.secondary)
            .help("Include this provider in the shared send action.")
        case .hidden:
            Label("Hidden", systemImage: "eye.slash")
                .font(CouncilTypography.meta)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SidebarActionRow: View {
    let title: String
    let subtitle: String
    let systemName: String

    var body: some View {
        HStack(spacing: CouncilSpacing.md) {
            Image(systemName: systemName)
                .font(CouncilTypography.compactIcon)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CouncilTypography.detail)
                    .lineLimit(1)
                Text(subtitle)
                    .font(CouncilTypography.meta)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

private struct ProviderSidebarGlyph: View {
    let providerID: ProviderID?
    let isSelected: Bool

    var body: some View {
        Text(symbolText)
            .font(CouncilTypography.microIcon)
            .foregroundStyle(.white)
            .frame(width: CouncilMetrics.glyphSize, height: CouncilMetrics.glyphSize)
            .background(
                Circle()
                    .fill(isSelected ? accentColor : accentColor.opacity(0.68))
            )
    }

    private var symbolText: String {
        switch providerID {
        case .chatGPT:
            return "C"
        case .claude:
            return "C"
        case .gemini:
            return "G"
        case .grok:
            return "G"
        case .perplexity:
            return "P"
        case .deepSeek:
            return "D"
        case nil:
            return "W"
        }
    }

    private var accentColor: Color {
        switch providerID {
        case .chatGPT:
            return Color(red: 0.13, green: 0.51, blue: 0.95)
        case .claude:
            return Color(red: 0.45, green: 0.45, blue: 0.47)
        case .gemini:
            return Color(red: 0.37, green: 0.52, blue: 0.98)
        case .grok:
            return Color(red: 0.48, green: 0.48, blue: 0.5)
        case .perplexity:
            return Color(red: 0.35, green: 0.35, blue: 0.38)
        case .deepSeek:
            return Color(red: 0.4, green: 0.45, blue: 0.5)
        case nil:
            return .secondary
        }
    }
}
