#!/bin/bash

set -e  # Exit on error

echo "🔹 Starting SBOM generation using CycloneDX..."

# Ensure security-audit folder exists
mkdir -p security-audit
echo "📂 security-audit folder is ready"

# Define SBOM file name (ensures unique names)
RUN_ID=$(date +%s)
SBOM_FILE="security-audit/sbom-run-$RUN_ID.json"

# Install CycloneDX CLI if missing
if ! command -v cyclonedx-cli &> /dev/null; then
    echo "🛠️ Installing CycloneDX CLI..."
    curl -sSfL https://github.com/CycloneDX/cyclonedx-cli/releases/latest/download/cyclonedx-linux-x64 -o /usr/local/bin/cyclonedx-cli
    chmod +x /usr/local/bin/cyclonedx-cli
fi

# Verify installation
if ! command -v cyclonedx-cli &> /dev/null; then
    echo "❌ CycloneDX installation failed"
    exit 127
fi

# Detect project type and generate SBOM
echo "🛠️ Generating SBOM..."
if [ -f "package.json" ]; then
    cyclonedx-cli npm --output "$SBOM_FILE"
elif [ -f "pom.xml" ]; then
    cyclonedx-cli maven --output "$SBOM_FILE"
elif [ -f "requirements.txt" ]; then
    cyclonedx-cli python --output "$SBOM_FILE"
elif [ -f "Cargo.toml" ]; then
    cyclonedx-cli rust --output "$SBOM_FILE"
elif [ -d ".git" ]; then
    cyclonedx-cli git --output "$SBOM_FILE"
else
    echo "❌ No recognized package manager found. SBOM generation failed."
    exit 1
fi

# Check if SBOM was created
if [ ! -s "$SBOM_FILE" ]; then
    echo "❌ SBOM file is empty or missing"
    exit 23
fi

echo "✅ SBOM successfully generated and saved at: $SBOM_FILE"
