import SwiftUI
import AppKit
import Combine

/// Started with plain AppKit: the menu is AppDelegate's own status item and panel, and a
/// SwiftUI App needs a scene, which macOS opens as an empty window when the app launches.
@main
enum AIMeterApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menu: MenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let text = Strings.current
        let updates = UpdateChecker(appName: "AI Meter", repo: "getguruhat/ai-meter",
                                    wording: .init(title: text.updateTitle, message: text.updateMessage,
                                                   download: text.download, later: text.later))
        updates.start()
        menu = MenuController(usage: UsageModel(), updates: updates)
    }
}

/// The menu bar item and the panel it opens. A MenuBarExtra window doesn't shrink when
/// its content does, so switching from Claude (two cards) to Codex (one) left the
/// content floating lower in a window that was too tall. This panel is always sized to
/// its content, centered under the item, with its top edge just below the menu bar.
final class MenuController: NSObject {
    private let usage: UsageModel
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel: MenuPanel
    private let hosting: NSHostingView<MenuContent>
    private var watchers: Set<AnyCancellable> = []
    private var outsideClicks: Any?

    init(usage: UsageModel, updates: UpdateChecker) {
        self.usage = usage
        hosting = NSHostingView(rootView: MenuContent(usage: usage, updates: updates))
        panel = MenuPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                          styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        super.init()

        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.onEscape = { [weak self] in self?.close() }

        item.button?.target = self
        item.button?.action = #selector(toggle)
        updateTitle()
        // Read the new values after they change (objectWillChange fires before).
        for publisher in [usage.objectWillChange.eraseToAnyPublisher(), updates.objectWillChange.eraseToAnyPublisher()] {
            publisher.receive(on: DispatchQueue.main).sink { [weak self] in
                self?.updateTitle()
                self?.fit()
            }.store(in: &watchers)
        }
    }

    private func updateTitle() {
        item.button?.title = usage.menuTitle
    }

    @objc private func toggle() {
        panel.isVisible ? close() : show()
    }

    func show() {
        guard let button = item.button, let buttonWindow = button.window else { return }
        let size = hosting.fittingSize
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let x = min(max(anchor.midX - size.width / 2, screen.minX + 8), screen.maxX - size.width - 8)
        panel.setFrame(NSRect(x: x, y: anchor.minY - 6 - size.height, width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
        panel.makeKey()
        button.highlight(true)
        outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    func close() {
        panel.orderOut(nil)
        item.button?.highlight(false)
        if let outsideClicks { NSEvent.removeMonitor(outsideClicks) }
        outsideClicks = nil
    }

    /// Resizes the open panel to its content, keeping the top edge where it is.
    private func fit() {
        guard panel.isVisible else { return }
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        var frame = panel.frame
        guard abs(frame.height - size.height) > 0.5 || abs(frame.width - size.width) > 0.5 else { return }
        frame.origin.y = frame.maxY - size.height
        frame.origin.x = frame.midX - size.width / 2
        frame.size = size
        panel.setFrame(frame, display: true)
    }
}

/// A borderless panel that can take clicks and Escape without activating the app.
final class MenuPanel: NSPanel {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onEscape?() }
}

struct MenuContent: View {
    @ObservedObject var usage: UsageModel
    @ObservedObject var updates: UpdateChecker

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            // Both windows share one card, so the colored bars are what stands out.
            if let primary = usage.primary {
                VStack(alignment: .leading, spacing: 12) {
                    WindowMeter(window: primary, plan: usage.plan)
                    if let secondary = usage.secondary {
                        Divider()
                        WindowMeter(window: secondary, plan: nil)
                    }
                }
                .card(padding: 12)
            } else {
                Text(Strings.current.unavailable).font(.system(size: 14, weight: .semibold)).card(padding: 12)
            }

            if let problem = usage.problem {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.orange)
                        Text(problem).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                    }
                    if usage.needsSignIn {
                        Link(Strings.current.troubleshooting, destination: usage.troubleshootingURL)
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.accent)
                    }
                }
                .card(padding: 12)
            }

            if let update = updates.available {
                Link(destination: update.page) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 18)).foregroundStyle(Theme.accent)
                        Text(Strings.fill(Strings.current.updateTitle, "AI Meter", update.version))
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.text)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.secondary)
                    }
                    .card(padding: 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 300)
        .foregroundStyle(Theme.text)
        .fixedSize(horizontal: false, vertical: true)
        // Opaque, in the panel's rounded shape. Light or dark follows the system, like the Theme colors.
        .background(Theme.page)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// The provider switch, then Refresh, About and Quit, on one row.
    private var header: some View {
        HStack(spacing: 6) {
            ProviderSwitch(selection: $usage.provider)
            Button { usage.refresh() } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(CircleButtonStyle(size: 30))
                .help(Strings.current.refresh).accessibilityLabel(Strings.current.refresh)
            Button { AboutWindowController.shared.show() } label: { Image(systemName: "info") }
                .buttonStyle(CircleButtonStyle(size: 30))
                .help(Strings.current.about).accessibilityLabel(Strings.current.about)
            Button { NSApplication.shared.terminate(nil) } label: { Image(systemName: "power") }
                .buttonStyle(CircleButtonStyle(size: 30))
                .help(Strings.current.quit).accessibilityLabel(Strings.current.quit)
        }
    }
}

