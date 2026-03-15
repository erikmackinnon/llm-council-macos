//
//  CouncilScreenshotExport.swift
//  LLM Council
//
//  Created by Codex on 2026-03-08.
//

import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class CouncilScreenshotCaptureContext: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    weak var containerView: NSView?
    weak var window: NSWindow?
    var captureRect: CGRect = .zero

    func update(containerView: NSView?, window: NSWindow?, captureRect: CGRect) {
        objectWillChange.send()
        self.containerView = containerView
        self.window = window
        self.captureRect = captureRect
    }
}

typealias CouncilCaptureContext = CouncilScreenshotCaptureContext

struct CouncilScreenshotCaptureAnchor: NSViewRepresentable {
    let context: CouncilScreenshotCaptureContext

    func makeNSView(context _: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        DispatchQueue.main.async {
            let containerView = nsView.superview
            let rect = nsView.frame.integral
            self.context.update(containerView: containerView, window: nsView.window, captureRect: rect)
        }
    }
}

typealias CouncilCaptureAnchor = CouncilScreenshotCaptureAnchor

@MainActor
enum CouncilScreenshotExporter {
    static func exportCurrentWorkspace(
        from context: CouncilScreenshotCaptureContext,
        visibleProviderNames: [String],
        includedProviderCount: Int
    ) {
        exportWorkspace(
            context: context,
            providerNames: visibleProviderNames,
            visibleCount: visibleProviderNames.count,
            includedCount: includedProviderCount
        )
    }

    static func exportWorkspace(
        context: CouncilScreenshotCaptureContext,
        providerNames: [String],
        visibleCount: Int,
        includedCount: Int
    ) {
        guard
            let containerView = context.containerView,
            context.captureRect.width > 1,
            context.captureRect.height > 1,
            let workspaceImage = captureImage(of: containerView, rect: context.captureRect),
            let exportImage = renderCard(
                workspaceImage: workspaceImage,
                providerNames: providerNames,
                visibleCount: visibleCount,
                includedCount: includedCount,
                scale: context.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
            ),
            let pngData = exportImage.pngData
        else {
            NSSound.beep()
            return
        }

        presentSavePanel(
            pngData: pngData,
            suggestedFilename: suggestedFilename(),
            window: context.window
        )
    }

    private static func captureImage(of view: NSView, rect: CGRect) -> NSImage? {
        let captureRect = rect.integral
        guard
            captureRect.width > 1,
            captureRect.height > 1,
            let bitmap = view.bitmapImageRepForCachingDisplay(in: captureRect)
        else {
            return nil
        }

        view.layoutSubtreeIfNeeded()
        view.cacheDisplay(in: captureRect, to: bitmap)

        let image = NSImage(size: captureRect.size)
        image.addRepresentation(bitmap)
        return image
    }

    private static func renderCard(
        workspaceImage: NSImage,
        providerNames: [String],
        visibleCount: Int,
        includedCount: Int,
        scale: CGFloat
    ) -> NSImage? {
        let cardView = CouncilScreenshotCard(
            workspaceImage: workspaceImage,
            providerNames: providerNames,
            visibleCount: visibleCount,
            includedCount: includedCount,
            exportedAt: .now
        )

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = scale
        renderer.isOpaque = false
        renderer.proposedSize = ProposedViewSize(
            width: workspaceImage.size.width + 72,
            height: workspaceImage.size.height + 168
        )
        return renderer.nsImage
    }

    private static func presentSavePanel(
        pngData: Data,
        suggestedFilename: String,
        window: NSWindow?
    ) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedFilename
        panel.title = "Save Workspace Screenshot"
        panel.message = "Export a branded PNG of the current LLM Council workspace."

        let saveAction = {
            guard let url = panel.url else {
                return
            }
            do {
                try pngData.write(to: url, options: .atomic)
            } catch {
                NSSound.beep()
            }
        }

        if let window {
            panel.beginSheetModal(for: window) { response in
                guard response == .OK else {
                    return
                }
                saveAction()
            }
        } else if panel.runModal() == .OK {
            saveAction()
        }
    }

    private static func suggestedFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "LLM-Council-\(formatter.string(from: .now)).png"
    }
}

private struct CouncilScreenshotCard: View {
    let workspaceImage: NSImage
    let providerNames: [String]
    let visibleCount: Int
    let includedCount: Int
    let exportedAt: Date

    private var subtitle: String {
        "\(visibleCount) visible • \(includedCount) included"
    }

    private var timestamp: String {
        exportedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.1, blue: 0.15),
                    Color(red: 0.05, green: 0.06, blue: 0.09),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: CouncilSpacing.xl) {
                header

                Image(nsImage: workspaceImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: CouncilMetrics.cardCornerRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: CouncilMetrics.cardCornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.22), radius: 24, y: 10)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .frame(
            width: workspaceImage.size.width + 72,
            height: workspaceImage.size.height + 168
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: CouncilSpacing.xl) {
            VStack(alignment: .leading, spacing: CouncilSpacing.xs) {
                Text("LLM Council")
                    .font(CouncilTypography.overlayTitle)
                    .foregroundStyle(.white)

                Text("Compare live model sessions in one clean frame.")
                    .font(CouncilTypography.detail)
                    .foregroundStyle(Color.white.opacity(0.72))

                HStack(spacing: CouncilSpacing.sm) {
                    labelCapsule(text: subtitle, fill: Color.white.opacity(0.12))

                    ForEach(providerNames, id: \.self) { providerName in
                        labelCapsule(text: providerName, fill: Color.accentColor.opacity(0.22))
                    }
                }
            }

            Spacer(minLength: CouncilSpacing.xl)

            Text(timestamp)
                .font(CouncilTypography.meta)
                .foregroundStyle(Color.white.opacity(0.64))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
        }
    }

    private func labelCapsule(text: String, fill: Color) -> some View {
        Text(text)
            .font(CouncilTypography.compactPill)
            .foregroundStyle(.white.opacity(0.94))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(fill)
            )
    }
}

private extension NSImage {
    var pngData: Data? {
        guard
            let tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffRepresentation)
        else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
