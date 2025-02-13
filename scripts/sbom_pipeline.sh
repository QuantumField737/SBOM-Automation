#!/bin/bash

set -e  # Exit on any error

echo "🔹 Starting SBOM pipeline..."

# Ensure security-audit directory exists
if [ ! -d "security-audit" ]; then
    mkdir security-audit
    echo "📂 Created security-audit folder"
else
    echo "📂 security-audit folder already exists"
fi

# Define SBOM file
SBOM_FILE="security-audit/sbom.json"

# Check if the required tool is installed, otherwise install it
if ! command -v sbom_tool &> /dev/null; then
    echo "🛠️ Installing required components..."
    install_sbom_tool  # Placeholder for actual installation command
fi

# Verify installation
if ! command -v sbom_tool &> /dev/null; then
    echo "❌ Error: Required component installation failed"
    exit 127
fi

# Generate SBOM
echo "🛠️ Generating SBOM..."
sbom_tool generate --output "$SBOM_FILE"  # Placeholder for actual SBOM generation command
echo "✅ SBOM saved at $SBOM_FILE"

# Define project name (generic)
PROJECT_NAME="SBOM_Project"

# Upload SBOM
echo "📤 Uploading SBOM..."
curl -s -X POST "$DEP_TRACK_URL/api/v1/bom" \
    -H "X-Api-Key: $DEP_TRACK_API_KEY" \
    -F "autoCreate=true" \
    -F "projectName=$PROJECT_NAME" \
    -F "projectVersion=1.0" \
    -F "bom=@$SBOM_FILE"

echo "⏳ Waiting for processing..."
sleep 90  # Wait 90 seconds

# Retrieve Project UUID
echo "📡 Fetching project details..."
PROJECT_UUID=$(curl -s "$DEP_TRACK_URL/api/v1/project?name=$PROJECT_NAME" \
    -H "X-Api-Key: $DEP_TRACK_API_KEY" | jq -r '.[0].uuid')

if [[ "$PROJECT_UUID" == "null" ]]; then
    echo "❌ Error: Could not retrieve project UUID"
    exit 1
fi

# Download Full Report
REPORT_FILE="security-audit/report.json"
echo "📥 Downloading report..."
curl -s "$DEP_TRACK_URL/api/v1/metrics/project/$PROJECT_UUID/current" \
    -H "X-Api-Key: $DEP_TRACK_API_KEY" > "$REPORT_FILE"

echo "✅ Report saved at $REPORT_FILE"
echo "🎉 Process completed!"
