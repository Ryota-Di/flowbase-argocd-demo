#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/prepare-pr.sh" staging
