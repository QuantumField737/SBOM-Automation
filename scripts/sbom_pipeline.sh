name: Generate SBOM with Snyk (Self-Hosted Runner)

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  generate-sbom:
    runs-on: self-hosted  # Uses self-hosted runner

    steps:
      - name: Checkout Code
        uses: actions/checkout@v3

      - name: Ensure security-audit Directory Exists
        run: mkdir -p security-audit

      - name: Generate SBOM
        run: |
          REPO_NAME="${GITHUB_REPOSITORY##*/}"  # Extracts repo name
          TIMESTAMP=$(date +"%Y%m%d-%H%M%S")    # Simplified timestamp format
          SBOM_FILE="security-audit/${REPO_NAME}_SBOM_${TIMESTAMP}.json"
          snyk sbom --format=cyclonedx1.4+json > "$SBOM_FILE"

      - name: Commit and Push SBOM
        run: |
          git add security-audit/
          git commit -m "SBOM update"
          git push || echo "No changes to commit."
