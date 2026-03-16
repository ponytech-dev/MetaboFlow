#!/bin/bash
##############################################################################
##  MetaboFlow E2E Test Runner
##  Builds Docker image, runs full pipeline on faahKO data, saves results
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/tests/e2e/results"
DATA_DIR="$SCRIPT_DIR/data/faahKO_raw"

echo "========== MetaboFlow E2E Test Runner =========="
echo "Project root: $PROJECT_ROOT"
echo "Data dir:     $DATA_DIR"
echo "Results dir:  $RESULTS_DIR"
echo ""

# Check data exists
if [ ! -d "$DATA_DIR/WT" ] || [ ! -d "$DATA_DIR/KO" ]; then
    echo "ERROR: faahKO data not found at $DATA_DIR"
    echo "Run download first: see tests/e2e/README"
    exit 1
fi

echo "WT files: $(ls "$DATA_DIR/WT/"*.CDF 2>/dev/null | wc -l | tr -d ' ')"
echo "KO files: $(ls "$DATA_DIR/KO/"*.CDF 2>/dev/null | wc -l | tr -d ' ')"
echo ""

# Clean previous results
rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

# Build Docker image
echo "===== Building Docker image ====="
docker build \
    -t metaboflow-e2e:latest \
    -f "$SCRIPT_DIR/Dockerfile.e2e" \
    "$PROJECT_ROOT"

echo ""
echo "===== Running E2E Pipeline ====="
docker run --rm \
    -v "$DATA_DIR:/data/faahKO_raw:ro" \
    -v "$RESULTS_DIR:/results" \
    metaboflow-e2e:latest

echo ""
echo "===== Results ====="
ls -lh "$RESULTS_DIR/"

echo ""
echo "===== E2E Report ====="
cat "$RESULTS_DIR/00_E2E_REPORT.txt"
