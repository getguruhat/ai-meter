import SwiftUI
import AppKit

@main
struct AIMeterApp: App {
    @StateObject private var usage = UsageModel()

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Provider", selection: $usage.provider) {
                    ForEach(UsageProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                Text(usage.displayText).font(.headline)
                if let reset = usage.resetText { Text("Resets \(reset)").font(.caption).foregroundStyle(.secondary) }
                Divider()
                HStack(spacing: 14) {
                    Button { usage.refresh() } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 42, height: 30)
                    }
                    .help("Refresh")
                    .accessibilityLabel("Refresh")

                    Button { AboutWindowController.shared.show() } label: {
                        Image(systemName: "info.circle")
                            .frame(width: 42, height: 30)
                    }
                    .help("About AI Meter")
                    .accessibilityLabel("About AI Meter")

                    Button { NSApplication.shared.terminate(nil) } label: {
                        Image(systemName: "power")
                            .frame(width: 42, height: 30)
                    }
                    .help("Quit")
                    .accessibilityLabel("Quit")
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }.padding(12).frame(width: 220)
        } label: {
            Text(usage.menuTitle)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AboutWindowController {
    static let shared = AboutWindowController()
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let content = AboutView()
        let hosting = NSHostingView(rootView: content)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 390, height: 430),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = "About AI Meter"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = hosting
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct AboutView: View {
    private let donationURL = URL(string: "https://www.paypal.com/donate/?hosted_button_id=FHGYWD46722JS")!

    var body: some View {
        VStack(spacing: 14) {
            if let iconURL = Bundle.main.url(forResource: "icon", withExtension: "png"),
               let icon = NSImage(contentsOf: iconURL) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
            }
            Text("AI Meter").font(.title2).bold()
            Text("Version 1.3")
                .foregroundStyle(.secondary)
            Text("A GuruHat open-source tool")
                .font(.headline)
            Divider().padding(.vertical, 6)
            Link(destination: donationURL) {
                Label("Support AI Meter", systemImage: "heart.fill")
                    .frame(maxWidth: .infinity)
            }
            Text("Thank you for supporting this project!")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 390, height: 430)
    }
}

enum UsageProvider: String, CaseIterable, Identifiable {
    case codex = "Codex"
    case claude = "Claude"
    var id: String { rawValue }
}

final class UsageModel: ObservableObject {
    private static let providerKey = "provider"

    @Published var provider: UsageProvider = UsageProvider(rawValue: UserDefaults.standard.string(forKey: providerKey) ?? "") ?? .codex {
        didSet {
            UserDefaults.standard.set(provider.rawValue, forKey: UsageModel.providerKey)
            loadCached()
            refresh()
        }
    }
    @Published var remaining: Int?
    @Published var reset: Date?
    private var timer: Timer?

