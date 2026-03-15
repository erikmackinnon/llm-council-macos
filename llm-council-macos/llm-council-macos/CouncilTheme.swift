//
//  CouncilTheme.swift
//  LLM Council
//
//  Created by Codex on 2026-03-08.
//

import SwiftUI

enum CouncilTheme {
    enum Selection: String, CaseIterable, Codable, Identifiable {
        case system
        case latte
        case mocha

        var id: String {
            rawValue
        }

        var displayName: String {
            switch self {
            case .system:
                return "System"
            case .latte:
                return "Latte"
            case .mocha:
                return "Mocha"
            }
        }

        var persistedValue: String {
            rawValue
        }

        var colorSchemeOverride: ColorScheme? {
            switch self {
            case .system:
                return nil
            case .latte:
                return .light
            case .mocha:
                return .dark
            }
        }

        static var pickerOptions: [Selection] {
            [.system, .latte, .mocha]
        }

        init(persistedValue: String?) {
            let normalized = persistedValue?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            switch normalized {
            case nil, "", "system", "auto", "default":
                self = .system
            case "latte", "catppuccin-latte", "catppuccin_latte", "light":
                self = .latte
            case "mocha", "catppuccin-mocha", "catppuccin_mocha", "dark":
                self = .mocha
            default:
                self = .system
            }
        }

        func palette(for colorScheme: ColorScheme) -> Palette {
            switch self {
            case .system:
                return colorScheme == .dark ? .mocha : .latte
            case .latte:
                return .latte
            case .mocha:
                return .mocha
            }
        }
    }

    struct Palette {
        let sidebarGradientTop: Color
        let sidebarGradientBottom: Color
        let workspaceGradientTop: Color
        let workspaceGradientBottom: Color
        let cardFill: Color
        let cardBorder: Color
        let sectionIcon: Color
        let primaryText: Color
        let secondaryText: Color
        let tint: Color
    }
}

extension CouncilTheme.Palette {
    static let latte = CouncilTheme.Palette(
        sidebarGradientTop: Color(hex: 0xEFF1F5),
        sidebarGradientBottom: Color(hex: 0xDCE0E8),
        workspaceGradientTop: Color(hex: 0xF5F7FB),
        workspaceGradientBottom: Color(hex: 0xE6E9EF),
        cardFill: Color(hex: 0xE6E9EF).opacity(0.9),
        cardBorder: Color(hex: 0x9CA0B0).opacity(0.7),
        sectionIcon: Color(hex: 0x179299),
        primaryText: Color(hex: 0x4C4F69),
        secondaryText: Color(hex: 0x6C6F85),
        tint: Color(hex: 0x1E66F5)
    )

    static let mocha = CouncilTheme.Palette(
        sidebarGradientTop: Color(hex: 0x1E1E2E),
        sidebarGradientBottom: Color(hex: 0x11111B),
        workspaceGradientTop: Color(hex: 0x181825),
        workspaceGradientBottom: Color(hex: 0x11111B),
        cardFill: Color(hex: 0x313244).opacity(0.9),
        cardBorder: Color(hex: 0x6C7086).opacity(0.7),
        sectionIcon: Color(hex: 0x94E2D5),
        primaryText: Color(hex: 0xCDD6F4),
        secondaryText: Color(hex: 0xA6ADC8),
        tint: Color(hex: 0x89B4FA)
    )
}

private extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
