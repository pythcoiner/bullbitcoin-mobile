#!/usr/bin/env bash
# check-deps.sh: verify dev environment for bb-mobile SP development.
# Exits 0 only when every assertion passes.

FAIL=0

ok()   { printf "OK  %s\n" "$1"; }
fail() { printf "FAIL: %s\n" "$1"; FAIL=$((FAIL + 1)); }

version_gte() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -1)" = "$2" ]
}

# ── Ensure ~/.cargo/bin is in PATH ────────────────────────────────────────────
export PATH="$HOME/.pub-cache/bin:$HOME/.cargo/bin:$PATH"

# ── Bootstrap fvm into PATH if .fvmrc is present ──────────────────────────────
FVM_HOME=""
if   [ -d "$HOME/fvm/bin"  ]; then FVM_HOME="$HOME/fvm"
elif [ -d "$HOME/.fvm/bin" ]; then FVM_HOME="$HOME/.fvm"
fi
if [ -n "$FVM_HOME" ] && [ -f ".fvmrc" ]; then
    export PATH="$FVM_HOME/bin:$PATH"
fi

# ── Pick flutter command ───────────────────────────────────────────────────────
if [ -f ".fvmrc" ] && command -v fvm >/dev/null 2>&1; then
    FLUTTER_CMD="fvm flutter"
    FLUTTER_VIA="fvm"
    FVM_PINNED=$(python3 -c "import json; print(json.load(open('.fvmrc')).get('flutter',''))" 2>/dev/null \
                 || grep -oE '"[0-9]+\.[0-9]+\.[0-9]+"' .fvmrc | tr -d '"' | head -1 || echo "")
else
    FLUTTER_CMD="flutter"
    FLUTTER_VIA="system"
    FVM_PINNED=""
fi

