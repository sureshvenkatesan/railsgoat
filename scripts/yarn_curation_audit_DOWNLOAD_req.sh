#!/bin/bash
#USage:
# ./yarn_curation_audit_DOWNLOAD_req.sh "https://your.artifactory.instance/api/npm/your-repo" "YOUR_ACCESS_TOKEN"

# Ensure correct usage
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <ARTIFACTORY_BASE_URL> <ACCESS_TOKEN>"
    exit 1
fi

ARTIFACTORY_BASE_URL="$1"
ACCESS_TOKEN="$2"
YARN_DEPENDENCIES_FILE="dependencies.json"
DOWNLOAD_DIR="downloaded_packages"

# Create the downloaded_packages directory if it doesn't exist
mkdir -p "$DOWNLOAD_DIR"

# Generate the dependencies JSON file from Yarn lock
echo "Generating dependencies list from yarn.lock..."
yarn list --json > "$YARN_DEPENDENCIES_FILE"

# Check if dependencies.json was created
if [ ! -s "$YARN_DEPENDENCIES_FILE" ]; then
    echo "Error: Failed to generate dependencies.json. Is Yarn installed?"
    exit 1
fi

# Extract dependencies from JSON file
DEPENDENCIES=$(jq -r '.data.trees[] | .name' "$YARN_DEPENDENCIES_FILE")

# Function to check and download a package from Artifactory
check_and_download_package() {
    local package_name="$1"
    local package_version="$2"
    local package_url="${ARTIFACTORY_BASE_URL}/${package_name}/-/${package_name}-${package_version}.tgz"
    local output_file="${DOWNLOAD_DIR}/${package_name}-${package_version}.tgz"

    # Send HEAD request to check package availability
    response=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${ACCESS_TOKEN}" -I "$package_url")

    case "$response" in
        200)
            echo "$package_name $package_version ✅ Available in Artifactory"
            ;;
        403)
            echo "$package_name $package_version ❌ Blocked (403 Forbidden)"
            echo "Error Message: $(curl -s -H "Authorization: Bearer ${ACCESS_TOKEN}" "$package_url")"
            ;;
        404)
            echo "$package_name $package_version ❌ Not Found (404) - Downloading..."
            curl -s -H "Authorization: Bearer ${ACCESS_TOKEN}" -o "$output_file" "$package_url"

            # Check if the file was successfully downloaded
            if [ -s "$output_file" ]; then
                echo "$package_name $package_version ✅ Downloaded successfully to $output_file"
            else
                echo "$package_name $package_version ❌ Failed to download"
                rm -f "$output_file" # Remove empty file
            fi
            ;;
        *)
            echo "$package_name $package_version ⚠️ Unexpected Response: $response"
            echo "Error Message: $(curl -s -H "Authorization: Bearer ${ACCESS_TOKEN}" "$package_url")"
            ;;
    esac
}

# Iterate through dependencies and check/download each package
echo "Checking dependencies in Artifactory..."
while IFS=@ read -r package_name package_version; do
    if [[ -n "$package_name" && -n "$package_version" ]]; then
        check_and_download_package "$package_name" "$package_version"
    fi
done <<< "$DEPENDENCIES"

echo "Curation audit and download process completed."
