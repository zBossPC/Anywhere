# AGENTS.md

Guidance for AI agents working in the Anywhere repository.

## Product overview

**Anywhere** is a native iOS/iPadOS/tvOS proxy/VPN client (Swift + vendored C). It is **not** a web app or server-side project. There is no `package.json`, Docker stack, or backend API to run locally.

| Target | Scheme | Purpose |
| --- | --- | --- |
| **Anywhere** (required) | `Anywhere` | Main SwiftUI app |
| **Network Extension** (required for VPN E2E) | `Anywhere Network Extension` | Packet tunnel (`NEPacketTunnelProvider`) |
| Anywhere TV (optional) | `Anywhere TV` | tvOS variant |
| Anywhere Widget (optional) | `Anywhere Widget` | WidgetKit VPN toggle |

## Development environment (macOS — required for build/run)

Full development requires **macOS with Xcode** (project `LastUpgradeVersion = 2640`, iOS deployment target **17.0+**).

1. Open `Anywhere.xcodeproj` in Xcode.
2. Select the **Anywhere** scheme and an iOS Simulator or device.
3. Set your own **Development Team** (project currently references team `C7AS5D38Q8`).
4. Build and run (`⌘R`). The Network Extension is embedded and launches when VPN connects.

**Signing:** Network Extension, App Group (`group.com.argsment.Anywhere`), and Keychain entitlements require valid Apple provisioning.

**SPM dependencies** (resolved by Xcode): [Argsment/BLAKE3](https://github.com/Argsment/BLAKE3.git), [Argsment/YAML](https://github.com/Argsment/YAML.git).

**Bundled data:** `Shared/DataStore/Rules.db` (SQLite routing rules, ~39k rules).

**No automated test targets** (`XCTest` / test plans) are configured in this repo.

### Useful commands (macOS only)

```bash
# Build for iOS Simulator
xcodebuild -project Anywhere.xcodeproj -scheme Anywhere \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build Network Extension
xcodebuild -project Anywhere.xcodeproj -scheme "Anywhere Network Extension" \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### External runtime dependencies (for meaningful E2E proxy testing)

- User-configured proxy servers (VLESS, Hysteria2, Trojan, Shadowsocks, etc.) or subscription URLs
- Not part of the repo; needed to test real proxy connectivity beyond UI/build

## Code navigation

| Area | Path |
| --- | --- |
| Proxy protocols | `Shared/Networking/Protocols/` |
| Packet tunnel / lwIP / MITM | `Anywhere Network Extension/` |
| Shared models & stores | `Shared/` |
| Routing rules docs | `Documentations/Routing.md` |
| MITM rewrite docs | `Documentations/MITM.md` |

**Important:** `README.md` is a curated summary, not a spec. Verify behavior in source code when making claims about protocol support.

## Cursor Cloud specific instructions

### Platform limitation

This Cloud Agent VM runs **Linux**. The Anywhere iOS app **cannot be built or run here** — there is no Xcode, iOS SDK, or Simulator. Treat macOS + Xcode as a hard requirement for compile/run/debug workflows.

### What works on Linux (validation only)

Agents can still verify repo health without macOS:

1. **Project structure** — `Anywhere.xcodeproj`, four shared schemes, `Rules.db` present.
2. **SPM remotes** — pins in `Package.resolved` match `main` on GitHub (`Argsment/BLAKE3`, `Argsment/YAML`).
3. **Rules.db** — `sqlite3 Shared/DataStore/Rules.db ".tables"` → `metadata`, `rules`.
4. **SPM package compile** — BLAKE3 and YAML build with Swift on Linux (`swift build` in cloned repos); this validates dependency availability, not the iOS app.

Swift toolchain (if installed on the VM): `/opt/swift/usr/bin` — add to `PATH` before running `swift`.

### What does NOT work on Linux

- `xcodebuild`, iOS Simulator, device deploy, VPN/Network Extension testing
- SwiftUI preview, WidgetKit, JavaScriptCore MITM scripting in-app
- Lint/format — no `.swiftlint.yml` or CI lint config in repo

### Services

| Service | Linux VM | macOS + Xcode |
| --- | --- | --- |
| Anywhere app | Cannot run | Required |
| Network Extension | Cannot run | Required for VPN E2E |
| External proxy server | N/A (user-provided) | Optional for real traffic tests |

No long-running dev servers, databases, or Docker compose stacks exist in this repository.

### Headless cloud compilation (GitHub Actions)

Linux agents can orchestrate **unsigned IPA builds** on `macos-14` runners via `scripts/cloud-build/`:

```bash
# Validate gh auth and preview pipeline
./scripts/cloud-build/cloud-compile.sh --dry-run --fork "$(gh api user -q .login)/Anywhere"

# Full loop: inject workflow → dispatch → watch → download Anywhere.ipa
./scripts/cloud-build/cloud-compile.sh --fork "$(gh api user -q .login)/Anywhere"
```

**Requirements:** `gh` authenticated with `repo` + `workflow` scopes (integration tokens may inject files but cannot `workflow_dispatch`).

| Script | Role |
| --- | --- |
| `cloud-compile.sh` | Main orchestrator |
| `lib/gh-auth.sh` | Validates `gh`; falls back to `gh auth login` |
| `lib/fork.sh` | Idempotent fork of `NodePassProject/Anywhere` |
| `lib/github-api.sh` | Base64 Contents API `PUT` for `.github/workflows/build.yml` |
| `lib/workflow-watch.sh` | `workflow_dispatch`, `gh run watch`, artifact download |
| `workflows/build.yml` | macOS build template (also at `.github/workflows/build.yml`) |

Build flags: Xcode 15.4, `Release` + `iphoneos`, `CODE_SIGNING_ALLOWED=NO`, artifact `Anywhere-Unsigned-IPA`.
