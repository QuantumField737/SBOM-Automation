#!/bin/bash

set -e  # Exit on error

echo "🔹 Starting SBOM generation..."

# Check if security-audit folder exists; if not, create it
if [ ! -d "security-audit" ]; then
    mkdir -p security-audit
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

# Generate SBOM with Debug Mode
echo "🛠️ Generating SBOM..."
syft . -o cyclonedx-json > "$SBOM_FILE" 2>&1 | tee debug_syft.log

# Check SBOM file existence
if [ ! -f "$SBOM_FILE" ]; then
    echo "❌ SBOM file was not created. Checking for errors..."
    cat debug_syft.log  # Show Syft debug output
    exit 1
fi

# Check SBOM file content
if [ ! -s "$SBOM_FILE" ]; then
    echo "❌ SBOM file is empty. Checking for errors..."
    cat debug_syft.log
    exit 1
fi

echo "✅ SBOM successfully generated and saved at: $SBOM_FILE"
