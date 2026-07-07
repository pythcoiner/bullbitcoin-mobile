# SP (Silent Payments) Development

## 1. Toolchains

| Tool | Version | Install |
|---|---|---|
| Rust | stable (pinned by `rust-toolchain.toml`) | `rustup toolchain install stable` |
| Flutter | 3.38.5 via fvm (pinned in `.fvmrc`) | `fvm install` in repo root |
| Dart | bundled with Flutter (SDK ≥ 3.10.0) | comes with Flutter |
| Java | ≥ 17 (Java 21 works) | system package manager or [SDKMAN](https://sdkman.io) |
| Android SDK | platform 34+ | Android Studio SDK Manager |
| Android NDK | any version under `$ANDROID_HOME/ndk/` | Android Studio SDK Manager |
| `flutter_rust_bridge_codegen` | exactly `2.11.1` | `dart pub global activate flutter_rust_bridge_codegen 2.11.1` |

Run `bash scripts/check-deps.sh` to verify your full environment before starting.

## 2. Environment Variables

| Variable | Required? | Default / fallback | Used by |
|---|---|---|---|
| `ANDROID_HOME` | Yes | none — must be set, must point to a real dir | Android Gradle build, `check-deps.sh`, NDK lookup |
| `ANDROID_NDK_HOME` | No | derived from `$ANDROID_HOME/ndk/<latest>` | cargokit Rust cross-compile to Android |
| `JAVA_HOME` | No | derived from `java` on PATH | Gradle (only when not on PATH) |
| `PATH` | Yes — must contain `fvm` (or `flutter`) and `~/.cargo/bin` | system-default + shell rc | every Flutter/cargo command |
| `SP_NETWORK_TESTS` | No | unset → network-gated tests skipped | `cargo test` integration tests in `rust/tests/scan_regtest.rs`, `send_regtest.rs`, and the `regtest_defaults_smoke` doctest |
| `RUST_LOG` | No | `info` | logging level inside the FRB Rust crate during tests and at runtime |
| `CARGO_HOME` | No | `~/.cargo` | rustup-managed; override only for sandboxed CI |
| `RUSTUP_HOME` | No | `~/.rustup` | rustup-managed; override only for sandboxed CI |

**`ANDROID_HOME`** — if unset or pointing to a non-existent directory, Gradle falls back to scanning common locations and usually fails with a confusing `SDK location not found` error during the Android build step. Set it to the directory containing `platforms/`, `platform-tools/`, and `ndk/`. On this dev machine that is `/opt/android-sdk`.

**`ANDROID_NDK_HOME`** — if unset, cargokit derives the NDK path from `$ANDROID_HOME/ndk/<latest installed version>`. If no NDK is installed, the Rust Android cross-compile step fails with a path resolution error. Install at least one NDK version via Android Studio's SDK Manager.

**`JAVA_HOME`** — Gradle can usually locate Java from PATH, but when multiple JDKs are installed the wrong one may be picked. Setting `JAVA_HOME` explicitly avoids version mismatches. Leave unset if only one JDK is installed and `java --version` reports the expected major version.

**`PATH`** — must include the `fvm` binary (or plain `flutter`) and `~/.cargo/bin`. Missing entries surface immediately as `command not found` for `fvm`, `flutter`, `cargo`, or `flutter_rust_bridge_codegen`. The `check-deps.sh` script adds `~/.cargo/bin` and the detected fvm home before running assertions.

**`SP_NETWORK_TESTS`** — when unset or empty, all network-dependent integration tests are compiled but skipped at runtime. Set to `1` to enable regtest tests against the live minta stack. Requires reachability of `minta.pythcoiner.dev` and `github.com`. Never set this in the standard CI lane.

**`RUST_LOG`** — controls log verbosity inside the Rust crate. Defaults to `info`. Set to `debug` or `trace` for verbose output during development or test debugging. Has no effect on the Dart/Flutter layer.

**`CARGO_HOME`** / **`RUSTUP_HOME`** — only override these in CI sandboxes that mount the Rust toolchain from a custom path. On a developer machine, leave both unset; rustup manages them automatically under `~/.cargo` and `~/.rustup`.

## 3. `make sp-*` Targets

| Target | Description |
|---|---|
| `sp-codegen` | Run `flutter_rust_bridge_codegen generate`; regenerates Dart bindings from the Rust API |
| `sp-build-rust` | `cargo build` in `rust/`; prints a skip message if `rust/` does not yet exist |
| `sp-clippy` | `cargo clippy --all-targets -- -D warnings` in `rust/`; skipped if `rust/` absent |
| `sp-test-rust` | `cargo test` in `rust/`; skipped if `rust/` absent |
| `sp-analyze` | `flutter analyze` across the whole project |
| `sp-verify-all` | Runs `sp-build-rust` → `sp-clippy` → `sp-test-rust` → `sp-analyze` → `flutter test` |

`make sp-verify-all` is the single automated verification entry point. CI runs it on every PR that touches `rust/`, `lib/core/sp/`, or `lib/features/sp/`.

## 4. Network-Gated Tests

Regtest integration tests live in `rust/tests/scan_regtest.rs` and `rust/tests/send_regtest.rs`. They are skipped by default and only execute when `SP_NETWORK_TESTS=1`:

```sh
SP_NETWORK_TESTS=1 make sp-test-rust
```

These tests fetch live regtest defaults from `http://minta.pythcoiner.dev/api/status`, mine blocks, and verify end-to-end scan and send flows. Both `minta.pythcoiner.dev` and `github.com` must be reachable. They run on a dedicated CI lane separate from the required SP verify job.

## 5. Reproducible Build (Optional)

`Dockerfile.apk` is the reproducible-build lane used to produce byte-for-byte identical APKs. CI runs it as a separate optional job (not a required PR check). **Developers do not need Docker locally.** `make sp-verify-all` never invokes Docker. To build a reproducible APK locally, run `make apk` (requires Docker).
