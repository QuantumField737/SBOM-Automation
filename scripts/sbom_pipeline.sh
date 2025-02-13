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

# Install Syft if missing
if ! command -v syft &> /dev/null; then
    echo "🛠️ Installing required components..."
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh
fi

# Verify installation
if ! command -v syft &> /dev/null; then
    echo "❌ Installation failed"
    exit 127
fi

# Generate SBOM
echo "🛠️ Generating SBOM..."
syft . -o cyclonedx-json > "$SBOM_FILE"
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

# **Upload SBOM**
echo "📤 Uploading SBOM..."
UPLOAD_STATUS=$(curl --retry 3 --connect-timeout 15 -s -o /dev/null -w "%{http_code}" -X POST "$DEP_TRACK_URL/api/v1/bom" \
    -H "X-Api-Key: $DEP_TRACK_API_KEY" \
    -F "autoCreate=true" \
    -F "projectName=PaymentsPipeline" \
    -F "projectVersion=1.0" \
    -F "bom=@$SBOM_FILE")

if [[ "$UPLOAD_STATUS" -ne 200 && "$UPLOAD_STATUS" -ne 201 ]]; then
    echo "❌ Upload failed ($UPLOAD_STATUS)"
    exit 1
fi

# **Retrieve Project UUID**
echo "📡 Fetching project UUID..."
PROJECT_UUID=$(curl -s "$DEP_TRACK_URL/api/v1/project?name=PaymentsPipeline" \
    -H "X-Api-Key: $DEP_TRACK_API_KEY" | jq -r '.[0].uuid')

if [[ -z "$PROJECT_UUID" || "$PROJECT_UUID" == "null" ]]; then
    echo "❌ Error: Could not retrieve project UUID"
    exit 1
fi

# **Poll for Report Availability (every 10s, max 5 minutes)**
MAX_ATTEMPTS=30  # 30 attempts (5 minutes total)
SLEEP_TIME=10     # 10 seconds between each attempt
ATTEMPT=0
REPORT_FILE="security-audit/payments-pipeline-report-$RUN_ID.json"

echo "⏳ Waiting for report to be available (Polling every $SLEEP_TIME seconds)..."

while [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
    REPORT_STATUS=$(curl -s -o "$REPORT_FILE" -w "%{http_code}" "$DEP_TRACK_URL/api/v1/metrics/project/$PROJECT_UUID/current" \
        -H "X-Api-Key: $DEP_TRACK_API_KEY")

    if [[ "$REPORT_STATUS" -eq 200 && -s "$REPORT_FILE" ]]; then
        echo "✅ Report is ready and saved as $REPORT_FILE"
        break
    fi

    ATTEMPT=$((ATTEMPT + 1))
    echo "🔄 Attempt $ATTEMPT/$MAX_ATTEMPTS: Report not ready yet. Retrying in $SLEEP_TIME seconds..."
    sleep $SLEEP_TIME
done

# **Check if report was downloaded successfully**
if [[ ! -s "$REPORT_FILE" ]]; then
    echo "❌ Error: Report not available after $MAX_ATTEMPTS attempts"
    exit 1
fi

echo "🎉 Payments Pipeline Process Completed!"
