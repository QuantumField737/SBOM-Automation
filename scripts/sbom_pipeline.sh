#!/bin/bash

set -e  # Exit on error

echo "🔹 Starting Payments Pipeline SBOM process..."

# Ensure security-audit directory exists
[ -d "security-audit" ] || mkdir security-audit
echo "📂 security-audit folder is ready"

# Define unique SBOM file name
RUN_COUNT=$(ls security-audit/payments-pipeline-run-* 2>/dev/null | wc -l)
RUN_ID=$((RUN_COUNT + 1))
SBOM_FILE="security-audit/payments-pipeline-run-$RUN_ID.json"

# Install CycloneDX CLI if missing
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
echo "✅ SBOM saved as $SBOM_FILE"

# Validate SBOM file
if [ ! -s "$SBOM_FILE" ]; then
    echo "❌ SBOM file is empty or missing"
    exit 23
fi

# **Check SBOM size before upload**
FILE_SIZE=$(stat -c%s "$SBOM_FILE")
echo "📏 SBOM file size: $FILE_SIZE bytes"

if [[ "$FILE_SIZE" -lt 100 ]]; then
    echo "❌ Error: SBOM file is too small, possibly corrupted."
    exit 23
fi

# **Use cURL with increased buffer size**
echo "📤 Uploading SBOM..."
UPLOAD_STATUS=$(curl --max-filesize 500M --limit-rate 500K -s -o /dev/null -w "%{http_code}" -X POST "$DEP_TRACK_URL/api/v1/bom" \
    -H "X-Api-Key: $DEP_TRACK_API_KEY" \
    -F "autoCreate=true" \
    -F "projectName=PaymentsPipeline" \
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
REPORT_FILE="security-audit/payments-pipeline-report-$RUN_ID.json"
echo "📥 Downloading report..."
curl -s "$DEP_TRACK_URL/api/v1/metrics/project/PaymentsPipeline/current" \
    -H "X-Api-Key: $DEP_TRACK_API_KEY" > "$REPORT_FILE"

echo "✅ Report saved as $REPORT_FILE"
echo "🎉 Payments Pipeline Process Completed!"

