#!/bin/bash
#Usage:
# ./yarn_curation_audit_HEAD_req.sh "https://your.artifactory.instance/api/npm/your-repo" "YOUR_ACCESS_TOKEN"

# Ensure correct usage
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <ARTIFACTORY_BASE_URL> <ACCESS_TOKEN>"
    exit 1
fi

ARTIFACTORY_BASE_URL="$1"
ACCESS_TOKEN="$2"
YARN_DEPENDENCIES_FILE="dependencies.json"

# Generate the dependencies JSON file from Yarn lock
echo "Generating dependencies list from yarn.lock..."
# Detect Yarn version
YARN_VERSION=$(yarn --version | cut -d. -f1)

# Generate the dependencies JSON file
echo "Detecting Yarn version..."
if [ "$YARN_VERSION" -eq 1 ]; then
    echo "Using Yarn 1 (Classic)..."
    yarn list --json > "$YARN_DEPENDENCIES_FILE"
elif [ "$YARN_VERSION" -ge 2 ]; then
    echo "Using Yarn 2+ (Berry)..."
    yarn info --name-only --recursive --json > "$YARN_DEPENDENCIES_FILE"
else
    echo "Error: Unsupported Yarn version ($YARN_VERSION)"
    exit 1
fi

# Check if dependencies.json was created
if [ ! -s "$YARN_DEPENDENCIES_FILE" ]; then
    echo "Error: Failed to generate dependencies.json. Is Yarn installed?"
    exit 1
fi

echo "Dependencies extracted successfully!"

# Extract dependencies from JSON file
DEPENDENCIES=$(jq -r '.data.trees[] | .name' "$YARN_DEPENDENCIES_FILE")

# Function to check if a package exists in Artifactory
check_artifactory() {
    local package_name="$1"
    local package_version="$2"
    local package_url="${ARTIFACTORY_BASE_URL}/${package_name}/-/${package_name}-${package_version}.tgz"

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
            echo "$package_name $package_version ❌ Not Found (404)"
            ;;
        *)
            echo "$package_name $package_version ⚠️ Unexpected Response: $response"
            echo "Error Message: $(curl -s -H "Authorization: Bearer ${ACCESS_TOKEN}" "$package_url")"
            ;;
    esac
}

# Iterate through dependencies and check each in Artifactory
echo "Checking dependencies in Artifactory..."
while IFS=@ read -r package_name package_version; do
    if [[ -n "$package_name" && -n "$package_version" ]]; then
        check_artifactory "$package_name" "$package_version"
    fi
done <<< "$DEPENDENCIES"

echo "Curation audit completed."
