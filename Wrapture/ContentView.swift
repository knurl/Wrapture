//
//  ContentView.swift
//  Wrapture
//
//  Created by Rob Anderson on 11/09/2026.
//

import SwiftUI

struct ContentView: View {
    @AppStorage(WraptureSettings.wrapLengthKey, store: WraptureSettings.defaults)
    private var storedWrapLength = WraptureSettings.defaultWrapLength

    private let presets = [80, 88, 96, 100, 120]

    private var wrapLength: Int {
        get { WraptureSettings.clampedWrapLength(storedWrapLength) }
        nonmutating set { storedWrapLength = WraptureSettings.clampedWrapLength(newValue) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                controlPanel
                previewPanel
            }
            .padding(24)
        }
        .frame(minWidth: 560, idealWidth: 680, minHeight: 520)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("Wrapture")
                    .font(.title2.weight(.semibold))
                Text("Comment wrapping preferences for the Xcode editor extension.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(wrapLength)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("columns")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Wrap length", systemImage: "ruler")
                    .font(.headline)

                Spacer()

                Stepper(
                    "\(wrapLength)",
                    value: Binding(
                        get: { wrapLength },
                        set: { wrapLength = $0 }
                    ),
                    in: WraptureSettings.minimumWrapLength...WraptureSettings.maximumWrapLength
                )
                .monospacedDigit()
                .labelsHidden()
            }

            Slider(
                value: Binding(
                    get: { Double(wrapLength) },
                    set: { wrapLength = Int($0.rounded()) }
                ),
                in: Double(WraptureSettings.minimumWrapLength)...Double(WraptureSettings.maximumWrapLength),
                step: 1
            )

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        wrapLength = preset
                    } label: {
                        Text("\(preset)")
                            .monospacedDigit()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                Button {
                    wrapLength = WraptureSettings.defaultWrapLength
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Preview", systemImage: "text.magnifyingglass")
                .font(.headline)

            ScrollView([.horizontal, .vertical]) {
                Text(previewText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(14)
            }
            .frame(minHeight: 220)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator, lineWidth: 1)
            }
        }
    }

    private var previewText: String {
        let sample = "/// Wrapture keeps comments readable without asking you to fuss with line breaks by hand, while preserving hanging indentation for third and later lines."
        return wrappedPreviewLine(sample)
    }

    private func wrappedPreviewLine(_ line: String) -> String {
        let marker = "/// "
        let content = String(line.dropFirst(marker.count))
        let width = max(wrapLength - marker.count, 20)
        let words = content.split(separator: " ").map(String.init)
        var lines: [String] = []
        var currentLine = ""

        for word in words {
            if currentLine.isEmpty {
                currentLine = word
            } else if currentLine.count + 1 + word.count <= width {
                currentLine += " " + word
            } else {
                lines.append(currentLine)
                currentLine = word
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines.map { marker + $0 }.joined(separator: "\n")
    }
}

#Preview {
    ContentView()
}
