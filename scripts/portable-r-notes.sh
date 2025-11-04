#!/usr/bin/env bash
set -euo pipefail
echo "Portable R bundling is primarily targeted at Windows."
echo "On macOS/Linux, the recommended approach is to rely on a system R (Homebrew/apt) or ship instructions."
echo "If you still want to bundle R, place the Rscript binary at:"
echo "  r-portable/R-Portable/App/R-Portable/bin/Rscript"
echo "and ensure it is executable (chmod +x)."
