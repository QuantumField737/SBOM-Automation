name: Generate SBOM with Snyk (Self-Hosted Runner)

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  generate-sbom:
    runs-on: self-hosted  # Use the self-hosted runner
    steps:
      - name: Checkout Code
        uses: actions/checkout@v3

      - name: Ensure Snyk CLI is Installed (if not pre-installed)
        run: |
          if ! command -v snyk &> /dev/null
          then
            echo "Snyk CLI not found. Installing..."
            curl -Lo snyk https://github.com/snyk/snyk/releases/latest/download/snyk-linux
            chmod +x snyk
            sudo mv snyk /usr/local/bin/
          else
            echo "Snyk CLI already installed."
          fi

      - name: Authenticate Snyk
        run: snyk auth ${{ secrets.SNYK_TOKEN }}

      - name: Ensure security-audit Directory Exists
        run: mkdir -p security-audit

      - name: Generate SBOM
        run: |
          REPO_NAME=${GITHUB_REPOSITORY##*/}
          TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
          SBOM_FILE="security-audit/${REPO_NAME}_SBOM_${TIMESTAMP}.json"
          snyk sbom --format cyclonedx1.4+json > "$SBOM_FILE"

      - name: Commit and Push SBOM to Repo
        run: |
          git config --global user.name "github-actions"
          git config --global user.email "actions@github.com"
          git add security-audit/
          git commit -m "Updated SBOM"
          git push
        continue-on-error: true  # Prevents failure if no changes exist
