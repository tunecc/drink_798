#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
android_output_dir="$project_root/build/app/outputs/flutter-apk"
ios_output_dir="$project_root/build/ios"
ios_ipa_output_dir="$project_root/build/ios/unsigned-ipa"
releases_dir="$project_root/releases"

usage() {
  echo "Usage: $0 [all|android|ios]" >&2
}

# Read version name from pubspec.yaml (e.g. 1.0.3+3 -> 1.0.3)
app_version() {
  local version
  version="$(
    awk '
      /^version:[[:space:]]*/ {
        v = $2
        sub(/\+.*/, "", v)
        print v
        exit
      }
    ' "$project_root/pubspec.yaml"
  )"

  if [[ -z "$version" ]]; then
    echo "Failed to read version from pubspec.yaml" >&2
    return 1
  fi

  printf '%s\n' "$version"
}

copy_to_releases() {
  local src="$1"
  local dest_name="$2"
  local dest

  if [[ ! -f "$src" ]]; then
    echo "Skip releases copy: source not found: $src" >&2
    return 1
  fi

  mkdir -p "$releases_dir"
  dest="$releases_dir/$dest_name"
  cp -f "$src" "$dest"
  echo "  $(du -h "$dest" | awk '{print $1}')  $dest"
}

publish_android_release_artifact() {
  local version src dest_name
  version="$(app_version)"
  src="$android_output_dir/app-arm64-v8a-release.apk"
  dest_name="drink_798_v${version}_android_arm64-v8a.apk"

  echo
  echo "Releases Android artifact:"
  copy_to_releases "$src" "$dest_name"
}

publish_ios_release_artifact() {
  local version src dest_name
  version="$(app_version)"
  src="$ios_ipa_output_dir/Runner-unsigned.ipa"
  dest_name="drink_798_v${version}_ios_unsigned.ipa"

  echo
  echo "Releases iOS artifact:"
  copy_to_releases "$src" "$dest_name"
}

check_ios_engine_cache() {
  local flutter_bin flutter_sdk_root engine_cache_root engine_framework

  flutter_bin="$(command -v flutter)"
  flutter_sdk_root="$(cd "$(dirname "$flutter_bin")/.." && pwd -P)"
  engine_cache_root="$flutter_sdk_root/bin/cache/artifacts/engine"
  engine_framework="$engine_cache_root/ios-release/Flutter.xcframework/ios-arm64/Flutter.framework/Flutter"

  if [[ -f "$engine_framework" ]] && xattr -p com.apple.quarantine "$engine_framework" >/dev/null 2>&1; then
    echo
    echo "iOS build blocked: Flutter iOS engine cache has com.apple.quarantine set."
    echo "  $engine_framework"
    echo
    echo "Clear it once and rerun:"
    echo "  xattr -dr com.apple.quarantine \"$engine_cache_root\""
    return 1
  fi
}

print_android_artifacts() {
  echo
  echo "Android release APKs:"

  for apk in \
    "$android_output_dir/app-arm64-v8a-release.apk" \
    "$android_output_dir/app-armeabi-v7a-release.apk" \
    "$android_output_dir/app-x86_64-release.apk"
  do
    if [[ -f "$apk" ]]; then
      size="$(du -h "$apk" | awk '{print $1}')"
      echo "  $size  $apk"
    fi
  done

  echo
  echo "Recommended for most physical devices: app-arm64-v8a-release.apk"
}

print_ios_artifacts() {
  echo
  echo "iOS unsigned app bundles:"

  local found=0
  while IFS= read -r app; do
    found=1
    size="$(du -sh "$app" | awk '{print $1}')"
    echo "  $size  $app"
  done < <(find "$ios_output_dir" -type d -name "Runner.app" 2>/dev/null | sort)

  if [[ "$found" -eq 0 ]]; then
    echo "  No Runner.app found under $ios_output_dir"
  fi

  echo
  echo "iOS unsigned IPA:"

  if [[ -f "$ios_ipa_output_dir/Runner-unsigned.ipa" ]]; then
    size="$(du -h "$ios_ipa_output_dir/Runner-unsigned.ipa" | awk '{print $1}')"
    echo "  $size  $ios_ipa_output_dir/Runner-unsigned.ipa"
  else
    echo "  No unsigned IPA found under $ios_ipa_output_dir"
  fi

  echo
  echo "Unsigned iOS IPA is not installable until it is signed."
}

package_unsigned_ipa() {
  local app_path temp_dir payload_dir ipa_path

  app_path="$(find "$ios_output_dir" -type d -name "Runner.app" 2>/dev/null | sort | tail -n 1)"

  if [[ -z "$app_path" ]]; then
    echo "Runner.app not found under $ios_output_dir" >&2
    return 1
  fi

  mkdir -p "$ios_ipa_output_dir"
  ipa_path="$ios_ipa_output_dir/Runner-unsigned.ipa"
  temp_dir="$(mktemp -d /tmp/drink_798_unsigned_ipa.XXXXXX)"
  payload_dir="$temp_dir/Payload"

  mkdir -p "$payload_dir"
  cp -R "$app_path" "$payload_dir/"

  (
    cd "$temp_dir"
    ditto -c -k --keepParent Payload "$ipa_path"
  )

  rm -rf "$temp_dir"
}

build_android() {
  flutter build apk --release --split-per-abi
  print_android_artifacts
  publish_android_release_artifact
}

build_ios() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo
    echo "Skipping iOS build: macOS is required."
    return 0
  fi

  if ! command -v xcodebuild >/dev/null 2>&1; then
    echo
    echo "Skipping iOS build: Xcode command line tools are not available."
    return 0
  fi

  check_ios_engine_cache
  COPYFILE_DISABLE=1 flutter build ios --release --no-codesign
  package_unsigned_ipa
  print_ios_artifacts
  publish_ios_release_artifact
}

cd "$project_root"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter command not found in PATH" >&2
  exit 1
fi

target="${1:-all}"

if [[ "$#" -gt 1 ]]; then
  usage
  exit 1
fi

case "$target" in
  all)
    build_android
    build_ios
    ;;
  android)
    build_android
    ;;
  ios)
    build_ios
    ;;
  *)
    usage
    exit 1
    ;;
esac
