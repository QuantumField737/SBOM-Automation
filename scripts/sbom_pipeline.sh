import os
import glob
import requests

# Dependency Track API details from environment variables
DT_API_URL = os.getenv("DT_API_URL", "https://your-dependency-track-instance/api")
DT_API_KEY = os.getenv("DT_API_KEY")

SBOM_DIR = "security-audit"

def get_latest_sbom():
    """Find the latest SBOM file in the security-audit folder."""
    sbom_files = sorted(glob.glob(os.path.join(SBOM_DIR, "*.json")), key=os.path.getmtime, reverse=True)
    return sbom_files[0] if sbom_files else None

def create_project(project_name, project_version="1.0"):
    """Create a project in Dependency Track if it doesn't exist."""
    headers = {"X-Api-Key": DT_API_KEY, "Content-Type": "application/json"}
    payload = {"name": project_name, "version": project_version}

    response = requests.put(f"{DT_API_URL}/v1/project", json=payload, headers=headers)
    if response.status_code in [200, 201]:
        print(f"Project '{project_name}' created successfully.")
        return response.json().get("uuid")
    elif response.status_code == 409:
        print(f"Project '{project_name}' already exists.")
        return None
    else:
        print(f"Failed to create project: {response.text}")
        return None

def upload_sbom(sbom_path, project_name):
    """Upload the SBOM to Dependency Track."""
    headers = {"X-Api-Key": DT_API_KEY}
    files = {"bom": open(sbom_path, "rb")}
    data = {"projectName": project_name, "projectVersion": "1.0", "autoCreate": "true"}

    response = requests.post(f"{DT_API_URL}/v1/bom", headers=headers, files=files, data=data)
    if response.status_code == 200:
        print(f"SBOM '{sbom_path}' uploaded successfully.")
        return response.json().get("token")
    else:
        print(f"Failed to upload SBOM: {response.text}")
        return None

def main():
    latest_sbom = get_latest_sbom()
    if not latest_sbom:
        print("No SBOM files found. Exiting.")
        return

    project_name = os.path.basename(latest_sbom).replace(".json", "")
    project_uuid = create_project(project_name)

    if project_uuid is not None:
        upload_sbom(latest_sbom, project_name)
        print("Please check in 15-20 minutes for risk audit results.")

if __name__ == "__main__":
    main()
