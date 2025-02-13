#!/bin/bash

# Dependency Track API URL (No "/api" needed)
DT_API_URL="http://localhost:8081"
DT_API_KEY="${DT_API_KEY}"  # Retrieved from GitHub Secrets

# Directory where SBOMs are stored
SBOM_DIR="security-audit"

# Find the latest SBOM file in the repo
LATEST_SBOM=$(ls -t "$SBOM_DIR"/*.json 2>/dev/null | head -n 1)

if [ -z "$LATEST_SBOM" ]; then
    echo "No SBOM files found in $SBOM_DIR. Exiting."
    exit 1
fi

# Extract project name from SBOM filename
PROJECT_NAME=$(basename "$LATEST_SBOM" .json)
PROJECT_VERSION="1.0"

echo "Found latest SBOM: $LATEST_SBOM"
echo "Creating project: $PROJECT_NAME"

# Create project in Dependency Track
CREATE_PROJECT_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$DT_API_URL/v1/project" \
  -H "X-Api-Key: $DT_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$PROJECT_NAME\", \"version\": \"$PROJECT_VERSION\"}")

if [ "$CREATE_PROJECT_RESPONSE" -eq 200 ] || [ "$CREATE_PROJECT_RESPONSE" -eq 201 ]; then
    echo "Project '$PROJECT_NAME' created successfully."
else
    echo "Project creation failed. HTTP Response: $CREATE_PROJECT_RESPONSE"
    exit 1
fi

# Upload SBOM to Dependency Track
echo "Uploading SBOM: $LATEST_SBOM"
UPLOAD_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$DT_API_URL/v1/bom" \
  -H "X-Api-Key: $DT_API_KEY" \
  -F "projectName=$PROJECT_NAME" \
  -F "projectVersion=$PROJECT_VERSION" \
  -F "autoCreate=true" \
  -F "bom=@$LATEST_SBOM")

if [ "$UPLOAD_RESPONSE" -eq 200 ]; then
    echo "SBOM '$LATEST_SBOM' uploaded successfully."
    echo "Please check in 15-20 minutes for risk audit results."
else
    echo "SBOM upload failed. HTTP Response: $UPLOAD_RESPONSE"
    exit 1
fi
