#!/bin/bash

set -e  # Exit on error

echo "🔹 Starting Payments Pipeline SBOM process..."

# Ensure security-audit directory exists
mkdir -p security-audit
echo "📂 security-audit folder is ready"

# Define SBOM file name (ensures unique names)
RUN_ID=$(date +%s)
SBOM_FILE="security-audit/payments-pipeline-run-$RUN_ID.json"

# Install required tools if missing
if ! command -v syft &> /dev/null; then
    echo "🛠️ Installing SBOM generator..."
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh
fi

if ! command -v jq &> /dev/null; then
    echo "🛠️ Installing jq..."
    sudo apt update && sudo apt install -y jq
fi

# Verify installations
if ! command -v syft &> /dev/null || ! command -v jq &> /dev/null; then
    echo "❌ Installation failed"
    exit 127
fi

# Generate SBOM
echo "🛠️ Generating SBOM..."
syft . -o cyclonedx-json > "$SBOM_FILE"
echo "✅ SBOM saved as $SBOM_FILE"

# Check SBOM file
if [ ! -s "$SBOM_FILE" ]; then
    echo "❌ SBOM file is empty or missing"
    exit 23
fi

# Upload SBOM
echo "📤 Uploading SBOM..."
UPLOAD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$DEP_TRACK_URL/api/v1/bom" \
    -H "X-Api-Key: $DEP_TRACK_API_KEY" \
    -F "autoCreate=true" \
    -F "projectName=PaymentsPipeline" \
    -F "projectVersion=1.0" \
    -F "bom=@$SBOM_FILE")

if [[ "$UPLOAD_STATUS" -ne 200 && "$UPLOAD_STATUS" -ne 201 ]]; then
    echo "❌ Upload failed ($UPLOAD_STATUS)"
    exit 1
fi

# Get project UUID
echo "📡 Fetching project UUID..."
PROJECT_UUID=$(curl -s "$DEP_TRACK_URL/api/v1/project?name=PaymentsPipeline" \
    -H "X-Api-Key: $DEP_TRACK_API_KEY" | jq -r '.[0].uuid')

if [[ -z "$PROJECT_UUID" || "$PROJECT_UUID" == "null" ]]; then
    echo "❌ Error: Could not retrieve project UUID"
    exit 1
fi

# Poll for report
REPORT_FILE="security-audit/payments-pipeline-report-$RUN_ID.json"
echo "⏳ Waiting for report..."

for i in {1..30}; do
    curl -s -o "$REPORT_FILE" "$DEP_TRACK_URL/api/v1/metrics/project/$PROJECT_UUID/current" \
        -H "X-Api-Key: $DEP_TRACK_API_KEY"

    if [[ -s "$REPORT_FILE" ]]; then
        echo "✅ Report saved as $REPORT_FILE"
        exit 0
    fi

    echo "🔄 Report not ready yet. Retrying in 10 seconds..."
    sleep 10
done

echo "❌ Report not available after multiple attempts"
exit 1
