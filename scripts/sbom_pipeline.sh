#!/bin/bash

set -e  # Exit on error

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

# Automatically detect if an SBOM tool is installed
if ! command -v sbom_generator &> /dev/null; then
    echo "🛠️ Installing necessary components..."
    
    # Check OS and install the required tool (replace with real commands)
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt update && sudo apt install -y sbom_generator_package
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install sbom_generator_package
    else
        echo "❌ Error: Unsupported OS"
        exit 1
    fi
fi

# Verify installation
if ! command -v sbom_generator &> /dev/null; then
    echo "❌ Error: Required component installation failed"
    exit 127
fi

# Generate SBOM
echo "🛠️ Generating SBOM..."
sbom_generator generate --output "$SBOM_FILE"  # Replace with actual command
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
