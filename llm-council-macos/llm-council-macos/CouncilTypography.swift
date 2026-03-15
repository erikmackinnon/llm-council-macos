//
//  CouncilTypography.swift
//  LLM Council
//
//

import SwiftUI

enum CouncilTypography {
    private static let sansFamily = "Avenir Next"
    private static let displayFamily = "Avenir Next Condensed"

    static let appTitle = Font.custom(displayFamily, size: 18).weight(.semibold)
    static let sectionTitle = Font.custom(sansFamily, size: 14).weight(.semibold)
    static let sectionSubtitle = Font.custom(sansFamily, size: 12).weight(.medium)
    static let paneTitle = Font.custom(sansFamily, size: 13).weight(.semibold)
    static let body = Font.custom(sansFamily, size: 14)
    static let bodyStrong = Font.custom(sansFamily, size: 14).weight(.semibold)
    static let detail = Font.custom(sansFamily, size: 13).weight(.medium)
    static let detailStrong = Font.custom(sansFamily, size: 13).weight(.semibold)
    static let caption = Font.custom(sansFamily, size: 12).weight(.regular)
    static let captionStrong = Font.custom(sansFamily, size: 12).weight(.semibold)
    static let meta = Font.custom(sansFamily, size: 11).weight(.medium)
    static let compactPill = Font.custom(sansFamily, size: 11).weight(.semibold)
    static let promptLabel = sectionTitle
    static let promptInput = body
    static let promptStatus = meta
    static let emptyStateTitle = Font.custom(displayFamily, size: 22).weight(.semibold)
    static let overlayTitle = Font.custom(displayFamily, size: 24).weight(.bold)
    static let overlayDismiss = Font.system(size: 16, weight: .semibold)
    static let keycap = Font.system(size: 12, weight: .semibold, design: .monospaced)
    static let largeIcon = Font.system(size: 28, weight: .medium)
    static let mediumIcon = Font.system(size: 16, weight: .medium)
    static let compactIcon = Font.system(size: 12, weight: .medium)
    static let microIcon = Font.system(size: 10, weight: .semibold)
}

enum CouncilSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 6
    static let sm: CGFloat = 8
    static let md: CGFloat = 10
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let xxl: CGFloat = 20
    static let xxxl: CGFloat = 24
}

enum CouncilMetrics {
    static let glyphSize: CGFloat = 20
    static let paneGlyphSize: CGFloat = 24
    static let statusDotSize: CGFloat = 8
    static let iconButtonSize: CGFloat = 22
    static let textFieldMinHeight: CGFloat = 82
    static let chipCornerRadius: CGFloat = 999
    static let fieldCornerRadius: CGFloat = 10
    static let cardCornerRadius: CGFloat = 14
    static let heroCardCornerRadius: CGFloat = 18
}

enum CouncilControls {
    static let compact: ControlSize = .small
    static let standard: ControlSize = .regular
}
