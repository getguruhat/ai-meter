# AI Meter

**Your remaining Claude Code or Codex usage, right in the Mac menu bar.**

![AI Meter menu showing 41% of AI usage remaining](https://guruhat.com/assets/ai-meter/ai-meter-menu.webp)

AI Meter is a free, open-source GuruHat menu-bar tool for macOS. It displays the remaining AI allowance for either Codex or Claude, depending on the provider selected in the menu, and refreshes every five minutes. It reads your existing local sign-in through the system `curl` command; if a provider changes its usage endpoint, the display will show `AI —` until updated.

- **Codex:** remaining allowance from the ChatGPT session in `~/.codex/auth.json`.
- **Claude:** the five-hour window from the Claude Code sign-in stored in the macOS Keychain (`Claude Code-credentials`), or `~/.claude/.credentials.json` if the Keychain entry is not found.

Website: https://guruhat.com/apps/ai-meter/
Windows version: https://github.com/getguruhat/ai-meter-windows
GitHub organization: https://github.com/getguruhat

## Download

Download the latest packaged macOS installer from the [GitHub Releases page](../../releases/latest).

After downloading:

1. Open `AI-Meter-Installer.dmg`.
2. Drag `AI Meter.app` onto the Applications folder shortcut.
3. Open it from Applications and approve **Open** if macOS shows an unsigned-app warning.

AI Meter is currently built for Apple silicon Macs. The release package includes the complete app bundle and does not require Swift or Xcode to be installed.

## Requirements

- macOS 13 or later
- Swift 5.9 or later (the package uses Swift Package Manager)
- A signed-in Codex/ChatGPT session (`~/.codex/auth.json`) for the Codex provider, and/or a signed-in Claude Code session for the Claude provider

Claude Code renews its saved sign-in only while the `claude` command runs (the Claude desktop app keeps a separate one). When the saved sign-in has expired, AI Meter runs `claude doctor` in the background, at most every 10 minutes, so the CLI renews it. That sends no prompt and uses none of your allowance.

The first time Claude usage is read, macOS may ask whether AI Meter (or `security`) can access the `Claude Code-credentials` Keychain item. Choose **Always Allow** to avoid repeated prompts.

## Build and run from the command line

From this directory, build the executable with:

```sh
swift build -c release
```

Run the app directly with:

```sh
swift run -c release
```

The app runs as a menu-bar-only application, so there is no normal window or terminal output. Click the `AI —` menu-bar item to view the status. Stop it with `Control-C` in the terminal, or choose **Quit** from the menu.

For a debug build, use `swift run` without `-c release`.

## Create and run an app bundle

To create a relocatable `.app` bundle from the release executable:

```sh
./build-app.sh
```

This also creates `AI-Meter-Installer.dmg`, a Finder disk image with the app and an
Applications shortcut arranged for drag-and-drop installation.

If macOS blocks the app because it is unsigned, use **System Settings > Privacy & Security > Open Anyway**, or run it from the command line with `open "AI Meter.app"` after reviewing the warning.

## Start automatically at login (optional)

The included `com.guruhat.aimeter.plist` is a `launchd` agent. Its `ProgramArguments` points to `/Users/andre/Applications/AI Meter.app`. Update that path if the app is stored elsewhere. Then install and load it with:

```sh
mkdir -p ~/Applications
cp -R "AI Meter.app" ~/Applications/
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.guruhat.aimeter.plist 2>/dev/null || true
cp com.guruhat.aimeter.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.guruhat.aimeter.plist
```

To stop automatic launch, unload the agent and remove the installed plist:

```sh
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.guruhat.aimeter.plist
rm ~/Library/LaunchAgents/com.guruhat.aimeter.plist
```

## Xcode

Open the folder in Xcode, or use **File > Open Package** and select this directory. Select the `AIMeter` scheme and run it on **My Mac**. The package manifest defines the executable target and the minimum macOS version; no separate Xcode project is required.

The app reads the access tokens locally and calls each provider's usage endpoint through the system `curl` executable. The Claude provider calls `https://api.anthropic.com/api/oauth/usage`, and the Codex provider calls `https://chatgpt.com/backend-api/wham/usage`. If the credentials are missing or the endpoint response changes, the menu bar displays `AI —`. Tokens are never sent anywhere else, and AI Meter has no analytics.

## License

MIT. AI Meter is an independent project and is not affiliated with Anthropic or OpenAI.
