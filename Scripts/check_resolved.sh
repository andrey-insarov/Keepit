#!/bin/sh
# Refuse to build if SwiftPM resolves dependencies to anything other than the committed Package.resolved.
# Pins are compared semantically (identity / location / revision / version), so a newer SwiftPM rewriting
# the file's schema version is not drift — a different Sparkle revision is.
# Usage: Scripts/check_resolved.sh   (from the package root; needs swift and jq)
set -eu

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cp Package.resolved "$tmp/committed.json"
# A binary-artifact download that fails half-way (GitHub 5xx) leaves a file behind, and SwiftPM's own
# retry then stops with "... already exists in file system". On CI, drop the partial download and try
# again (3 attempts); the archive is still verified against the checksum in Sparkle's manifest.
attempt=1
until swift package resolve >/dev/null; do
  if [ -z "${CI:-}" ] || [ "$attempt" -ge 3 ]; then
    exit 1
  fi
  echo "swift package resolve failed (attempt $attempt of 3); clearing the artifact cache and retrying" >&2
  rm -rf "$HOME/Library/Caches/org.swift.swiftpm/artifacts" .build/artifacts
  attempt=$((attempt + 1))
  sleep $((attempt * 15))
done

pins='[.pins[] | {identity, location, revision: .state.revision, version: .state.version}]'
jq -S "$pins" "$tmp/committed.json" > "$tmp/committed.pins"
jq -S "$pins" Package.resolved > "$tmp/resolved.pins"

if ! diff -u "$tmp/committed.pins" "$tmp/resolved.pins"; then
  echo "error: resolved dependencies differ from the committed Package.resolved." >&2
  echo "       Review the change, then run 'swift package resolve' and commit Package.resolved." >&2
  exit 1
fi
echo "Dependencies match Package.resolved:"
jq -r '.pins[] | "  \(.identity) \(.state.version) \(.state.revision)"' Package.resolved
