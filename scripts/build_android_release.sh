#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="$project_root/build/app/outputs/flutter-apk"

cd "$project_root"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter command not found in PATH" >&2
  exit 1
fi

flutter build apk --release --split-per-abi "$@"

echo
echo "Android release APKs:"

for apk in \
  "$output_dir/app-arm64-v8a-release.apk" \
  "$output_dir/app-armeabi-v7a-release.apk" \
  "$output_dir/app-x86_64-release.apk"
do
  if [[ -f "$apk" ]]; then
    size="$(du -h "$apk" | awk '{print $1}')"
    echo "  $size  $apk"
  fi
done

echo
echo "Recommended for most physical devices: app-arm64-v8a-release.apk"
