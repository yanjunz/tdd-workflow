#!/usr/bin/env bash
# Ensure skills/SKILL.md metadata.version matches package.json version.
#
# Runs as part of `npm test` and is also wired into `prepublishOnly`
# so publishing a mismatched version fails fast.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PKG="$ROOT/package.json"
SKILL="$ROOT/skills/SKILL.md"

if [ ! -f "$PKG" ] || [ ! -f "$SKILL" ]; then
  echo "version-sync: missing $PKG or $SKILL" >&2
  exit 2
fi

# Extract "version": "X.Y.Z" from package.json (no jq dependency)
PKG_VER=$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PKG" | head -1)

# Extract the YAML front-matter metadata.version line in SKILL.md
# (format: `  version: "X.Y.Z"` under `metadata:`)
SKILL_VER=$(sed -n 's/^[[:space:]]*version:[[:space:]]*"\([^"]*\)".*/\1/p' "$SKILL" | head -1)

if [ -z "$PKG_VER" ]; then
  echo "version-sync: cannot read version from $PKG" >&2
  exit 2
fi
if [ -z "$SKILL_VER" ]; then
  echo "version-sync: cannot read metadata.version from $SKILL" >&2
  exit 2
fi

if [ "$PKG_VER" = "$SKILL_VER" ]; then
  printf '\033[32m✓ version sync ok (%s)\033[0m\n' "$PKG_VER"
  exit 0
fi

printf '\033[31m✗ version mismatch\033[0m\n'
printf '    package.json         = %s\n' "$PKG_VER"
printf '    skills/SKILL.md      = %s\n' "$SKILL_VER"
printf '  Bump skills/SKILL.md metadata.version to match, then re-run.\n'
exit 1
