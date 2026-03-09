#!/usr/bin/env bash
set -euo pipefail

curl -fsS -X POST http://127.0.0.1:39173/refresh >/dev/null 2>&1 || true