/// The Codex/Claude switch: a soft grey track with the selected provider on a white pill,
/// quiet enough that the usage bars stay the brightest thing in the menu. Plain buttons,
/// because a segmented Picker in the menu bar window didn't always take the click.
struct ProviderSwitch: View {
    @Binding var selection: UsageProvider

    var body: some View {
        HStack(spacing: 2) {
            ForEach(UsageProvider.allCases) { provider in
                let selected = provider == selection
                Button { selection = provider } label: {
                    Text(provider.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selected ? Theme.text : Theme.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(Capsule().fill(selected ? Theme.card : Color.clear)
                            .shadow(color: .black.opacity(selected ? 0.12 : 0), radius: 1.5, y: 0.5))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.primary.opacity(0.07)))
        .accessibilityLabel(Strings.current.provider)
    }
}

/// One usage window: its name (with the plan beside the first one), what's left, a bar
/// colored by how much is left, and when it resets.
struct WindowMeter: View {
    let window: UsageWindow
    let plan: String?

    /// Named by its length: Codex's free plan has a single monthly window.
    private var title: String {
        switch window.seconds {
        case ..<86_400: return Strings.current.fiveHour
        case ..<(8 * 86_400): return Strings.current.weekly
        default: return Strings.current.monthly
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.secondary)
                if let plan {
                    Text(Strings.fill(Strings.current.plan, plan))
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.accent)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(Theme.accent.opacity(0.12)))
                        .fixedSize()
                }
                Spacer()
                Text(Strings.fill(Strings.current.percentLeft, window.remaining))
                    .font(.system(size: 15, weight: .semibold)).monospacedDigit()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.control)
                    if window.remaining > 0 {
                        Capsule().fill(Theme.level(window.remaining))
                            .frame(width: max(8, proxy.size.width * CGFloat(min(window.remaining, 100)) / 100))
                    }
                }
            }
            .frame(height: 7)
            if let reset = window.reset {
                Text(Strings.fill(Strings.current.resets, reset.formatted(date: .abbreviated, time: .shortened)))
                    .font(.system(size: 11)).foregroundStyle(Theme.secondary)
            }
        }
        .accessibilityElement(children: .combine)
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
        window.title = Strings.current.about
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
            Text(Strings.fill(Strings.current.version, "1.6.1"))
                .foregroundStyle(.secondary)
            Text(Strings.current.tagline)
                .font(.headline)
            Divider().padding(.vertical, 6)
            Link(destination: donationURL) {
                Label(Strings.current.support, systemImage: "heart.fill")
                    .frame(maxWidth: .infinity)
            }
            Text(Strings.current.thanks)
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

/// One usage window: the percent left, when it resets, and how long it lasts.
struct UsageWindow {
    var remaining: Int
    var reset: Date?
    var seconds: Double
}

