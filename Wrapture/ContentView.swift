import SwiftUI

struct ContentView: View {
    @AppStorage(Settings.wrapLengthKey, store: Settings.defaults)
    private var storedWrapLength = Settings.defaultWrapLength
    private let presets: [Int]

    init() {
        presets = [Settings.minimumWrapLength, 80, 96, Settings.maximumWrapLength]
            .filter {
                stride(
                    from: Settings.minimumWrapLength,
                    through: Settings.maximumWrapLength,
                    by: Settings.stepSize
                ).contains($0)
            }
    }

    private var wrapLength: Int {
        get { Settings.clampedWrapLength(storedWrapLength) }
        nonmutating set { storedWrapLength = Settings.clampedWrapLength(newValue) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            Divider()

            VStack(alignment: .leading, spacing: 24) {
                controlPanel
                previewPanel
            }
            .padding()
        }
        .frame(minWidth: 576, idealWidth: 576, minHeight: 496, idealHeight: 496)
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
                Text("Choose the column for re-wrapping your Swift comments.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("column number")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(wrapLength)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .padding(24)
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Wrap length", systemImage: "ruler")
                    .font(.headline)
            }

            Slider(
                value: Binding(
                    get: { Double(wrapLength) },
                    set: { wrapLength = Int($0.rounded()) }
                ),
                in: Double(
                    Settings.minimumWrapLength
                )...Double(Settings.maximumWrapLength),
                step: Double(Settings.stepSize)
            )

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { preset in
                    presetButton(for: preset)
                }

                Spacer()

                Button {
                    wrapLength = Settings.defaultWrapLength
                } label: {
                    Label("Reset to Default", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.glass)
            }
        }
    }

    @ViewBuilder
    private func presetButton(for preset: Int) -> some View {
        let button = Button("\(preset)") {
            wrapLength = preset
        }

        if preset == Settings.defaultWrapLength {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.glass)
        }
    }

    private var previewPanel: some View {
        VStack(alignment: .leading) {
            Label("Preview", systemImage: "text.magnifyingglass")
                .font(.headline)

            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    Text(previewText)
                        .font(.caption)
                        .monospaced()
                        .textSelection(.disabled)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: true, vertical: true)
                        .padding()
                        .frame(
                            minWidth: proxy.size.width,
                            minHeight: proxy.size.height,
                            alignment: .topLeading
                        )
                }
            }
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator, lineWidth: 1)
            }
        }
    }

    private var previewText: String {
        let sample = """
            // To understand political power right, and derive it from its original, we must consider, what state all men are naturally in, and that is, a state of perfect freedom to order their actions, and dispose of their possessions and persons, as they think fit, within the bounds of the law of nature, without asking leave, or depending upon the will of any other man. A state also of equality, wherein all the power and jurisdiction is reciprocal, no one having more than another; there being nothing more evident, than that creatures of the same species and rank, promiscuously born to all the same advantages of nature, and the use of the same faculties, should also be equal one amongst another without subordination or subjection, unless the lord and master of them all should, by any manifest declaration of his will, set one above another, and confer on him, by an evident and clear appointment, an undoubted right to dominion and sovereignty.
            """
        return wrappedPreviewLine(sample)
    }

    private func wrappedPreviewLine(_ line: String) -> String {
        let marker = "// "
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
