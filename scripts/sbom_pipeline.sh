#!/bin/bash

set -e  # Exit on error

echo "🔹 Starting Payments Pipeline SBOM process..."

# Ensure security-audit directory exists
[ -d "security-audit" ] || mkdir security-audit
echo "📂 security-audit folder is ready"

# Define unique SBOM file name
RUN_COUNT=$(ls security-audit/payments-pipeline-run-* 2>/dev/null | wc -l)
RUN_ID=$((RUN_COUNT + 1))
SBOM_FILE="security-audit/payments-pipeline-run-$RUN_ID.json"

# Install Syft if missing
if ! command -v syft &> /dev/null; then
    echo "🛠️ Installing required components..."
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh
fi

# Install jq if missing
if ! command -v jq &> /dev/null; then
    echo "🛠️ Installing jq..."
    sudo apt update && sudo apt install -y jq
fi

# Verify installations
if ! command -v syft &> /dev/null || ! command -v jq &> /dev/null; then
    echo "❌ Installation failed"
    exit 127
fi

# Generate SBOM
echo "🛠️ Generating SBOM..."
syft . -o cyclonedx-json > "$SBOM_FILE"
echo "✅ SBOM saved as $SBOM_FILE"

# Validate SBOM file
if [ ! -s "$SBOM_FILE" ]; then
    echo "❌ SBOM file is empt
