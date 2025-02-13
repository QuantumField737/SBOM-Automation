#!/bin/bash

set -e  # Exit on error

echo "🔹 Starting SBOM generation using CycloneDX..."

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

# Install CycloneDX CLI if missing
if ! command -v cyclonedx &> /dev/null; then
    echo "🛠️ Installing CycloneDX CLI..."
    curl -sSfL https://github.com/CycloneDX/cyclonedx-cli/releases/latest/download/cyclonedx-linux-x64 -o /usr/local/bin/cyclonedx
    chmod +x /usr/local/bin/cyclonedx
fi

# Verify installation
if ! command -v cyclonedx &> /dev/null; then
    echo "❌ CycloneDX installation failed"
    exit 127
fi

# Generate SBOM based on detected project type
echo "🛠️ Generating SBOM..."
if [ -f "package.json" ]; then
    cyclonedx nodejs --output "$SBOM_FILE"
elif [ -f "pom.xml" ]; then
    cyclonedx maven --output "$SBOM_FILE"
elif [ -f "requirements.txt" ]; then
    cyclonedx python --output "$SBOM_FILE"
elif [ -d ".git" ]; then
    cyclonedx git --output "$SBOM_FILE"
else
    echo "❌ No recognized package manager found. SBOM generation failed."
    exit 1
fi

# Check SBOM file
if [ ! -s "$SBOM_FILE" ]; then
    echo "❌ SBOM file is empty or missing"
    exit 23
fi

echo "✅ SBOM successfully generated and saved at: $SBOM_FILE"
