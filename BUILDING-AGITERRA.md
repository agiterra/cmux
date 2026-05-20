# Building agiterra cmux

This branch (`agiterra-main`) is a soft fork of `manaflow-ai/cmux` that bundles fixes and configuration we need ahead of upstream merges, so the agiterra team can run a properly-signed daily-driver build.

## What's different from upstream `main`

Three things:

1. **Merged unmerged PRs we depend on** — e.g. [#4193](https://github.com/manaflow-ai/cmux/pull/4193) (fixes offscreen terminal startup + cold send for socket-created surfaces). This is what makes `cmux new-workspace` followed by `cmux send` actually work for headless agent orchestration. Without #4193 the surface has no PTY allocated and send rejects with "Surface is not a terminal."

2. **Proper signing setup** — `scripts/reloads.sh` is patched to sign tagged Release builds with a real Apple Development certificate instead of ad-hoc. With ad-hoc signing the bundle CDHash changes every rebuild, macOS treats every rebuild as a "different app at the same path," and TCC re-prompts for every protected category every time. Apple-signed builds with a stable Team ID don't have this problem — TCC remembers grants by Team+Identifier.

3. **Empty in-app entitlements** — `Resources/cmux.entitlements` is emptied (originally just `keychain-access-groups`). For local daily-driver builds we don't need in-app keychain (Wire's passkey lives in the browser dashboard). Removing it lets us sign without an Apple-provisioned profile for our custom bundle ID.

## Prerequisites

| Tool | Version | Why |
|---|---|---|
| Xcode | 26.0.1+ | Build toolchain |
| `xcodebuild -downloadComponent MetalToolchain` | ~700 MB | Required at link time |
| `zig` | `0.15.x` exactly | Ghostty's `build.zig.zon` rejects 0.16. Use `brew install zig@0.15` |
| Apple Developer account | Any tier with a dev cert in Keychain | Stable Team ID for TCC |
| Git submodules | initialized | `ghostty`, `vendor/bonsplit`, `homebrew-cmux` |

First-time setup:

```bash
git submodule update --init --recursive
brew install zig@0.15
./scripts/setup.sh    # builds GhosttyKit.xcframework via zig — slow first time
```

## Build invocation

```bash
DEVELOPMENT_TEAM=<your-team-id> \
CODE_SIGN_STYLE=Automatic \
PATH="/opt/homebrew/opt/zig@0.15/bin:$PATH" \
./scripts/reloads.sh \
  --tag agiterra \
  --name agiterra \
  --bundle-id com.<your-domain>.agiterra
```

- **`DEVELOPMENT_TEAM`** — your Apple Team ID (find via `security find-identity -p codesigning -v` — it's the 10-char string in parentheses after your cert name)
- **`--bundle-id`** — must be under a domain your Apple Developer account can auto-provision. Personal teams can use anything; paid teams typically need wildcards or pre-registered IDs. Don't use `com.cmuxterm.app.*` — that collides with Manaflow's bundle ID space.
- **`--tag agiterra`** — names the build slug (derived-data path, app display name, socket name)
- The `CMUX_ALLOW_SOCKET_OVERRIDE=1` env that lets socket isolation work under non-staging bundle IDs is set automatically by the patched `reloads.sh`.

Output lands at: `/tmp/cmux-staging-agiterra/Build/Products/Release/agiterra.app`

## Install + activate

```bash
# Quit any running agiterra
osascript -e 'tell application id "com.<your-domain>.agiterra" to quit' 2>/dev/null

# Atomic swap
ditto /tmp/cmux-staging-agiterra/Build/Products/Release/agiterra.app /Applications/agiterra.app.new
rm -rf /Applications/agiterra.app.old
[ -e /Applications/agiterra.app ] && mv /Applications/agiterra.app /Applications/agiterra.app.old
mv /Applications/agiterra.app.new /Applications/agiterra.app
xattr -dr com.apple.quarantine /Applications/agiterra.app

# Relaunch
open /Applications/agiterra.app
```

## First-launch TCC prompts

On the first launch of a freshly-signed build, macOS will prompt once per protected category your subprocesses touch (Apple Events, Accessibility, Files-and-Folders, Local Network, Photos, Music, etc.). Click Allow for each one. **Because the build is properly signed with a stable Team ID, those grants persist across future rebuilds.** No prompt storms on subsequent rebuilds (unlike ad-hoc).

If you want to silence the first burst before launching, pre-grant in System Settings → Privacy & Security:
- **Full Disk Access** → + → agiterra
- **Files and Folders** → toggle agiterra ON for all subfolders
- **Automation** → agiterra → toggle ON for everything you'd want it to control
- **Accessibility** → + → agiterra

## Rebuilding (after upstream main moves)

```bash
cd <your-cmux-clone>
git checkout agiterra-main
git fetch origin    # manaflow-ai/cmux
git rebase origin/main
# resolve conflicts if any in scripts/reloads.sh or Resources/cmux.entitlements
# (the agiterra commit on this branch is one localized change; rebases cleanly except when reloads.sh changes upstream)

# Re-run the build invocation above + reinstall
```

## Rolling back

```bash
osascript -e 'tell application id "com.<your-domain>.agiterra" to quit'
rm -rf /Applications/agiterra.app
mv /Applications/agiterra.app.old /Applications/agiterra.app
open /Applications/agiterra.app
```

## Why a fork at all (vs upstream contributions)

The build-config tweaks (entitlements, signing identity, bundle ID prefix) are **per-installer choices** — they can't sensibly land in Manaflow's upstream because Manaflow signs with their own team and their own bundle IDs. The fork carries our local-build configuration; we periodically rebase on upstream main to inherit fixes.

The PR-merges-not-yet-upstream pieces (e.g. #4193) are different — those are real bugs Manaflow is also working on. As they merge upstream, our `git rebase origin/main` deduplicates them and our branch shrinks.

## See also

- Upstream cmux: [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux)
- Agiterra Multi-Agent Toolkit handbook: [agiterra/handbook](https://github.com/agiterra/handbook)
