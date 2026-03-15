//
//  WorkspaceStore.swift
//  LLM Council
//
//

import Combine
import Foundation

struct UserDefaultsWorkspacePersistence: WorkspacePersisting {
    private let defaults: UserDefaults
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        defaults: UserDefaults = .standard,
        key: String = "llm-council.workspace.snapshot.v1"
    ) {
        self.defaults = defaults
        self.key = key
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func load() -> WorkspaceSnapshot? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? decoder.decode(WorkspaceSnapshot.self, from: data)
    }

    func save(_ snapshot: WorkspaceSnapshot) {
        guard let data = try? encoder.encode(snapshot) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}

@MainActor
final class WorkspaceStore: ObservableObject {
    static let maxHistoryCount = 100
    static let minPageZoom = 0.6
    static let maxPageZoom = 1.6
    static let pageZoomStep = 0.1

    @Published private(set) var providers: [ProviderDefinition]
    @Published private(set) var paneOrder: [ProviderID]
    @Published private(set) var paneStates: [ProviderID: ProviderPaneState]
    @Published private(set) var layoutPresets: [WorkspaceLayoutPreset]
    @Published var focusedProviderID: ProviderID?

    @Published var composerText = ""
    @Published var pageZoom = 1.0
    @Published var sendScope: ComposerSendScope = .allVisible
    @Published var clearComposerAfterSend = true
    @Published private(set) var dispatchState: PromptDispatchState = .idle

    @Published private(set) var promptHistory: [PromptHistoryEntry]
    @Published private(set) var promptPresets: [PromptPreset]
    @Published private(set) var savedSessions: [SavedWorkspaceSession]

    private let persistence: WorkspacePersisting

    var focusModeEnabled: Bool {
        focusedProviderID != nil
    }

    init(
        providers: [ProviderDefinition]? = nil,
        layoutPresets: [WorkspaceLayoutPreset]? = nil,
        persistence: WorkspacePersisting? = nil
    ) {
        let resolvedProviders = providers ?? BuiltInProviders.definitions
        let resolvedPresets = layoutPresets ?? BuiltInLayoutPresets.all

        self.providers = resolvedProviders
        self.layoutPresets = resolvedPresets
        self.persistence = persistence ?? UserDefaultsWorkspacePersistence()
        paneOrder = resolvedProviders.map(\.id)
        paneStates = WorkspaceStore.makeDefaultPaneStates(for: resolvedProviders)
        promptHistory = []
        promptPresets = []
        savedSessions = []
        restore()
    }

