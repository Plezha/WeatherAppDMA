#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
swiftlint_version="0.65.1"
archive_checksum="c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0"
tool_root="$project_dir/.tools/swiftlint"
tool_dir="$tool_root/$swiftlint_version"
swiftlint_bin="$tool_dir/swiftlint"

if [[ "$(uname -s)" != "Darwin" ]]; then
    printf 'This script uses the macOS SwiftLint binary. Run it on a Mac with Xcode installed.\n' >&2
    exit 1
fi

if [[ ! -x "$swiftlint_bin" ]]; then
    mkdir -p "$tool_root"
    download_dir="$(mktemp -d "$tool_root/download.XXXXXX")"
    trap 'rm -rf "$download_dir"' EXIT

    printf 'Downloading SwiftLint %s from the official release...\n' "$swiftlint_version" >&2
    curl --fail --silent --show-error --location --retry 2 \
        "https://github.com/realm/SwiftLint/releases/download/$swiftlint_version/portable_swiftlint.zip" \
        --output "$download_dir/swiftlint.zip"
    printf '%s  %s\n' "$archive_checksum" "$download_dir/swiftlint.zip" | shasum -a 256 --check - >&2
    unzip -q "$download_dir/swiftlint.zip" -d "$download_dir/extracted"
    mkdir -p "$tool_dir"
    cp "$download_dir/extracted/LICENSE" "$tool_dir/LICENSE"
    chmod +x "$download_dir/extracted/swiftlint"
    mv "$download_dir/extracted/swiftlint" "$swiftlint_bin"
    rm -rf "$download_dir"
    trap - EXIT
fi

if [[ "$("$swiftlint_bin" version)" != "$swiftlint_version" ]]; then
    printf 'Unexpected SwiftLint version. Remove %s and rerun this script.\n' "$tool_dir" >&2
    exit 1
fi

cd "$project_dir"
# Discover the root config so per-directory test configs are also applied.
exec "$swiftlint_bin" lint --cache-path "$tool_root/cache" "$@"
