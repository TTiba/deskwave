import SwiftUI

@main
struct DeskWeaveApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("DeskWeave") {
            ContentView(model: model)
                .frame(minWidth: 520, minHeight: 430)
        }
        .windowResizability(.contentMinSize)
    }
}

private struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: "macbook.and.ipad")
                    .font(.system(size: 38))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 3) {
                    Text("DeskWeave")
                        .font(.title2.weight(.semibold))
                    Text("H.264 Main 4.2 • 1792 × 1120 • up to 60 fps")
                        .foregroundStyle(.secondary)
                    Text("Version 0.3.1 • protocol DW31")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Label(model.status, systemImage: statusIcon)
                        .font(.headline)
                    Text(model.statistics)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Address to enter on the tablet")
                    .font(.headline)
                if model.addresses.isEmpty {
                    Text("Network addresses appear after the display starts.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.addresses, id: \.self) { address in
                        Text(address)
                            .font(.system(.title3, design: .monospaced).weight(.medium))
                            .textSelection(.enabled)
                    }
                }
            }

            Text("On first launch, allow Screen Recording for DeskWeave. Only the virtual display is captured and transmitted.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Spacer()
                if model.isRunning {
                    Button("Stop") {
                        Task { await model.stop() }
                    }
                    .keyboardShortcut(.cancelAction)
                } else {
                    Button("Create second display") {
                        model.start()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(26)
    }

    private var statusIcon: String {
        model.isRunning ? "display.2" : "circle"
    }
}