    var orderedProviders: [ProviderDefinition] {
        let byID = Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0) })
        return paneOrder.compactMap { byID[$0] }
    }

    var orderedVisibleProviders: [ProviderDefinition] {
        orderedProviders.filter { state(for: $0.id).isVisible }
    }

    var dispatchProviderIDs: [ProviderID] {
        let visible = orderedVisibleProviders.map(\.id)
        switch sendScope {
        case .allVisible:
            return visible
        case .includedOnly:
            return visible.filter { state(for: $0).isIncludedInSend }
        }
    }

    func definition(for providerID: ProviderID) -> ProviderDefinition? {
        BuiltInProviders.byID[providerID]
    }

    func state(for providerID: ProviderID) -> ProviderPaneState {
        paneStates[providerID] ?? ProviderPaneState.initialState(for: providerID)
    }

    func replacePaneState(_ paneState: ProviderPaneState) {
        paneStates[paneState.providerID] = paneState
    }

    func setPaneVisibility(_ providerID: ProviderID, isVisible: Bool) {
        mutatePane(providerID) { pane in
            pane.isVisible = isVisible
            if !isVisible {
                pane.isIncludedInSend = false
            }
        }
        if focusedProviderID == providerID, !isVisible {
            focusedProviderID = nil
        }
        persist()
    }

    func setIncludedInSend(_ providerID: ProviderID, isIncluded: Bool) {
        mutatePane(providerID) { pane in
            pane.isIncludedInSend = pane.isVisible ? isIncluded : false
        }
        persist()
    }

    func setFocusedProvider(_ providerID: ProviderID?) {
        focusedProviderID = providerID
        persist()
    }

    func toggleFocusMode() {
        if focusedProviderID == nil {
            focusedProviderID = orderedVisibleProviders.first?.id
        } else {
            focusedProviderID = nil
        }
        persist()
    }

    func updateNavigationState(
        for providerID: ProviderID,
        url: URL?,
        title: String?,
        estimatedProgress: Double,
        canGoBack: Bool,
        canGoForward: Bool
    ) {
        mutatePane(providerID) { pane in
            pane.lastKnownURLString = url?.absoluteString
            pane.lastPageTitle = title
            pane.estimatedProgress = estimatedProgress
            pane.canGoBack = canGoBack
            pane.canGoForward = canGoForward
        }
    }

    func setAutomationState(_ providerID: ProviderID, level: AutomationStateLevel, message: String) {
        mutatePane(providerID) { pane in
            pane.automationState = ProviderAutomationState(level: level, message: message, updatedAt: .now)
        }
    }

    func applyLayoutPreset(_ presetID: LayoutPresetID) {
        guard let preset = layoutPresets.first(where: { $0.id == presetID }) else {
            return
        }
        applyLayoutPreset(preset)
    }

    func applyLayoutPreset(_ preset: WorkspaceLayoutPreset) {
        let visibleSet = Set(preset.visibleProviderIDs)
        for provider in providers {
            mutatePane(provider.id) { pane in
                pane.isVisible = visibleSet.contains(provider.id)
                pane.isIncludedInSend = pane.isVisible
            }
        }
        focusedProviderID = preset.focusedProviderID
        paneOrder = normalizedPaneOrder(paneOrder, available: providers.map(\.id))
        persist()
    }

    @discardableResult
    func registerPromptSend(now: Date = .now) -> String {
        let normalized = WorkspaceStore.normalizedPrompt(composerText)
        guard !normalized.isEmpty else {
            return ""
        }
        promptHistory = WorkspaceStore.upsertHistory(promptHistory, prompt: normalized, now: now)
        if clearComposerAfterSend {
            composerText = ""
        }
        persist()
        return normalized
    }

    func updateComposer(with prompt: String) {
        composerText = prompt
    }

    func addOrUpdatePreset(title: String, prompt: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPrompt = WorkspaceStore.normalizedPrompt(prompt)
        guard !cleanTitle.isEmpty, !cleanPrompt.isEmpty else {
            return
        }

        if let index = promptPresets.firstIndex(where: { $0.title.caseInsensitiveCompare(cleanTitle) == .orderedSame }) {
            promptPresets[index].prompt = cleanPrompt
            promptPresets[index].updatedAt = .now
        } else {
            promptPresets.insert(PromptPreset(title: cleanTitle, prompt: cleanPrompt), at: 0)
        }
        persist()
    }

    func applyPreset(_ presetID: UUID) {
        guard let preset = promptPresets.first(where: { $0.id == presetID }) else {
            return
        }
        composerText = preset.prompt
    }

    func deletePreset(_ presetID: UUID) {
        promptPresets.removeAll { $0.id == presetID }
        persist()
    }

    func deleteHistoryEntry(_ entryID: UUID) {
        let originalCount = promptHistory.count
        promptHistory.removeAll { $0.id == entryID }
        guard promptHistory.count != originalCount else {
            return
        }
        persist()
    }

    func clearHistory() {
        promptHistory.removeAll()
        persist()
    }

    @discardableResult
    func saveCurrentSession(named name: String, now: Date = .now) -> SavedWorkspaceSession? {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else {
            return nil
        }

        let session = makeSavedSession(name: cleanedName, now: now)
        savedSessions.insert(session, at: 0)
        persist()
        return session
    }

    @discardableResult
    func applySavedSession(_ sessionID: UUID) -> Bool {
        guard let session = savedSessions.first(where: { $0.id == sessionID }) else {
            return false
        }

        let available = providers.map(\.id)
        let availableSet = Set(available)
        let visibleIDs = uniqueProviderIDs(session.visibleProviderIDs.filter { availableSet.contains($0) })
        let visibleSet = Set(visibleIDs)
        let includedSet = Set(
            uniqueProviderIDs(session.includedInSendProviderIDs.filter { availableSet.contains($0) })
        )
        let normalizedURLs = session.providerChatURLs.reduce(into: [ProviderID: String]()) { result, entry in
            guard availableSet.contains(entry.key) else {
                return
            }
            let value = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else {
                return
            }
            result[entry.key] = value
        }

        paneOrder = normalizedPaneOrder(session.paneOrder, available: available)
        for provider in providers {
            mutatePane(provider.id) { pane in
                let isVisible = visibleSet.contains(provider.id)
                pane.isVisible = isVisible
                pane.isIncludedInSend = isVisible && includedSet.contains(provider.id)
                pane.lastKnownURLString = normalizedURLs[provider.id]
            }
        }

        if let focus = session.focusedProviderID, visibleSet.contains(focus) {
            focusedProviderID = focus
        } else {
            focusedProviderID = nil
        }
        composerText = session.composerDraft
        persist()
        return true
    }

    func deleteSavedSession(_ sessionID: UUID) {
        let originalCount = savedSessions.count
        savedSessions.removeAll { $0.id == sessionID }
        guard savedSessions.count != originalCount else {
            return
        }
        persist()
    }

    @discardableResult
    func renameSavedSession(_ sessionID: UUID, to newName: String, now: Date = .now) -> Bool {
        let cleanedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else {
            return false
        }
        guard let index = savedSessions.firstIndex(where: { $0.id == sessionID }) else {
            return false
        }
        savedSessions[index].name = cleanedName
        savedSessions[index].updatedAt = now
        persist()
        return true
    }

    func persist() {
        persistence.save(snapshot())
    }

    func beginPromptBootstrap(prompt: String, targets: [ProviderID], now: Date = .now) {
        dispatchState = PromptDispatchState(
            phase: .bootstrapping,
            message: targets.isEmpty ? "Preparing workspace" : "Preparing \(targets.count) provider\(targets.count == 1 ? "" : "s")",
            targetProviderIDs: targets,
            successfulProviderIDs: [],
            failedProviderIDs: [],
            lastPrompt: prompt,
            lastUpdatedAt: now
        )
    }

    func beginPromptDispatch(prompt: String, targets: [ProviderID], now: Date = .now) {
        dispatchState = PromptDispatchState(
            phase: .sending,
            message: "Sending to \(targets.count) provider\(targets.count == 1 ? "" : "s")",
            targetProviderIDs: targets,
            successfulProviderIDs: [],
            failedProviderIDs: [],
            lastPrompt: prompt,
            lastUpdatedAt: now
        )
    }

    func completePromptDispatch(results: [WebAutomationResult], prompt: String, now: Date = .now) {
        let successful = results.filter(\.success).map(\.providerID)
        let failed = results.filter { !$0.success }.map(\.providerID)
        let phase: PromptDispatchPhase = failed.isEmpty ? .succeeded : .failed
        let message: String
        if results.isEmpty {
            message = "No providers available."
        } else if failed.isEmpty {
            message = "Sent to \(successful.count)/\(results.count)"
        } else if successful.isEmpty {
            message = "Send failed for \(failed.count)/\(results.count)"
        } else {
            message = "Sent to \(successful.count)/\(results.count), \(failed.count) failed"
        }

        dispatchState = PromptDispatchState(
            phase: phase,
            message: message,
            targetProviderIDs: results.map(\.providerID),
            successfulProviderIDs: successful,
            failedProviderIDs: failed,
            lastPrompt: prompt,
            lastUpdatedAt: now
        )
    }

    func cancelPromptDispatchTracking(now: Date = .now) {
        guard dispatchState.isActive else {
            return
        }

        dispatchState.phase = .cancelled
        dispatchState.message = "Dispatch tracking cancelled."
        dispatchState.lastUpdatedAt = now
    }

    func resetPromptDispatchState(now: Date = .now) {
        dispatchState = .idle
        dispatchState.lastUpdatedAt = now
    }

    func markPromptDispatchBootstrapFailed(prompt: String, targets: [ProviderID], message: String, now: Date = .now) {
        dispatchState = PromptDispatchState(
            phase: .failed,
            message: message,
            targetProviderIDs: targets,
            successfulProviderIDs: [],
            failedProviderIDs: targets,
            lastPrompt: prompt,
            lastUpdatedAt: now
        )
    }

    func requestSendCurrentPrompt() {
        NotificationCenter.default.post(name: .councilSendPrompt, object: nil)
    }

    func requestNewChatOnAllTargets() {
        NotificationCenter.default.post(name: .councilNewChatAll, object: nil)
    }

    func zoomIn() {
        setPageZoom(pageZoom + WorkspaceStore.pageZoomStep)
    }

    func zoomOut() {
        setPageZoom(pageZoom - WorkspaceStore.pageZoomStep)
    }

    func resetZoom() {
        setPageZoom(1.0)
    }

    func setPageZoom(_ value: Double) {
        let clamped = WorkspaceStore.clampZoom(value)
        if abs(clamped - pageZoom) < 0.001 {
            return
        }
        pageZoom = clamped
        persist()
    }

    static func normalizedPrompt(_ prompt: String) -> String {
        prompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r\n", with: "\n")
    }

    static func upsertHistory(
        _ history: [PromptHistoryEntry],
        prompt: String,
        now: Date = .now,
        maxCount: Int = 100
    ) -> [PromptHistoryEntry] {
        let normalized = normalizedPrompt(prompt)
        guard !normalized.isEmpty else {
            return history
        }

        var updated = history.filter { normalizedPrompt($0.text) != normalized }
        updated.insert(PromptHistoryEntry(text: normalized, createdAt: now), at: 0)
        if updated.count > maxCount {
            updated.removeLast(updated.count - maxCount)
        }
        return updated
    }

    static func clampZoom(_ zoom: Double) -> Double {
        let clamped = min(max(zoom, minPageZoom), maxPageZoom)
        return (clamped * 100).rounded() / 100
    }

    private func restore() {
        guard let restored = persistence.load() else {
            return
        }

        paneOrder = normalizedPaneOrder(restored.paneOrder, available: providers.map(\.id))
        let restoredMap = Dictionary(uniqueKeysWithValues: restored.paneStates.map { ($0.providerID, $0) })
        paneStates = WorkspaceStore.makeDefaultPaneStates(for: providers).merging(restoredMap) { _, restored in
            restored
        }
        pageZoom = WorkspaceStore.clampZoom(restored.pageZoom)
        focusedProviderID = restored.focusedProviderID
        sendScope = restored.sendScope
        clearComposerAfterSend = restored.clearComposerAfterSend
        promptHistory = restored.promptHistory
        promptPresets = restored.promptPresets

        let availableIDs = providers.map(\.id)
        var seenIDs = Set<UUID>()
        var normalizedSessions: [SavedWorkspaceSession] = []
        for session in restored.savedSessions where seenIDs.insert(session.id).inserted {
            normalizedSessions.append(normalizedSavedSession(session, available: availableIDs))
        }
        savedSessions = normalizedSessions
    }

    private func snapshot() -> WorkspaceSnapshot {
        let orderedPaneStates = paneOrder.map { state(for: $0) }
        return WorkspaceSnapshot(
            schemaVersion: WorkspaceSnapshot.currentSchemaVersion,
            pageZoom: pageZoom,
            paneStates: orderedPaneStates,
            paneOrder: paneOrder,
            focusedProviderID: focusedProviderID,
            sendScope: sendScope,
            clearComposerAfterSend: clearComposerAfterSend,
            promptHistory: promptHistory,
            promptPresets: promptPresets,
            savedSessions: savedSessions
        )
    }

    private func makeSavedSession(name: String, now: Date) -> SavedWorkspaceSession {
        let orderedPaneStates = paneOrder.map { state(for: $0) }
        let visible = orderedPaneStates.filter(\.isVisible).map(\.providerID)
        let included = orderedPaneStates.filter { $0.isVisible && $0.isIncludedInSend }.map(\.providerID)
        let urls = orderedPaneStates.reduce(into: [ProviderID: String]()) { result, pane in
            guard let url = pane.lastKnownURLString?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !url.isEmpty
            else {
                return
            }
            result[pane.providerID] = url
        }

        return SavedWorkspaceSession(
            name: name,
            createdAt: now,
            updatedAt: now,
            focusedProviderID: focusedProviderID,
            visibleProviderIDs: visible,
            includedInSendProviderIDs: included,
            paneOrder: paneOrder,
            composerDraft: composerText,
            providerChatURLs: urls
        )
    }

    private func mutatePane(_ providerID: ProviderID, update: (inout ProviderPaneState) -> Void) {
        var pane = state(for: providerID)
        update(&pane)
        paneStates[providerID] = pane
    }

    private static func makeDefaultPaneStates(for providers: [ProviderDefinition]) -> [ProviderID: ProviderPaneState] {
        var states: [ProviderID: ProviderPaneState] = [:]
        for provider in providers {
            states[provider.id] = ProviderPaneState.initialState(
                for: provider.id,
                visible: provider.defaultVisible
            )
        }
        return states
    }

    private func normalizedSavedSession(_ session: SavedWorkspaceSession, available: [ProviderID]) -> SavedWorkspaceSession {
        let availableSet = Set(available)
        let visible = uniqueProviderIDs(session.visibleProviderIDs.filter { availableSet.contains($0) })
        let visibleSet = Set(visible)
        let included = uniqueProviderIDs(session.includedInSendProviderIDs.filter { visibleSet.contains($0) })
        let normalizedURLs = session.providerChatURLs.reduce(into: [ProviderID: String]()) { result, entry in
            guard availableSet.contains(entry.key) else {
                return
            }
            let value = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else {
                return
            }
            result[entry.key] = value
        }

        let normalizedFocus: ProviderID?
        if let focus = session.focusedProviderID, visibleSet.contains(focus) {
            normalizedFocus = focus
        } else {
            normalizedFocus = nil
        }

        return SavedWorkspaceSession(
            id: session.id,
            name: session.name,
            createdAt: session.createdAt,
            updatedAt: session.updatedAt,
            focusedProviderID: normalizedFocus,
            visibleProviderIDs: visible,
            includedInSendProviderIDs: included,
            paneOrder: normalizedPaneOrder(session.paneOrder, available: available),
            composerDraft: session.composerDraft,
            providerChatURLs: normalizedURLs
        )
    }

    private func uniqueProviderIDs(_ ids: [ProviderID]) -> [ProviderID] {
        var seen = Set<ProviderID>()
        return ids.filter { seen.insert($0).inserted }
    }

    private func normalizedPaneOrder(_ current: [ProviderID], available: [ProviderID]) -> [ProviderID] {
        let availableSet = Set(available)
        var seen = Set<ProviderID>()
        var result: [ProviderID] = []

        for id in current where availableSet.contains(id) {
            guard seen.insert(id).inserted else {
                continue
            }
            result.append(id)
        }

        for id in available where seen.insert(id).inserted {
            result.append(id)
        }
        return result
    }
}
