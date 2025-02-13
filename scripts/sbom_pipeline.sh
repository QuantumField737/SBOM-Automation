#!/bin/bash

set -e  # Exit on any error

echo "🔹 Starting SBOM pipeline..."

# Create security-audit directory if missing
mkdir -p security-audit
echo "📂 Created security-audit folder"

# Define SBOM file
SBOM_FILE="security-audit/sbom.json"

# Generate SBOM using Syft (or modify for other tools)
echo "🛠️ Generating SBOM..."
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh
syft . -o cyclonedx-json > "$SBOM_FILE"
echo "✅ SBOM saved at $SBOM_FILE"

# Extract project name from file
PROJECT_NAME="SBOM_Project"

# Upload SBOM to Dependency-Track
echo "📤 Uploading SBOM..."
curl -s -X POST "$DEP_TRACK_URL/api/v1/bom" \
    -H "X-Api-Key: $DEP_TRACK_API_KEY" \
    -F "autoCreate=true" \
    -F "projectName=$PROJECT_NAME" \
    -F "projectVersion=1.0" \
    -F "bom=@$SBOM_FILE"

echo "⏳ Waiting for Dependency-Track processing..."
sleep 90  # Wait 90 seconds

# Get Project UUID
echo "📡 Fetching project details..."
PROJECT_UUID=$(curl -s "$DEP_TRACK_URL/api/v1/project?name=$PROJECT_NAME" \
    -H "X-Api-Key: $DEP_TRACK_API_KEY" | jq -r '.[0].uuid')

if [[ "$PROJECT_UUID" == "null" ]]; then
    echo "❌ Error: Could not retrieve project UUID"
    exit 1
fi

# Download Full Analysis Report
REPORT_FILE="security-audit/deptrack-report.json"
echo "📥 Downloading report..."
curl -s "$DEP_TRACK_URL/api/v1/metrics/project/$PROJECT_UUID/current" \
    -H "X-Api-Key: $DEP_TRACK_API_KEY" > "$REPORT_FILE"

echo "✅ Report saved at $REPORT_FILE"
echo "🎉 SBOM pipeline completed!"

