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
                if let problem = usage.problem {
                    Text(problem).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
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
            Text("Version 1.5.1")
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

/// What one usage check produced. Anything other than a reading leaves the last good
/// reading on screen, with the reason it couldn't be updated shown in the menu.
enum FetchResult {
    case reading(Int, Date?)
    case rateLimited(until: Date)
    case signIn(String)
    case unavailable
}

final class UsageModel: ObservableObject {
    private static let providerKey = "provider"

    @Published var provider: UsageProvider = UsageProvider(rawValue: UserDefaults.standard.string(forKey: providerKey) ?? "") ?? .codex {
        didSet {
            UserDefaults.standard.set(provider.rawValue, forKey: UsageModel.providerKey)
            problem = nil
            loadCached()
            refresh()
        }
    }
    @Published var remaining: Int?
    @Published var reset: Date?
    @Published var problem: String?
    /// When a provider asked us to back off, no request is sent to it before this time.
    private var retryAt: [UsageProvider: Date] = [:]
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
        if let until = retryAt[current], until > Date() {
            problem = UsageModel.rateLimitText(current, until)
            objectWillChange.send()
            return
        }
        DispatchQueue.global(qos: .utility).async {
            let result: FetchResult
            switch current {
            case .codex: result = UsageModel.fetchCodex()
            case .claude: result = UsageModel.fetchClaude()
            }
            DispatchQueue.main.async {
                guard self.provider == current else { return }
                switch result {
                case let .reading(value, reset):
                    self.remaining = value
                    self.reset = reset
                    self.problem = nil
                    self.retryAt[current] = nil
                    self.saveCached()
                    return
                case let .rateLimited(until):
                    self.retryAt[current] = until
                    self.problem = UsageModel.rateLimitText(current, until)
                case let .signIn(message):
                    self.problem = message
                case .unavailable:
                    self.problem = "Couldn't get usage from \(current.rawValue). Trying again in 5 minutes."
                }
                // A failed check keeps the last good reading, unless its window has already reset.
                if let reset = self.reset, reset < Date() {
                    self.remaining = nil
                    self.reset = nil
                    self.saveCached()
                }
            }
        }
    }

    private static func rateLimitText(_ provider: UsageProvider, _ until: Date) -> String {
        "\(provider.rawValue) is limiting usage checks. Next check at \(until.formatted(date: .omitted, time: .shortened))."
    }

    // MARK: - Codex

    private static func fetchCodex() -> FetchResult {
        let authURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")
        guard let authData = try? Data(contentsOf: authURL),
              let auth = try? JSONSerialization.jsonObject(with: authData) as? [String: Any],
              let tokens = auth["tokens"] as? [String: Any],
              let token = tokens["access_token"] as? String else {
            return .signIn("No Codex sign-in found. Run codex and sign in with ChatGPT.")
        }
        let accountID = tokens["account_id"] as? String ?? ""
        let reply = request(url: "https://chatgpt.com/backend-api/wham/usage",
                            headers: ["Accept: application/json",
                                      "Authorization: Bearer \(token)",
                                      "ChatGPT-Account-Id: \(accountID)"])
        if let failure = failure(reply, expired: "Codex sign-in expired. Run codex once to renew it.") { return failure }
        guard let limit = reply?.json?["rate_limit"] as? [String: Any],
              let primary = limit["primary_window"] as? [String: Any],
              let used = number(primary["used_percent"]) else { return .unavailable }
        return .reading(max(0, 100 - Int(used)), date(primary["reset_at"]))
    }

    // MARK: - Claude

    /// Claude Code's usage endpoint and the OAuth token it accepts. The response has
    /// `five_hour` and `seven_day` windows, each with `utilization` (percent used) and `resets_at`.
    private static func fetchClaude() -> FetchResult {
        guard var credentials = claudeCredentials() else {
            return .signIn("No Claude Code sign-in found. Sign in to Claude Code first.")
        }
        // Claude Code renews its sign-in only while it runs, and the desktop app keeps a
        // separate one, so the saved token often expires. Asking with it would just spend
        // the usage endpoint's small request allowance, so renew it first.
        if let expires = credentials.expires, expires < Date() {
            guard renewClaudeSignIn(), let renewed = claudeCredentials(), (renewed.expires ?? .distantFuture) > Date() else {
                return .signIn("Claude sign-in expired at \(expires.formatted(date: .omitted, time: .shortened)). Run claude in Terminal once to renew it.")
            }
            credentials = renewed
        }
        let reply = request(url: "https://api.anthropic.com/api/oauth/usage",
                            headers: ["Accept: application/json",
                                      "Authorization: Bearer \(credentials.token)",
                                      "anthropic-version: 2023-06-01",
                                      "anthropic-beta: oauth-2025-04-20"])
        if let failure = failure(reply, expired: "Claude sign-in expired. Use Claude Code once to renew it.") { return failure }
        guard let window = reply?.json?["five_hour"] as? [String: Any],
              let used = number(window["utilization"]) else { return .unavailable }
        return .reading(max(0, 100 - Int(used.rounded())), date(window["resets_at"]))
    }

    private static var lastRenewal: Date?

    /// Runs `claude doctor`, which makes the Claude Code CLI renew its saved sign-in
    /// without sending a prompt (so it uses none of your allowance). Tried at most once
    /// every 10 minutes; returns whether it ran.
    private static func renewClaudeSignIn() -> Bool {
        if let lastRenewal, Date().timeIntervalSince(lastRenewal) < 600 { return false }
        lastRenewal = Date()
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = ["\(home)/.local/bin/claude", "\(home)/.claude/local/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
        guard let cli = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cli)
        process.arguments = ["doctor"]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment
        process.currentDirectoryURL = URL(fileURLWithPath: home)
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return false }
        DispatchQueue.global().asyncAfter(deadline: .now() + 60) { if process.isRunning { process.terminate() } }
        process.waitUntilExit()
        return true
    }

    /// Claude Code stores its login in the macOS Keychain ("Claude Code-credentials").
    /// Falls back to ~/.claude/.credentials.json when the Keychain entry is missing.
    private static func claudeCredentials() -> (token: String, expires: Date?)? {
        if let data = run("/usr/bin/security", ["find-generic-password", "-s", "Claude Code-credentials", "-w"]),
           let credentials = oauthCredentials(from: data) {
            return credentials
        }
        let fileURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/.credentials.json")
        if let data = try? Data(contentsOf: fileURL), let credentials = oauthCredentials(from: data) {
            return credentials
        }
        return nil
    }

    private static func oauthCredentials(from data: Data) -> (token: String, expires: Date?)? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty else { return nil }
        return (token, date(oauth["expiresAt"]))
    }

    // MARK: - Helpers

    private struct Reply {
        let status: Int
        let retryAfter: String
        let json: [String: Any]?
    }

    /// Calls the endpoint with the system curl and returns the status code, the
    /// Retry-After header, and the JSON body.
    private static func request(url: String, headers: [String]) -> Reply? {
        var args = ["-sS", "--max-time", "15", "-w", "\n%{http_code} %header{retry-after}"]
        for header in headers { args += ["-H", header] }
        args.append(url)
        guard let data = run("/usr/bin/curl", args), let text = String(data: data, encoding: .utf8),
              let split = text.range(of: "\n", options: .backwards) else { return nil }
        let meta = text[split.upperBound...].split(separator: " ", maxSplits: 1)
        let body = Data(text[..<split.lowerBound].utf8)
        return Reply(status: Int(meta.first ?? "") ?? 0,
                     retryAfter: meta.count > 1 ? String(meta[1]).trimmingCharacters(in: .whitespacesAndNewlines) : "",
                     json: (try? JSONSerialization.jsonObject(with: body)) as? [String: Any])
    }

    /// Turns an unsuccessful reply into a result, or returns nil for a 2xx reply.
    private static func failure(_ reply: Reply?, expired: String) -> FetchResult? {
        guard let reply else { return .unavailable }
        switch reply.status {
        case 200..<300: return nil
        case 429:
            // Honor Retry-After (seconds), within 1 minute to 2 hours; otherwise wait 15 minutes.
            let seconds = Double(reply.retryAfter).map { min(max($0, 60), 7200) } ?? 900
            return .rateLimited(until: Date().addingTimeInterval(seconds))
        case 401, 403: return .signIn(expired)
        default: return .unavailable
        }
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