/// What one usage check produced. Anything other than a reading leaves the last good
/// reading on screen, with the reason it couldn't be updated shown in the menu.
enum FetchResult {
    case reading(UsageWindow, secondary: UsageWindow?, plan: String?)
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
            needsSignIn = false
            loadCached()
            refresh()
        }
    }
    /// The shortest window (five hours, or a month on Codex's free plan), which the menu bar title shows.
    @Published var primary: UsageWindow?
    /// The weekly window, when the plan has one.
    @Published var secondary: UsageWindow?
    /// The plan name the provider reports, such as "Free" or "Pro".
    @Published var plan: String?
    @Published var problem: String?
    /// True when the problem is a missing or expired sign-in, so the menu links to the troubleshooting guide.
    @Published var needsSignIn = false
    /// The troubleshooting guide, opened at the Codex section when Codex is selected.
    var troubleshootingURL: URL {
        URL(string: "https://guruhat.com/apps/ai-meter/troubleshooting/" + (provider == .codex ? "#codex" : ""))!
    }
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
        primary = loadWindow("", defaultSeconds: 5 * 3600)
        secondary = loadWindow("weekly.", defaultSeconds: 7 * 86_400)
        plan = UserDefaults.standard.string(forKey: cacheKey("plan"))
    }

    private func saveCached() {
        saveWindow(primary, "")
        saveWindow(secondary, "weekly.")
        UserDefaults.standard.set(plan, forKey: cacheKey("plan"))
    }

    private func loadWindow(_ prefix: String, defaultSeconds: Double) -> UsageWindow? {
        let defaults = UserDefaults.standard
        guard let remaining = defaults.object(forKey: cacheKey(prefix + "remaining")) as? Int else { return nil }
        let resetTime = defaults.double(forKey: cacheKey(prefix + "reset"))
        let seconds = defaults.double(forKey: cacheKey(prefix + "seconds"))
        return UsageWindow(remaining: remaining, reset: resetTime > 0 ? Date(timeIntervalSince1970: resetTime) : nil,
                           seconds: seconds > 0 ? seconds : defaultSeconds)
    }

    private func saveWindow(_ window: UsageWindow?, _ prefix: String) {
        let defaults = UserDefaults.standard
        defaults.set(window?.remaining, forKey: cacheKey(prefix + "remaining"))
        defaults.set(window?.reset?.timeIntervalSince1970 ?? 0, forKey: cacheKey(prefix + "reset"))
        defaults.set(window?.seconds ?? 0, forKey: cacheKey(prefix + "seconds"))
    }
    deinit { timer?.invalidate() }

    var menuTitle: String { primary.map { "AI \($0.remaining)%" } ?? "AI —" }

    /// Fetches usage for the selected provider on a background queue and publishes the result on the main queue.
    func refresh() {
        let current = provider
        // While the provider has asked us to back off, quietly keep the last reading.
        if let until = retryAt(current), until > Date() { return }
        DispatchQueue.global(qos: .utility).async {
            let result: FetchResult
            switch current {
            case .codex: result = UsageModel.fetchCodex()
            case .claude: result = UsageModel.fetchClaude()
            }
            DispatchQueue.main.async {
                guard self.provider == current else { return }
                if case .signIn = result { self.needsSignIn = true } else { self.needsSignIn = false }
                switch result {
                case let .reading(primary, secondary, plan):
                    self.primary = primary
                    self.secondary = secondary
                    self.plan = plan
                    self.problem = nil
                    self.setRetryAt(nil, for: current)
                    self.saveCached()
                    return
                case let .rateLimited(until):
                    // Not worth a warning: the last reading stays on screen, and the next
                    // check after the wait brings it up to date.
                    self.setRetryAt(until, for: current)
                    self.problem = nil
                case let .signIn(message):
                    self.problem = message
                case .unavailable:
                    self.problem = Strings.fill(Strings.current.unreachable, current.rawValue)
                }
                // A failed check keeps the last good reading, unless its window has already reset.
                if let reset = self.primary?.reset, reset < Date() { self.primary = nil; self.secondary = nil }
                if let reset = self.secondary?.reset, reset < Date() { self.secondary = nil }
                self.saveCached()
            }
        }
    }

    /// When a provider asked us to back off, no request is sent to it before this time.
    /// Saved, so quitting and reopening the app doesn't skip the wait.
    private func retryAt(_ provider: UsageProvider) -> Date? {
        let time = UserDefaults.standard.double(forKey: "\(provider.rawValue).retryAt")
        return time > 0 ? Date(timeIntervalSince1970: time) : nil
    }

    private func setRetryAt(_ date: Date?, for provider: UsageProvider) {
        UserDefaults.standard.set(date?.timeIntervalSince1970 ?? 0, forKey: "\(provider.rawValue).retryAt")
    }

    // MARK: - Codex

    private static func fetchCodex() -> FetchResult {
        let authURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")
        guard let authData = try? Data(contentsOf: authURL),
              let auth = try? JSONSerialization.jsonObject(with: authData) as? [String: Any],
              let tokens = auth["tokens"] as? [String: Any],
              let token = tokens["access_token"] as? String else {
            return .signIn(Strings.current.codexNoSignIn)
        }
        let accountID = tokens["account_id"] as? String ?? ""
        let reply = request(url: "https://chatgpt.com/backend-api/wham/usage",
                            headers: ["Accept: application/json",
                                      "Authorization: Bearer \(token)",
                                      "ChatGPT-Account-Id: \(accountID)"])
        if let failure = failure(reply, expired: Strings.current.codexExpired) { return failure }
        // The free plan has one 30-day window and no weekly one; paid plans have five hours and a week.
        guard let limit = reply?.json?["rate_limit"] as? [String: Any],
              let primary = window(limit["primary_window"], used: "used_percent", reset: "reset_at",
                                   seconds: "limit_window_seconds", defaultSeconds: 5 * 3600) else { return .unavailable }
        return .reading(primary,
                        secondary: window(limit["secondary_window"], used: "used_percent", reset: "reset_at",
                                          seconds: "limit_window_seconds", defaultSeconds: 7 * 86_400),
                        plan: planName(reply?.json?["plan_type"]))
    }

    // MARK: - Claude

    /// Claude Code's usage endpoint and the OAuth token it accepts. The response has
    /// `five_hour` and `seven_day` windows, each with `utilization` (percent used) and `resets_at`.
    private static func fetchClaude() -> FetchResult {
        guard var credentials = claudeCredentials() else {
            return .signIn(Strings.current.claudeNoSignIn)
        }
        // Claude Code renews its sign-in only while it runs, and the desktop app keeps a
        // separate one, so the saved token often expires. Asking with it would just spend
        // the usage endpoint's small request allowance, so renew it first.
        if let expires = credentials.expires, expires < Date() {
            guard renewClaudeSignIn(), let renewed = claudeCredentials(), (renewed.expires ?? .distantFuture) > Date() else {
                return .signIn(Strings.fill(Strings.current.claudeExpiredAt, expires.formatted(date: .omitted, time: .shortened)))
            }
            credentials = renewed
        }
        let reply = request(url: "https://api.anthropic.com/api/oauth/usage",
                            headers: ["Accept: application/json",
                                      "Authorization: Bearer \(credentials.token)",
                                      "anthropic-version: 2023-06-01",
                                      "anthropic-beta: oauth-2025-04-20"])
        if let failure = failure(reply, expired: Strings.current.claudeExpired) { return failure }
        guard let fiveHour = window(reply?.json?["five_hour"], used: "utilization", reset: "resets_at",
                                    defaultSeconds: 5 * 3600) else { return .unavailable }
        return .reading(fiveHour,
                        secondary: window(reply?.json?["seven_day"], used: "utilization", reset: "resets_at",
                                          defaultSeconds: 7 * 86_400),
                        plan: planName(credentials.plan))
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
    private static func claudeCredentials() -> (token: String, expires: Date?, plan: String?)? {
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

    private static func oauthCredentials(from data: Data) -> (token: String, expires: Date?, plan: String?)? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty else { return nil }
        return (token, date(oauth["expiresAt"]), oauth["subscriptionType"] as? String)
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

    /// Reads a usage window reported as percent used plus a reset time, and its length
    /// when the reply says it.
    private static func window(_ value: Any?, used usedKey: String, reset resetKey: String,
                               seconds secondsKey: String? = nil, defaultSeconds: Double) -> UsageWindow? {
        guard let window = value as? [String: Any], let used = number(window[usedKey]) else { return nil }
        let seconds = secondsKey.flatMap { number(window[$0]) }.flatMap { $0 > 0 ? $0 : nil } ?? defaultSeconds
        return UsageWindow(remaining: max(0, 100 - Int(used.rounded())), reset: date(window[resetKey]), seconds: seconds)
    }

    /// "free" → "Free", "pro" → "Pro"; nil when the provider doesn't say.
    private static func planName(_ value: Any?) -> String? {
        guard let plan = value as? String, !plan.isEmpty else { return nil }
        return plan.prefix(1).uppercased() + plan.dropFirst()
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
