//
//  WebViewPane.swift
//  LLM Council
//
//

import AppKit
import Combine
import SwiftUI
import WebKit

@MainActor
final class WebViewHub: ObservableObject {
    private static let supportedURLSchemes: Set<String> = ["http", "https"]

    private var webViews: [ProviderID: WKWebView] = [:]
    private var currentZoom = 1.0

    func register(providerID: ProviderID, webView: WKWebView) {
        webViews[providerID] = webView
        webView.pageZoom = currentZoom
    }

    func cachedWebView(providerID: ProviderID) -> WKWebView? {
        webViews[providerID]
    }

    func goBack(providerID: ProviderID) {
        webViews[providerID]?.goBack()
    }

    func goForward(providerID: ProviderID) {
        webViews[providerID]?.goForward()
    }

    func reload(providerID: ProviderID) {
        webViews[providerID]?.reload()
    }

    @discardableResult
    func openHome(providerID: ProviderID) -> Bool {
        loadIntoMountedWebView(
            providerID: providerID,
            preferredURL: providerURL(for: providerID)?.homeURL,
            fallbackToHome: false
        )
    }

    @discardableResult
    func openNewChat(providerID: ProviderID) -> Bool {
        loadIntoMountedWebView(
            providerID: providerID,
            preferredURL: providerURL(for: providerID)?.newChatURL,
            fallbackToHome: true
        )
    }

    @discardableResult
    func openURL(providerID: ProviderID, url: URL, fallbackToHome: Bool = true) -> Bool {
        loadIntoMountedWebView(
            providerID: providerID,
            preferredURL: sanitizedURL(from: url, for: providerID),
            fallbackToHome: fallbackToHome
        )
    }

    @discardableResult
    func openURL(providerID: ProviderID, urlString: String?, fallbackToHome: Bool = true) -> Bool {
        loadIntoMountedWebView(
            providerID: providerID,
            preferredURL: sanitizedURL(from: urlString, for: providerID),
            fallbackToHome: fallbackToHome
        )
    }

    @discardableResult
    func openRestoredChat(providerID: ProviderID, restoredURLString: String?) -> Bool {
        openURL(providerID: providerID, urlString: restoredURLString, fallbackToHome: true)
    }

    @discardableResult
    private func loadIntoMountedWebView(
        providerID: ProviderID,
        preferredURL: URL?,
        fallbackToHome: Bool
    ) -> Bool {
        guard
            let webView = webViews[providerID],
            let definition = providerURL(for: providerID)
        else {
            return false
        }

        let targetURL = preferredURL ?? (fallbackToHome ? definition.homeURL : nil)
        guard let targetURL else {
            return false
        }

        webView.load(URLRequest(url: targetURL))
        return true
    }

    private func providerURL(for providerID: ProviderID) -> ProviderDefinition? {
        BuiltInProviders.byID[providerID]
    }

    private func sanitizedURL(from urlString: String?, for providerID: ProviderID) -> URL? {
        guard let rawValue = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty,
              let components = URLComponents(string: rawValue),
              let scheme = components.scheme?.lowercased(),
              Self.supportedURLSchemes.contains(scheme),
              let url = components.url,
              let host = url.host?.lowercased(),
              !host.isEmpty,
              isHostAllowed(host, for: providerID)
        else {
            return nil
        }
        return url
    }

    private func sanitizedURL(from url: URL, for providerID: ProviderID) -> URL? {
        guard let scheme = url.scheme?.lowercased(),
              Self.supportedURLSchemes.contains(scheme),
              let host = url.host?.lowercased(),
              !host.isEmpty,
              isHostAllowed(host, for: providerID)
        else {
            return nil
        }
        return url
    }

    private func isHostAllowed(_ host: String, for providerID: ProviderID) -> Bool {
        for allowed in allowedHosts(for: providerID) {
            if host == allowed || host.hasSuffix(".\(allowed)") {
                return true
            }
        }
        return false
    }

    private func allowedHosts(for providerID: ProviderID) -> [String] {
        switch providerID {
        case .chatGPT:
            return ["chatgpt.com"]
        case .claude:
            return ["claude.ai"]
        case .gemini:
            return ["gemini.google.com"]
        case .grok:
            return ["grok.com"]
        case .perplexity:
            return ["perplexity.ai"]
        case .deepSeek:
            return ["chat.deepseek.com", "deepseek.com"]
        }
    }

