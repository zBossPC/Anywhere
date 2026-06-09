# Cloud Compile — Headless iOS Build Loop

Remote unsigned IPA builds for **Anywhere** via GitHub Actions (`macos-14` + Xcode 15.4).

## Prerequisites

- [GitHub CLI](https://cli.github.com/) (`gh`) installed
- Authenticated session with scopes: `repo`, `workflow`
- A fork of `NodePassProject/Anywhere` under your GitHub account (auto-created if missing)

## Quick start

```bash
# Validate auth and preview the pipeline
./scripts/cloud-build/cloud-compile.sh --dry-run

# Full loop: inject workflow → dispatch → watch → download Anywhere.ipa
./scripts/cloud-build/cloud-compile.sh

# Use an existing fork explicitly
./scripts/cloud-build/cloud-compile.sh --fork "$(gh api user -q .login)/Anywhere"
```

## Pipeline stages

| Stage | Implementation |
| --- | --- |
| Auth validation | `lib/gh-auth.sh` — `gh auth status --json` with `hostname,username` or `hosts` fallback; interactive `gh auth login` trap |
| Fork linkage | `lib/fork.sh` — `gh repo fork NodePassProject/Anywhere --clone=false` (idempotent) |
| Workflow injection | `lib/github-api.sh` — Base64 `PUT` to `.github/workflows/build.yml` via Contents API |
| Build & package | `workflows/build.yml` — `xcodebuild` Release/iphoneos unsigned → `Payload/` → `Anywhere.ipa` |
| Dispatch & watch | `lib/workflow-watch.sh` — `workflow_dispatch`, `gh run watch`, artifact download |

## Workflow build flags

- Runner: `macos-14`
- Toolchain: `sudo xcode-select -s /Applications/Xcode_15.4.app`
- Build: `-scheme Anywhere -configuration Release -sdk iphoneos`
- Overrides: `CODE_SIGNING_ALLOWED=NO`, `ONLY_ACTIVE_ARCH=NO`
- Artifact: `Anywhere-Unsigned-IPA` (contains `Anywhere.ipa`)

## Advanced flags

```bash
./scripts/cloud-build/cloud-compile.sh --help
./scripts/cloud-build/cloud-compile.sh --print-base64          # emit workflow YAML as Base64
./scripts/cloud-build/cloud-compile.sh --skip-dispatch         # inject only
./scripts/cloud-build/cloud-compile.sh --skip-download       # inject + dispatch + watch
./scripts/cloud-build/cloud-compile.sh --branch main --dest .
```

## Layout

```
scripts/cloud-build/
├── cloud-compile.sh          # Main orchestrator
├── lib/
│   ├── common.sh
│   ├── gh-auth.sh
│   ├── fork.sh
│   ├── github-api.sh
│   └── workflow-watch.sh
└── workflows/
    └── build.yml             # GitHub Actions workflow template
```
