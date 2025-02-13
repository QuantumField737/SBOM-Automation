#!/bin/bash

set -e  # Exit on error

echo "🔹 Starting SBOM generation..."

# Check if security-audit folder exists; if not, create it
if [ ! -d "security-audit" ]; then
    mkdir security-audit
    echo "📂 Created security-audit folder"
else
    echo "📂 security-audit folder already exists"
fi

# Define SBOM file name (ensures unique names)
RUN_ID=$(date +%s)
SBOM_FILE="security-audit/sbom-run-$RUN_ID.json"

# Install Syft if missing
if ! command -v syft &> /dev/null; then
    echo "🛠️ Installing SBOM generator..."
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh
fi

# Verify installation
if ! command -v syft &> /dev/null; then
    echo "❌ Syft installation failed"
    exit 127
fi

# Generate SBOM
echo "🛠️ Generating SBOM..."
syft . -o cyclonedx-json > "$SBOM_FILE"

# Check SBOM file
if [ ! -s "$SBOM_FILE" ]; then
    echo "❌ SBOM file is empty or missing"
    exit 23
fi

echo "✅ SBOM successfully generated and saved at: $SBOM_FILE"
