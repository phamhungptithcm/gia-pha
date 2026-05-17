#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
npm_config_loglevel=error npx --yes @google/design.md@0.1.1 lint DESIGN.md
