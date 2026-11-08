#!/bin/sh
# Refuse to build if SwiftPM resolves dependencies to anything other than the committed Package.resolved.
# Pins are compared semantically (identity / location / revision / version), so a newer SwiftPM rewriting
# the file's schema version is not drift — a different Sparkle revision is.
# Usage: Scripts/check_resolved.sh   (from the package root; needs swift and jq)
set -eu

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cp Package.resolved "$tmp/committed.json"
# On CI, SwiftPM's shared cache (~/Library/Caches/org.swift.swiftpm/artifacts) fails on the macos-15
# runners with "... Sparkle_for_Swift_Package_Manager_zip already exists in file system", even when it
# is emptied right before (runs 452, 456, 8 Nov). So CI resolves without the shared cache: the binary
# goes straight to .build/artifacts, where the later build steps find it. The archive is still
# verified against the checksum in Sparkle's manifest. A failed attempt is retried (3 in all).
cache_flag=
if [ -n "${CI:-}" ]; then
  cache_flag=--disable-dependency-cache
fi
attempt=1
until swift package resolve $cache_flag >/dev/null; do
  if [ -z "${CI:-}" ] || [ "$attempt" -ge 3 ]; then
    exit 1
  fi
  echo "swift package resolve failed (attempt $attempt of 3); clearing .build/artifacts and retrying" >&2
  rm -rf .build/artifacts
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
