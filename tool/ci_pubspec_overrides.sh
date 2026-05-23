#!/usr/bin/env bash
# Writes pubspec_overrides.yaml so CI resolves sibling packages from the
# monorepo instead of pub.dev (overrides are gitignored for local dev).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pkg_dir="${1:?usage: ci_pubspec_overrides.sh <package-dir-relative-to-root>}"

override_file="${root}/${pkg_dir}/pubspec_overrides.yaml"

case "${pkg_dir}" in
  packages/openui)
    cat >"${override_file}" <<'EOF'
dependency_overrides:
  openui_core:
    path: ../openui_core
EOF
    ;;
  packages/openui_components)
    cat >"${override_file}" <<'EOF'
dependency_overrides:
  openui:
    path: ../openui
  openui_core:
    path: ../openui_core
EOF
    ;;
  packages/openui_mcp)
    cat >"${override_file}" <<'EOF'
dependency_overrides:
  openui_core:
    path: ../openui_core
EOF
    ;;
  apps/openui_flutter_example)
    cat >"${override_file}" <<'EOF'
dependency_overrides:
  openui:
    path: ../../packages/openui
  openui_components:
    path: ../../packages/openui_components
  openui_core:
    path: ../../packages/openui_core
EOF
    ;;
  *)
    echo "No pubspec overrides needed for ${pkg_dir}" >&2
    exit 0
    ;;
esac

echo "Wrote ${override_file}"
