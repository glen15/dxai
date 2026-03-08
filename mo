#!/bin/bash
# Legacy alias: redirects to dxai
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/dxai" "$@"
