import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var screenshots: [URL] = []
    @State private var errorMessage: String?

    private let deviceInformation = DeviceInformation.current

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 28))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Send Feedback")
                        .font(.title2.bold())
                    Text("Report a bug, request a feature, or share an idea.")
                        .foregroundStyle(.secondary)
                }
            }

            TextEditor(text: $message)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    if message.isEmpty {
                        Text("What happened, or what would you like to see?")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 150)

            GroupBox("Device Information") {
                Text(deviceInformation.summary)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Screenshots (Optional)")
                        .font(.headline)
                    Spacer()
                    Button("Add Screenshots…", systemImage: "photo.badge.plus") {
                        addScreenshots()
                    }
                }

                if screenshots.isEmpty {
                    Text("No screenshots selected")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(screenshots, id: \.self) { url in
                                screenshotTile(url)
                            }
                        }
                    }
                }
            }

            Text("The device information above is included in the email. No serial number, Mac name, or Photos data is collected.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Open in Mail", systemImage: "paperplane.fill") {
                    openInMail()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 560)
        .frame(minHeight: 620)
        .alert("Could Not Create Email", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func screenshotTile(_ url: URL) -> some View {
        ZStack(alignment: .topTrailing) {
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110, height: 72)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }

            Button {
                screenshots.removeAll { $0 == url }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.65))
            }
            .buttonStyle(.plain)
            .padding(4)
            .accessibilityLabel("Remove \(url.lastPathComponent)")
        }
    }

    private func addScreenshots() {
        let panel = NSOpenPanel()
        panel.title = "Add Screenshots"
        panel.prompt = "Add"
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        screenshots.append(contentsOf: panel.urls.filter { !screenshots.contains($0) })
    }

    private func openInMail() {
        guard let mail = NSSharingService(named: .composeEmail) else {
            errorMessage = "No email service is available on this Mac."
            return
        }

        mail.recipients = ["pietro.michelini@gmail.com"]
        mail.subject = deviceInformation.subject
        let items: [Any] = [deviceInformation.emailBody(message: message)] + screenshots
        guard mail.canPerform(withItems: items) else {
            errorMessage = "Mail could not create the feedback message."
            return
        }

        mail.perform(withItems: items)
        dismiss()
    }
}

struct DeviceInformation {
    let appVersion: String
    let appBuild: String
    let macModel: String
    let chip: String
    let memory: String
    let macOS: String
    let displays: String

    static var current: DeviceInformation {
        let bundle = Bundle.main
        let screenDescriptions = NSScreen.screens.map {
            "\(Int($0.frame.width * $0.backingScaleFactor))×\(Int($0.frame.height * $0.backingScaleFactor))"
        }
        return DeviceInformation(
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown",
            appBuild: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown",
            macModel: systemValue("hw.model") ?? "Unknown",
            chip: systemValue("machdep.cpu.brand_string") ?? architecture,
            memory: ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory),
            macOS: ProcessInfo.processInfo.operatingSystemVersionString,
            displays: screenDescriptions.isEmpty ? "None detected" : screenDescriptions.joined(separator: ", ")
        )
    }

    var summary: String {
        """
        DejaVuScreensaver: v\(appVersion) (\(appBuild))
        Mac: \(macModel)
        Chip: \(chip)
        Memory: \(memory)
        macOS: \(macOS)
        Displays: \(displays)
        """
    }

    var subject: String { "DejaVuScreensaver feedback — v\(appVersion) (\(appBuild))" }

    func emailBody(message: String) -> String {
        """
        \(message.trimmingCharacters(in: .whitespacesAndNewlines))

        — Device Information —
        \(summary)
        """
    }

    private static var architecture: String {
        #if arch(arm64)
        "Apple silicon"
        #elseif arch(x86_64)
        "Intel"
        #else
        "Unknown"
        #endif
    }

    private static func systemValue(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 1 else { return nil }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return String(cString: value)
    }
}
