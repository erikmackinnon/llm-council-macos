//
//  LLM_CouncilUITests.swift
//  LLM CouncilUITests
//
//

import XCTest

final class LLM_CouncilUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testShellLaunchesWithSidebarToolbarComposerAndInspector() {
        XCTAssertTrue(button("toolbar-send-button").waitForExistence(timeout: 2))
        XCTAssertTrue(button("toolbar-inspector-toggle").waitForExistence(timeout: 2))
        XCTAssertTrue(anyElement("toolbar-compact-stat").waitForExistence(timeout: 2))
        XCTAssertTrue(composerElement().waitForExistence(timeout: 2))

        XCTAssertTrue(app.staticTexts["Workspace"].exists)
        XCTAssertTrue(app.staticTexts["Providers"].exists)
        XCTAssertTrue(app.staticTexts["Get Started"].exists)
        XCTAssertTrue(app.textFields["Session name"].exists)
    }

    @MainActor
    func testComposerSendEnablesAfterPromptEntry() {
        let composer = composerElement()
        XCTAssertTrue(composer.waitForExistence(timeout: 2))

        let sendButton = button("send-all-button")
        XCTAssertTrue(sendButton.waitForExistence(timeout: 2))
        XCTAssertFalse(sendButton.isEnabled)

        composer.click()
        app.typeText("Check the compare shell")

        XCTAssertTrue(sendButton.isEnabled)
        XCTAssertTrue(button("toolbar-send-button").isEnabled)
    }

    @MainActor
    func testInspectorToggleAndFocusFlowUseSidebarSelection() {
        let inspectorToggle = button("toolbar-inspector-toggle")
        XCTAssertTrue(inspectorToggle.waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["Session name"].waitForExistence(timeout: 2))

        inspectorToggle.click()
        XCTAssertFalse(app.textFields["Session name"].waitForExistence(timeout: 1))

        inspectorToggle.click()
        XCTAssertTrue(app.textFields["Session name"].waitForExistence(timeout: 2))

        let claudeRow = app.staticTexts["Claude"].firstMatch
        XCTAssertTrue(claudeRow.waitForExistence(timeout: 2))
        claudeRow.click()

        let focusToggle = button("toolbar-focus-toggle")
        XCTAssertTrue(focusToggle.waitForExistence(timeout: 2))
        focusToggle.click()

        let toolbarStatus = anyElement("toolbar-compact-stat")
        XCTAssertTrue(toolbarStatus.waitForExistence(timeout: 2))
        XCTAssertTrue(toolbarStatus.label.contains("Claude"))
    }

    @MainActor
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testShortcutLegendKeyboardShortcutAndEscapeDismissal() {
        let composer = composerElement()
        XCTAssertTrue(composer.waitForExistence(timeout: 2))

        let legendTitle = app.staticTexts["Keyboard Shortcuts"].firstMatch
        XCTAssertFalse(legendTitle.exists)

        triggerShortcutLegend()
        XCTAssertTrue(legendTitle.waitForExistence(timeout: 2))

        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        XCTAssertTrue(waitForDisappearance(of: legendTitle, timeout: 2))

        composer.click()
        app.typeText("Shortcut legend focus regression check")

        triggerShortcutLegend()
        XCTAssertTrue(legendTitle.waitForExistence(timeout: 2))

        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        XCTAssertTrue(waitForDisappearance(of: legendTitle, timeout: 2))
    }

    private func anyElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func button(_ identifier: String) -> XCUIElement {
        app.buttons.matching(identifier: identifier).firstMatch
    }

    private func composerElement() -> XCUIElement {
        return anyElement("composer-text-editor")
    }

    private func triggerShortcutLegend() {
        app.typeKey("/", modifierFlags: [.command])
    }

    private func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
