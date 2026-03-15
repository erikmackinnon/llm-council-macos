#!/usr/bin/env bash
set -euo pipefail

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

ROOT="$(repo_root)"
ENV_FILE="${ROOT}/.codex/apple.env"

abspath_from_root() {
  local p="$1"
  if [[ "$p" = /* ]]; then
    printf '%s\n' "$p"
  else
    printf '%s\n' "${ROOT}/${p}"
  fi
}

load_apple_env() {
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "Missing ${ENV_FILE}. Run ./bin/bootstrap first."
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$ENV_FILE"

  : "${DERIVED_DATA_PATH:=.build/DerivedData}"
  : "${RESULT_BUNDLE_DIR:=.artifacts/xcresults}"
  : "${SCREENSHOT_DIR:=.artifacts/screenshots}"
  : "${VIDEO_DIR:=.artifacts/videos}"
  : "${XCODE_CONFIGURATION:=Debug}"
  : "${CODE_SIGNING_ALLOWED:=NO}"
  : "${CODE_SIGNING_REQUIRED:=NO}"
  : "${CODE_SIGN_IDENTITY:=-}"

  DERIVED_DATA_PATH="$(abspath_from_root "$DERIVED_DATA_PATH")"
  RESULT_BUNDLE_DIR="$(abspath_from_root "$RESULT_BUNDLE_DIR")"
  SCREENSHOT_DIR="$(abspath_from_root "$SCREENSHOT_DIR")"
  VIDEO_DIR="$(abspath_from_root "$VIDEO_DIR")"

  mkdir -p "$DERIVED_DATA_PATH" "$RESULT_BUNDLE_DIR" "$SCREENSHOT_DIR" "$VIDEO_DIR"

  if [[ -n "${XCODE_WORKSPACE:-}" ]]; then
    CONTAINER_ARGS=(-workspace "$XCODE_WORKSPACE")
  elif [[ -n "${XCODE_PROJECT:-}" ]]; then
    CONTAINER_ARGS=(-project "$XCODE_PROJECT")
  else
    echo "Neither XCODE_WORKSPACE nor XCODE_PROJECT is set in ${ENV_FILE}"
    exit 1
  fi
}

timestamp() {
  date +"%Y%m%d-%H%M%S"
}

result_bundle_path() {
  local label="$1"
  printf '%s/%s-%s.xcresult\n' "$RESULT_BUNDLE_DIR" "$label" "$(timestamp)"
}

latest_xcresult() {
  find "$RESULT_BUNDLE_DIR" -maxdepth 1 -name "*.xcresult" -type d 2>/dev/null | sort | tail -n 1
}

xcbeautify_pipe() {
  if command -v xcbeautify >/dev/null 2>&1; then
    xcbeautify
  else
    cat
  fi
}

ios_destination() {
  printf 'platform=iOS Simulator,name=%s,OS=latest\n' "${IOS_SIMULATOR:-iPhone 17 Pro}"
}

macos_destination() {
  printf 'platform=macOS\n'
}

sim_udid_by_name() {
  local name="$1"
  xcrun simctl list devices available -j | jq -r --arg name "$name" '
    .devices
    | to_entries[]
    | .value[]
    | select(.name == $name)
    | .udid
  ' | head -n 1
}

ensure_sim_booted() {
  local name="${IOS_SIMULATOR:-iPhone 17 Pro}"
  local udid
  udid="$(sim_udid_by_name "$name" || true)"

  if [[ -z "$udid" ]]; then
    echo "Could not find simulator named '$name'. Update .codex/apple.env."
    exit 1
  fi

  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
  open -a Simulator >/dev/null 2>&1 || true
}

run_xcodebuild() {
  local label="$1"
  shift
  local result
  result="$(result_bundle_path "$label")"

  set -o pipefail
  xcodebuild \
    "$@" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -resultBundlePath "$result" \
    CODE_SIGNING_ALLOWED="$CODE_SIGNING_ALLOWED" \
    CODE_SIGNING_REQUIRED="$CODE_SIGNING_REQUIRED" \
    CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" 2>&1 | xcbeautify_pipe
  echo
  echo "Result bundle: $result"
}
