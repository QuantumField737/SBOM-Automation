#!/bin/bash

set -e  # Exit on error

echo "🔹 Starting SBOM pipeline..."

# Ensure security-audit directory exists
[ -d "security-audit" ] || mkdir security-audit
echo "📂 security-audit folder is ready"

# Define SBOM file
SBOM_FILE="security-audit/sbom.json"

# Install tool if missing
if ! command -v cyclonedx-cli &> /dev/null; then
    echo "🛠️ Installing required components..."
    curl -sSfL https://github.com/CycloneDX/cyclonedx-cli/releases/latest/download/cyclonedx-linux-x64 -o /usr/local/bin/cyclonedx-cli
    chmod +x /usr/local/bin/cyclonedx-cli
fi

# Verify installation
if ! command -v cyclonedx-cli &> /dev/null; then
    echo "❌ Installation failed"
    exit 127
fi

# Generate SBOM
echo "🛠️ Generating SBOM..."
cyclonedx-cli --output "$SBOM_FILE"
echo "✅ SBOM saved"

# Validate SBOM file
if [ ! -s "$SBOM_FILE" ]; then
    echo "❌ SBOM file is empty or missing"
    exit 23
fi

# Upload SBOM
echo "📤 Uploading SBOM..."
UPLOAD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$DEP_TRACK_URL/api/v1/bom" \
    -H "X-Api-Key: $DEP_TRACK_API_KEY" \
    -F "autoCreate=true" \
    -F "projectName=Project" \
    -F "projectVersion=1.0" \
    -F "bom=@$SBOM_FILE")

if [[ "$UPLOAD_STATUS" -ne 200 && "$UPLOAD_STATUS" -ne 201 ]]; then
    echo "❌ Upload failed ($UPLOAD_STATUS)"
    exit 1
fi

# Wait for processing
echo "⏳ Processing SBOM..."
sleep 60

# Fetch Report
REPORT_FILE="security-audit/report.json"
echo "📥 Downloading report..."
curl -s "$DEP_TRACK_URL/api/v1/metrics/project/Project/current" \
    -H "X-Api-Key: $DEP_TRACK_API_KEY" > "$REPORT_FILE"

echo "✅ Report saved"
echo "🎉 Process completed!"
