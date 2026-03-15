//
//  CouncilShortcutGuide.swift
//  LLM Council
//
//

import Foundation

struct CouncilShortcutGuideSection: Identifiable, Hashable {
    let title: String
    let shortcuts: [CouncilShortcutGuideItem]
    var id: String {
        title
    }
}

struct CouncilShortcutGuideItem: Identifiable, Hashable {
    let id: String
    let action: String
    let keyCombination: [String]
    let description: String
}

enum CouncilShortcutGuide {
    static let sections: [CouncilShortcutGuideSection] = [
        CouncilShortcutGuideSection(
            title: "Prompting",
            shortcuts: [
                CouncilShortcutGuideItem(
                    id: "send-prompt",
                    action: "Send Prompt to Selected Providers",
                    keyCombination: ["Cmd", "Return"],
                    description: "Dispatch the current composer prompt to all active targets."
                ),
                CouncilShortcutGuideItem(
                    id: "toggle-focus",
                    action: "Compare Visible / Focus Selected Provider",
                    keyCombination: ["Cmd", "Shift", "F"],
                    description: "Switch between compare mode and a focused single-provider view."
                ),
                CouncilShortcutGuideItem(
                    id: "new-chat",
                    action: "Start New Chat in Visible Providers",
                    keyCombination: ["Cmd", "Shift", "N"],
                    description: "Reset visible providers to a clean composer window state."
                ),
                CouncilShortcutGuideItem(
                    id: "toggle-inspector",
                    action: "Toggle Inspector",
                    keyCombination: ["Cmd", "Shift", "I"],
                    description: "Show or hide the workspace inspector panel."
                ),
            ]
        ),
        CouncilShortcutGuideSection(
            title: "Layout and View",
            shortcuts: [
                CouncilShortcutGuideItem(
                    id: "equalize-panes",
                    action: "Equalize Pane Widths",
                    keyCombination: ["Cmd", "Shift", "E"],
                    description: "Reset pane spacing and share width evenly across the view."
                ),
                CouncilShortcutGuideItem(
                    id: "zoom-in",
                    action: "Zoom In Panes",
                    keyCombination: ["Cmd", "="],
                    description: "Increase the embedded provider page zoom level."
                ),
                CouncilShortcutGuideItem(
                    id: "zoom-out",
                    action: "Zoom Out Panes",
                    keyCombination: ["Cmd", "-"],
                    description: "Decrease the embedded provider page zoom level."
                ),
                CouncilShortcutGuideItem(
                    id: "zoom-reset",
                    action: "Actual Size",
                    keyCombination: ["Cmd", "0"],
                    description: "Reset panes to default zoom (1.0)."
                ),
            ]
        ),
        CouncilShortcutGuideSection(
            title: "Navigation",
            shortcuts: [
                CouncilShortcutGuideItem(
                    id: "pane-page-previous",
                    action: "Previous Pane Set",
                    keyCombination: ["Cmd", "["],
                    description: "Move the visible pane window backward when more than 3 panes are visible."
                ),
                CouncilShortcutGuideItem(
                    id: "pane-page-next",
                    action: "Next Pane Set",
                    keyCombination: ["Cmd", "]"],
                    description: "Move the visible pane window forward when more than 3 panes are visible."
                ),
                CouncilShortcutGuideItem(
                    id: "show-shortcuts",
                    action: "Show Shortcut Legend",
                    keyCombination: ["Cmd", "/"],
                    description: "Open this overlay at any time."
                ),
            ]
        ),
    ]
}
