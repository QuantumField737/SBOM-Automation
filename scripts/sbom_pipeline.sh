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

# Install CycloneDX CLI if missing
if ! command -v cyclonedx-cli &> /dev/null; then
    echo "🛠️ Installing CycloneDX CLI..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -sSfL https://github.com/CycloneDX/cyclonedx-cli/releases/latest/download/cyclonedx-linux-x64 -o /usr/local/bin/cyclonedx-cli
        chmod +x /usr/local/bin/cyclonedx-cli
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install cyclonedx/cyclonedx-cli/cyclonedx-cli
    else
        echo "❌ Error: Unsupported OS"
        exit 1
    fi
fi

# Verify installation
if ! command -v cyclonedx-cli &> /dev/null; then
    echo "❌ Error: CycloneDX installation failed"
    exit 127
fi

# Detect project type and generate SBOM
echo "🛠️ Generating SBOM..."
if [ -f "package.json" ]; then
    cyclonedx-cli nodejs --output "$SBOM_FILE"
elif [ -f "pom.xml" ]; then
    cyclonedx-cli maven --output "$SBOM_FILE"
elif [ -f "requirements.txt" ]; then
    cyclonedx-cli python --output "$SBOM_FILE"
elif [ -d ".git" ]; then
    cyclonedx-cli git --output "$SBOM_FILE"
else
    echo "❌ Error: Could not detect project type for SBOM generation"
    exit 1
fi
echo "✅ SBOM saved at $SBOM_FILE"

# Define project name
PROJECT_NAME="SBOM_Project"

# Upload SBOM to Dependency-Track
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