    init() {
        loadCached()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in self?.refresh() }
    }

    // The last good reading per provider is saved, so a failed or rate-limited request
    // still shows the most recent value instead of "unavailable".
    private func cacheKey(_ suffix: String) -> String { "\(provider.rawValue).\(suffix)" }

    private func loadCached() {
        let defaults = UserDefaults.standard
        remaining = defaults.object(forKey: cacheKey("remaining")) as? Int
        let resetTime = defaults.double(forKey: cacheKey("reset"))
        reset = resetTime > 0 ? Date(timeIntervalSince1970: resetTime) : nil
    }

    private func saveCached() {
        let defaults = UserDefaults.standard
        defaults.set(remaining, forKey: cacheKey("remaining"))
        defaults.set(reset?.timeIntervalSince1970 ?? 0, forKey: cacheKey("reset"))
    }
    deinit { timer?.invalidate() }

    var menuTitle: String { remaining.map { "AI \($0)%" } ?? "AI —" }
    var displayText: String {
        remaining.map { "AI usage remaining: \($0)%" } ?? "AI usage unavailable"
    }
    var resetText: String? { guard let reset else { return nil }; return reset.formatted(date: .abbreviated, time: .shortened) }

    /// Fetches usage for the selected provider on a background queue and publishes the result on the main queue.
    func refresh() {
        let current = provider
        DispatchQueue.global(qos: .utility).async {
            let result: (Int?, Date?)
            switch current {
            case .codex: result = UsageModel.fetchCodex()
            case .claude: result = UsageModel.fetchClaude()
            }
            DispatchQueue.main.async {
                guard self.provider == current else { return }
                // A failed request (e.g. rate limited) keeps the last good reading, unless its window has already reset.
                guard let value = result.0 else {
                    if let reset = self.reset, reset < Date() { self.remaining = nil; self.reset = nil; self.saveCached() }
                    return
                }
                self.remaining = value
                self.reset = result.1
                self.saveCached()
            }
        }
    }

    // MARK: - Codex

    private static func fetchCodex() -> (Int?, Date?) {
        let authURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")
        guard let authData = try? Data(contentsOf: authURL),
              let auth = try? JSONSerialization.jsonObject(with: authData) as? [String: Any],
              let tokens = auth["tokens"] as? [String: Any],
              let token = tokens["access_token"] as? String else { return (nil, nil) }
        let accountID = tokens["account_id"] as? String ?? ""
        guard let json = curlJSON(url: "https://chatgpt.com/backend-api/wham/usage",
                                  headers: ["Accept: application/json",
                                            "Authorization: Bearer \(token)",
                                            "ChatGPT-Account-Id: \(accountID)"]),
              let limit = json["rate_limit"] as? [String: Any],
              let primary = limit["primary_window"] as? [String: Any],
              let used = number(primary["used_percent"]) else { return (nil, nil) }
        return (max(0, 100 - Int(used)), date(primary["reset_at"]))
    }

    // MARK: - Claude

    /// Claude Code's usage endpoint and the OAuth token it accepts. The response has
    /// `five_hour` and `seven_day` windows, each with `utilization` (percent used) and `resets_at`.
    private static func fetchClaude() -> (Int?, Date?) {
        guard let token = claudeAccessToken(),
              let json = curlJSON(url: "https://api.anthropic.com/api/oauth/usage",
                                  headers: ["Accept: application/json",
                                            "Authorization: Bearer \(token)",
                                            "anthropic-version: 2023-06-01",
                                            "anthropic-beta: oauth-2025-04-20"]),
              let window = json["five_hour"] as? [String: Any],
              let used = number(window["utilization"]) else { return (nil, nil) }
        return (max(0, 100 - Int(used.rounded())), date(window["resets_at"]))
    }

    /// Claude Code stores its login in the macOS Keychain ("Claude Code-credentials").
    /// Falls back to ~/.claude/.credentials.json when the Keychain entry is missing.
    private static func claudeAccessToken() -> String? {
        if let data = run("/usr/bin/security", ["find-generic-password", "-s", "Claude Code-credentials", "-w"]),
           let token = oauthToken(from: data) {
            return token
        }
        let fileURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/.credentials.json")
        if let data = try? Data(contentsOf: fileURL), let token = oauthToken(from: data) {
            return token
        }
        return nil
    }

    private static func oauthToken(from data: Data) -> String? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty else { return nil }
        return token
    }

    // MARK: - Helpers

    private static func curlJSON(url: String, headers: [String]) -> [String: Any]? {
        var args = ["-sS", "--max-time", "15"]
        for header in headers { args += ["-H", header] }
        args.append(url)
        guard let data = run("/usr/bin/curl", args) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// Runs a command and returns its stdout, or nil if it fails or exits non-zero.
    private static func run(_ path: String, _ arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    /// Accepts epoch seconds, epoch milliseconds, or an ISO 8601 string.
    private static func date(_ value: Any?) -> Date? {
        if let seconds = number(value) {
            return Date(timeIntervalSince1970: seconds > 1e11 ? seconds / 1000 : seconds)
        }
        if let string = value as? String {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: string) { return date }
            return ISO8601DateFormatter().date(from: string)
        }
        return nil
    }
}