    func sendPrompt(
        _ prompt: String,
        to providerIDs: [ProviderID],
        using adapters: [ProviderID: any ProviderAutomationAdapter],
        completion: @escaping ([WebAutomationResult]) -> Void
    ) {
        guard !providerIDs.isEmpty else {
            completion([])
            return
        }

        var results: [WebAutomationResult] = []
        let group = DispatchGroup()

        for providerID in providerIDs {
            guard let webView = webViews[providerID] else {
                results.append(WebAutomationResult(providerID: providerID, success: false, message: "Web view unavailable"))
                continue
            }
            guard let adapter = adapters[providerID] else {
                results.append(WebAutomationResult(providerID: providerID, success: false, message: "Missing adapter"))
                continue
            }

            group.enter()
            webView.evaluateJavaScript(adapter.makeSendScript(prompt: prompt)) { value, error in
                defer { group.leave() }

                if let error {
                    results.append(
                        WebAutomationResult(
                            providerID: providerID,
                            success: false,
                            message: "Automation failed: \(error.localizedDescription)"
                        )
                    )
                    return
                }

                if let dictionary = value as? [String: Any],
                   let ok = dictionary["ok"] as? Bool
                {
                    let message = (dictionary["error"] as? String) ?? (dictionary["method"] as? String) ?? "ok"
                    results.append(WebAutomationResult(providerID: providerID, success: ok, message: message))
                } else {
                    results.append(WebAutomationResult(providerID: providerID, success: true, message: "Sent"))
                }
            }
        }

        group.notify(queue: .main) {
            completion(results)
        }
    }

    func setGlobalZoom(_ zoom: Double) {
        currentZoom = zoom
        for webView in webViews.values {
            webView.pageZoom = zoom
        }
    }
}

struct WebViewPane: NSViewRepresentable {
    let provider: ProviderDefinition
    let adapter: any ProviderAutomationAdapter
    @Binding var paneState: ProviderPaneState
    let hub: WebViewHub

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        if let cached = hub.cachedWebView(providerID: provider.id) {
            context.coordinator.webView = cached
            cached.navigationDelegate = context.coordinator
            cached.uiDelegate = context.coordinator
            return cached
        }

        let contentController = WKUserContentController()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.websiteDataStore = websiteDataStore(for: provider.id)
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground")
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }

        context.coordinator.webView = webView
        hub.register(providerID: provider.id, webView: webView)
        _ = hub.openRestoredChat(providerID: provider.id, restoredURLString: paneState.lastKnownURLString)
        return webView
    }

    func updateNSView(_: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator _: Coordinator) {
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    private func websiteDataStore(for providerID: ProviderID) -> WKWebsiteDataStore {
        if #available(macOS 14.0, *) {
            return WKWebsiteDataStore(forIdentifier: dataStoreID(for: providerID))
        }
        return .default()
    }

    private func dataStoreID(for providerID: ProviderID) -> UUID {
        switch providerID {
        case .chatGPT:
            return UUID(uuidString: "1977A93E-6449-4D56-8C52-120E1E929001")!
        case .claude:
            return UUID(uuidString: "1977A93E-6449-4D56-8C52-120E1E929002")!
        case .gemini:
            return UUID(uuidString: "1977A93E-6449-4D56-8C52-120E1E929003")!
        case .grok:
            return UUID(uuidString: "1977A93E-6449-4D56-8C52-120E1E929004")!
        case .perplexity:
            return UUID(uuidString: "1977A93E-6449-4D56-8C52-120E1E929005")!
        case .deepSeek:
            return UUID(uuidString: "1977A93E-6449-4D56-8C52-120E1E929006")!
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebViewPane
        weak var webView: WKWebView?

        init(_ parent: WebViewPane) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            parent.paneState.estimatedProgress = webView.estimatedProgress
            updateNavigationState(from: webView)
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            parent.paneState.estimatedProgress = 1
            parent.paneState.automationState = ProviderAutomationState(level: .ready, message: "Ready", updatedAt: .now)
            updateNavigationState(from: webView)
        }

        func webView(_ webView: WKWebView, didFail _: WKNavigation!, withError error: Error) {
            parent.paneState.automationState = ProviderAutomationState(
                level: .failed,
                message: "Navigation failed: \(error.localizedDescription)",
                updatedAt: .now
            )
            updateNavigationState(from: webView)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation _: WKNavigation!,
            withError error: Error
        ) {
            parent.paneState.automationState = ProviderAutomationState(
                level: .failed,
                message: "Load failed: \(error.localizedDescription)",
                updatedAt: .now
            )
            updateNavigationState(from: webView)
        }

        func webView(
            _: WKWebView,
            createWebViewWith _: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures _: WKWindowFeatures
        ) -> WKWebView? {
            guard navigationAction.targetFrame == nil, let url = navigationAction.request.url else {
                return nil
            }
            NSWorkspace.shared.open(url)
            return nil
        }

        private func updateNavigationState(from webView: WKWebView) {
            parent.paneState.lastKnownURLString = webView.url?.absoluteString
            parent.paneState.lastPageTitle = webView.title
            parent.paneState.canGoBack = webView.canGoBack
            parent.paneState.canGoForward = webView.canGoForward
            parent.paneState.estimatedProgress = webView.estimatedProgress
        }
    }
}