FLUTTER_VERSION=$(${FLUTTER_CMD} --version 2>/dev/null \
    | grep -oE 'Flutter [0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "")

# ── Detect env values for display ─────────────────────────────────────────────
ANDROID_HOME_VAL="${ANDROID_HOME:-}"
ANDROID_NDK_HOME_VAL="${ANDROID_NDK_HOME:-}"
JAVA_HOME_VAL="${JAVA_HOME:-}"

echo "== Detected env =="
printf "%-22s = %s\n" "ANDROID_HOME"               "${ANDROID_HOME_VAL:-(unset)}"
if [ -n "$ANDROID_NDK_HOME_VAL" ]; then
    printf "%-22s = %s\n" "ANDROID_NDK_HOME"        "$ANDROID_NDK_HOME_VAL"
else
    printf "%-22s = %s\n" "ANDROID_NDK_HOME"        "(unset; will check \$ANDROID_HOME/ndk)"
fi
if [ -n "$JAVA_HOME_VAL" ]; then
    printf "%-22s = %s\n" "JAVA_HOME"               "$JAVA_HOME_VAL"
else
    printf "%-22s = %s\n" "JAVA_HOME"               "(unset; using java on PATH)"
fi
printf "%-22s = %s\n" "FVM_HOME"                    "${FVM_HOME:-(not found)}"
printf "%-22s = %s\n" "FLUTTER (via ${FLUTTER_VIA})" "${FLUTTER_VERSION:-(unknown)}"
echo ""
echo "== Assertions =="

# ── 1. rustup ─────────────────────────────────────────────────────────────────
if rustup show >/dev/null 2>&1; then
    ACTIVE=$(rustup show active-toolchain 2>/dev/null | head -1 || echo "unknown")
    ok "rustup: active toolchain = $ACTIVE"
else
    fail "rustup not found or 'rustup show' failed"
fi

# ── 2. Required Rust targets ──────────────────────────────────────────────────
INSTALLED=$(rustup target list --installed 2>/dev/null || echo "")
for t in aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android; do
    if printf '%s\n' "$INSTALLED" | grep -qx "$t"; then
        ok "Rust target: $t"
    else
        fail "Rust target missing: $t  (run: rustup target add $t)"
    fi
done

# iOS targets on macOS
if [ "$(uname)" = "Darwin" ]; then
    for t in aarch64-apple-ios x86_64-apple-ios aarch64-apple-ios-sim; do
        if printf '%s\n' "$INSTALLED" | grep -qx "$t"; then
            ok "Rust target (iOS): $t"
        else
            fail "Rust target missing (iOS): $t  (run: rustup target add $t)"
        fi
    done
fi

# Host triple
HOST_TRIPLE=$(rustup show 2>/dev/null | awk '/Default host:/{print $3}' || echo "")
if [ -n "$HOST_TRIPLE" ]; then
    if printf '%s\n' "$INSTALLED" | grep -qx "$HOST_TRIPLE" || cargo --version >/dev/null 2>&1; then
        ok "Rust host triple: $HOST_TRIPLE"
    else
        fail "Rust host triple not usable: $HOST_TRIPLE"
    fi
fi

# ── 3. Flutter ────────────────────────────────────────────────────────────────
if [ -z "$FLUTTER_VERSION" ]; then
    fail "Flutter not found (tried: ${FLUTTER_CMD} --version)"
else
    if [ -f ".fvmrc" ] && command -v fvm >/dev/null 2>&1 && [ -n "$FVM_PINNED" ]; then
        if [ "$FLUTTER_VERSION" = "$FVM_PINNED" ]; then
            ok "Flutter (fvm): $FLUTTER_VERSION matches .fvmrc pin $FVM_PINNED"
        else
            fail "Flutter (fvm): version $FLUTTER_VERSION != .fvmrc pin $FVM_PINNED"
        fi
    else
        MIN_FLUTTER="3.10.0"
        if version_gte "$FLUTTER_VERSION" "$MIN_FLUTTER"; then
            ok "Flutter: $FLUTTER_VERSION (>= $MIN_FLUTTER)"
        else
            fail "Flutter: $FLUTTER_VERSION < required $MIN_FLUTTER"
        fi
    fi
fi

# ── 4. Dart ───────────────────────────────────────────────────────────────────
DART_VERSION=$(dart --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
MIN_DART="3.10.0"
if [ -n "$DART_VERSION" ]; then
    if version_gte "$DART_VERSION" "$MIN_DART"; then
        ok "Dart: $DART_VERSION (>= $MIN_DART)"
    else
        fail "Dart: $DART_VERSION < required $MIN_DART"
    fi
else
    fail "dart not found on PATH"
fi

# ── 5. Java ───────────────────────────────────────────────────────────────────
JAVA_VER_LINE=$(java -version 2>&1 | head -1 || echo "")
JAVA_VER_QUOTED=$(printf '%s\n' "$JAVA_VER_LINE" | grep -oE '"[^"]+"' | head -1 | tr -d '"')
if [ -n "$JAVA_VER_QUOTED" ]; then
    if printf '%s\n' "$JAVA_VER_QUOTED" | grep -q '^1\.'; then
        JAVA_MAJOR=$(printf '%s\n' "$JAVA_VER_QUOTED" | cut -d. -f2)
    else
        JAVA_MAJOR=$(printf '%s\n' "$JAVA_VER_QUOTED" | cut -d. -f1)
    fi
    if [ "$JAVA_MAJOR" -ge 17 ] 2>/dev/null; then
        ok "Java: major version $JAVA_MAJOR (>= 17)"
    else
        fail "Java: major version $JAVA_MAJOR < 17"
    fi
else
    fail "java -version failed or java not on PATH"
fi

# ── 6. ANDROID_HOME ───────────────────────────────────────────────────────────
if [ -z "$ANDROID_HOME_VAL" ]; then
    fail "ANDROID_HOME is not set"
elif [ ! -d "$ANDROID_HOME_VAL" ]; then
    fail "ANDROID_HOME=$ANDROID_HOME_VAL does not exist"
else
    ok "ANDROID_HOME=$ANDROID_HOME_VAL exists"
fi

# ── 7. Android NDK ───────────────────────────────────────────────────────────
if [ -n "$ANDROID_NDK_HOME_VAL" ]; then
    if [ -d "$ANDROID_NDK_HOME_VAL" ]; then
        ok "ANDROID_NDK_HOME=$ANDROID_NDK_HOME_VAL exists"
    else
        fail "ANDROID_NDK_HOME=$ANDROID_NDK_HOME_VAL does not exist"
    fi
elif [ -n "$ANDROID_HOME_VAL" ] && [ -d "$ANDROID_HOME_VAL/ndk" ]; then
    NDK_COUNT=$(ls -1 "$ANDROID_HOME_VAL/ndk" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$NDK_COUNT" -gt 0 ]; then
        ok "Android NDK: $NDK_COUNT install(s) found in $ANDROID_HOME_VAL/ndk"
    else
        fail "Android NDK: $ANDROID_HOME_VAL/ndk exists but contains no installs"
    fi
else
    fail "Android NDK: ANDROID_NDK_HOME not set and $ANDROID_HOME_VAL/ndk not found"
fi

# ── 8. flutter_rust_bridge_codegen ───────────────────────────────────────────
REQUIRED_FRB="2.11.1"
FRB_VERSION=$(flutter_rust_bridge_codegen --version 2>/dev/null \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
if [ "$FRB_VERSION" = "$REQUIRED_FRB" ]; then
    ok "flutter_rust_bridge_codegen: $FRB_VERSION"
else
    fail "flutter_rust_bridge_codegen: got '${FRB_VERSION:-not found}', need $REQUIRED_FRB"
    echo "     Install with: dart pub global activate flutter_rust_bridge_codegen $REQUIRED_FRB"
    echo "     Or:           cargo install flutter_rust_bridge_codegen --version $REQUIRED_FRB"
fi

# ── 9. Network reach ─────────────────────────────────────────────────────────
if curl -sf --max-time 15 https://github.com/pythcoiner/bwk >/dev/null 2>&1; then
    ok "Network: https://github.com/pythcoiner/bwk reachable"
else
    fail "Network: https://github.com/pythcoiner/bwk unreachable"
fi

if curl -sf --max-time 15 http://minta.pythcoiner.dev/api/status >/dev/null 2>&1; then
    ok "Network: http://minta.pythcoiner.dev/api/status reachable"
else
    fail "Network: http://minta.pythcoiner.dev/api/status unreachable"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "All checks passed."
    exit 0
else
    echo "$FAIL check(s) failed."
    exit 1
fi
