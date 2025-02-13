#!/bin/bash

set -e  # Exit on error

echo "📢 Starting SBOM processing pipeline..."

# Ensure security-audit directory exists
mkdir -p security-audit
echo "📂 Created security-audit directory"

# Define SBOM output file
SBOM_FILE="security-audit/sbom.json"

# Select SBOM generation tool (Modify if needed)
TOOL="syft"

echo "🛠️ Generating SBOM using $TOOL..."
if [[ "$TOOL" == "syft" ]]; then
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh
    syft . -o cyclonedx-json > "$SBOM_FILE"
elif [[ "$TOOL" == "trivy" ]]; then
    sudo apt install -y trivy
    trivy sbom --format cyclonedx --output "$SBOM_FILE" .
else
    echo "❌ Error: Unsupported SBOM tool selected"
    exit 1
fi
echo "✅ SBOM generated at $SBOM_FILE"

# Extract project name from SBOM file
PROJECT_NAME=$(basename "$SBOM_FILE" .json)
echo "📛 Project Name: $PROJECT_NAME"

# Upload SBOM to Dependency-Track
echo "📤 Uploading SBOM to Dependency-Track..."
UPLOAD_RESPONSE=$(curl -s -X POST "$DEP_TRACK_URL/api/v1/bom" \
    -H "X-Api-Key: $DEP_TRACK_API_KEY" \
    -F "autoCreate=true" \
    -F "projectName=$PROJECT_NAME" \
    -F "projectVersion=1.0" \
    -F "bom=@$SBOM_FILE")

echo "🔄 Upload Response: $UPLOAD_RESPONSE"

# Wait for processing to complete
echo "⏳ Waiting for Dependency-Track to process the SBOM..."
sleep 120  # Wait 2 minutes

# Retrieve Project UUID
echo "📡 Retrieving project UUID..."
PROJECT_UUID=$(curl -s -X GET "$DEP_TRACK_URL/api/v1/project?name=$PROJECT_NAME" \
    -H "X-Api-Key: $DEP_TRACK_API_KEY" | jq -r '.[0].uuid')

if [[ "$PROJECT_UUID" == "null" ]]; then
    echo "❌ Error: Unable to retrieve project UUID"
    exit 1
fi
echo "✅ Project UUID: $PROJECT_UUID"

# Download Full Analysis Report from Dependency-Track
REPORT_FILE="security-audit/deptrack-full-report.json"

echo "📥 Downloading full analysis report from Dependency-Track..."
curl -s "$DEP_TRACK_URL/api/v1/metrics/project/$PROJECT_UUID/current" \
    -H "X-Api-Key: $DEP_TRACK_API_KEY" > "$REPORT_FILE"

echo "✅ Full report saved at $REPORT_FILE"
echo "🎉 SBOM processing pipeline completed successfully!"
