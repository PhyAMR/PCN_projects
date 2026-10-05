#!/usr/bin/env bash
# ---------------------------------------------------------------------
# Page-budget check for the combined PoCN report.
#
#   Body limit: 10 pages (front page, references and appendices excluded)
#     Part I  - Project 45, chapters 1-4 ... 6 pages
#     Part II - Project 24, chapters 5-8 ... 4 pages
#
# Usage:
#   cd reports/report && quarto render
#   bash reports/check_pages.sh
# ---------------------------------------------------------------------
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PDF="${HERE}/main.pdf"

if [[ ! -f "${PDF}" ]]; then
  echo "main.pdf not found. Run: cd ${HERE}/report && quarto render" >&2
  exit 1
fi

if command -v pdfinfo >/dev/null 2>&1; then
  TOTAL=$(pdfinfo "${PDF}" | awk '/^Pages:/ {print $2}')
else
  TOTAL=$(python3 - "$PDF" <<'PY'
import re, sys
data = open(sys.argv[1], 'rb').read()
print(max(len(re.findall(rb'/Type\s*/Page[^s]', data)), 0))
PY
)
fi

echo "main.pdf total pages: ${TOTAL}"
echo
echo "Budget reminder (body only, front page / references / appendices excluded):"
echo "  ch.1 EvoSim simulations and cleaned trajectory data ..... 1"
echo "  ch.2 Reconstructed networks and temporal statistics ..... 2"
echo "  ch.3 Network structure and eco-evolutionary dynamics .... 2"
echo "  ch.4 Scenario comparison and interpretation ............. 1"
echo "  ch.5 Entanglement percolation: model and strategies ..... 1"
echo "  ch.6 Generating-function theory of q-swap percolation ... 1"
echo "  ch.7 Erdos-Renyi and scale-free networks ................ 1"
echo "  ch.8 Small-world networks and discussion ................ 1"
echo "  ------------------------------------------------------------"
echo "  BODY TOTAL ............................................. 10"
echo
echo "Open the PDF and confirm chapter 5 starts on body page 7."
echo "If a chapter overflows, move material into sections/appendix.qmd."
echo "Do NOT reduce margins or font size."
