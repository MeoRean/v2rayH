# v2rayH

A HarmonyOS / OpenHarmony port of [v2rayNG](https://github.com/2dust/v2rayNG): a
VLESS / VMess / Trojan / Shadowsocks client that drives a real VPN through the
in-tree [Xray-core](https://github.com/xtls/xray-core) kernel.

Traffic flow:

```
apps ──► vpn-tun (VpnExtensionAbility) ──► gVisor netstack (L3→L4)
     ──► Xray VLESS+REALITY outbound ──► internet
```

## Layout

| Path | What |
| --- | --- |
| `entry/src/main/ets/` | ArkTS UI, subscription parsing, VPN extension ability |
| `entry/src/main/cpp/` | NAPI module (`libentry.so`) that hosts the Go kernel |
| `native/libxray/` | Go wrapper + vendored, patched `xray-core` and `gvisor` |
| `native/build_libxray.sh` | rebuild `libxray.a` (openharmony/arm64) — Linux/CI |
| `native/build_libxray.ps1` | same, for a Windows host |
| `.github/workflows/build-libxray.yml` | CI that produces `libxray.a` |

## Native kernel

The kernel is built as a **c-archive** which CMake statically links into
`libentry.so`, so there is no runtime SONAME to ship.

Two things are needed to build it:

1. **ohos-go** — a Go toolchain that knows `GOOS=openharmony`/`GOARCH=arm64`.
   Prebuilt `linux-amd64` / `darwin-arm64` tarballs come from
   <https://github.com/sysit/ohos-go/releases>.
   (Stock Go cannot target OpenHarmony. The stock compiler also emits
   `R_AARCH64_TLS_TPREL64` initial-exec TLS relocations, which musl refuses at
   `dlopen`; ohos-go emits `R_AARCH64_TLSDESC` instead.)
2. **OpenHarmony SDK native toolchain** — `clang` + `sysroot` for
   `aarch64-linux-ohos`. Comes from either DevEco Studio
   (`sdk/default/openharmony/native/…`) or the public mirror
   <https://repo.huaweicloud.com/openharmony/os/>, where
   `ohos-sdk-windows_linux-public.tar.gz` contains a per-component
   `linux/native-*.zip`.

```bash
# Linux / CI
OHOS_GO=/path/to/ohos-go OHOS_SDK=/path/to/ohos-sdk ./native/build_libxray.sh

# Windows
.\native\build_libxray.ps1 -OHOS_GO C:\ohos-go -OHOS_SDK "C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony"
```

Both copy the result into `entry/src/main/cpp/thirdparty/libxray/`
(`libs/arm64-v8a/libxray.a` + `include/libxray.h`), which is git-ignored —
`devecocli build` needs it present.

## Building the app

```bash
devecocli build
devecocli run --skip-build
```

## PC (2-in-1) adaptation

`deviceTypes` includes `2in1`, so the HAP installs on HarmonyOS PCs.

- **Adaptive layout** — `EntryAbility` tracks the window width
  (`windowSizeChange` → `AppStorage('winWidthVp')`). At ≥ 600vp (the lg
  breakpoint) `Index` swaps the phone bottom tab bar for a side navigation
  rail with a width-capped (840vp), centered content column; below that the
  original phone layout stays. Drag the window across the breakpoint and the
  layout follows live.
- **Close-to-tray** — with `ohos.permission.PREPARE_APP_TERMINATE`,
  `onPrepareToTerminate()` intercepts the window X button on 2-in-1/tablet.
  On PC the app registers a status-bar (tray) icon via
  `@kit.DeskTopExtensionKit` `statusBarManager` at startup: left-click the
  icon to bring the window back, right-click for「显示主窗口 / 退出 v2rayH」
  (handled through `notifyOnly` menu events). Closing with X calls
  `hideAbility()` — window *and* taskbar entry disappear, the app lives in
  the tray and the VPN stays up. Quitting from the tray menu (or the dock
  right-click close, which bypasses the interceptor) terminates for real;
  `EntryAbility.onDestroy()` then stops the VPN extension so no orphaned
  tunnel survives. Settings also offers an in-app「断开并退出」action with
  the same semantics. Phones/tablets without the status-bar syscap skip tray
  setup entirely (`trayReady` stays false, X falls back to a plain
  minimize).

## CI

`.github/workflows/build-libxray.yml` runs on manual dispatch, on
`native/**` changes, on release publishes, and weekly. It downloads the two
toolchains above (both cached), builds `libxray.a`, uploads it as an artifact,
and attaches it to the release. The weekly run also opens an issue when
`xtls/xray-core` publishes a newer tag than the one vendored in
`native/libxray/go.mod`.

Pin bumps live in `env:` at the top of that workflow
(`OHOS_GO_VERSION`, `OHOS_SDK_VERSION`, `XRAY_VERSION`).

> Note: CI only builds the native kernel. The HAP itself must be built locally
> because the HarmonyOS app toolchain ships with DevEco Studio.

## Releasing

Releases carry an installable **unsigned `.hap`** — the convention ClashBox uses,
since a signature is bound to one developer's certificate and device.

**The HAP cannot be built in CI.** A HarmonyOS app needs the HarmonyOS SDK, which
ships with DevEco Studio and is not published to any mirror, so GitHub's Linux
runners cannot produce it. (`libxray.a` *is* built in CI; the release step just
consumes whatever is already in `entry/src/main/cpp/thirdparty/libxray/`.)

```powershell
.\scripts\release.ps1                  # version from AppScope/app.json5
.\scripts\release.ps1 -Version 0.2.0
.\scripts\release.ps1 -SkipBuild -Draft
.\scripts\release.ps1 -SkipBuild -DryRun
```

It builds, stages `dist/v2rayH-<ver>-unsigned.hap` plus a `.sha256`, then creates
the tag and the Release using GitHub's auto-generated notes
(`--generate-notes`). Drop a hand-written `docs/release-notes/<ver>.md` in place
to use `--notes-file` instead.

### Signing

`build-profile.json5` deliberately carries **no** `signingConfigs`: they contain
machine-specific paths and encrypted passwords. A fresh clone therefore builds an
unsigned HAP, which is exactly what gets released.

To install on your own device you still need a signature — let DevEco Studio
generate one (Project Structure → Signing Configs → Automatically generate
signature), then keep that local edit out of the way:

```bash
git update-index --skip-worktree build-profile.json5
```

## OpenHarmony patches

`native/libxray/go.mod` redirects `github.com/xtls/xray-core` and
`gvisor.dev/gvisor` at the vendored copies via `replace`. Three overlays make
them build and run on OpenHarmony — see `native/README.md`.

For the full list of things that went wrong while getting this to build and run
(initial-exec TLS vs musl, the cgo `CC` wrapper, the gVisor `fstat` denial, the
routing loop, the CI packaging traps), see [`docs/build-notes.md`](docs/build-notes.md).
