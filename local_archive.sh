#!/bin/bash

# Read the org name file
ORG_FILE="orgs.txt"
# Read the organizations from the file
while IFS= read -r line; do
  [[ "$OLD_ORG" ]] && NEW_ORG=$line || OLD_ORG=$line
done < $ORG_FILE
ORG=$OLD_ORG

# Read the GitHub personal access token from a file
read -r TOKEN < ".token.txt"

# Directory to store the cloned repositories
OUTPUT_DIR="${HOME}/${ORG}_archive/"

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Function to perform the archive clone of a repository
perform_archive_clone() {
  REPO=$1

  # Clone the repository using git
  git clone "git@github.com:$OLD_ORG/$REPO.git" "$OUTPUT_DIR/$REPO"


  # Check if the clone was successful
  if [ $? -eq 0 ]; then
    echo "Clone of $REPO completed"
    cd "$OUTPUT_DIR/$REPO" || exit

    # Fetch all branches and tags
    git fetch --all --tags

    # Download release assets
    RELEASES_RESPONSE=$(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/$ORG/$REPO/releases")
    ASSET_URLS=($(echo "$RELEASES_RESPONSE" | jq -r '.[].assets[].browser_download_url'))

    for URL in "${ASSET_URLS[@]}"; do
      curl -s -L -O -J -H "Authorization: token $TOKEN" "$URL"
    done

    cd - || exit
  else
    echo "Failed to clone $REPO"
  fi
}

# Fetch repositories for the organization
REPOS_RESPONSE=$(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/orgs/$ORG/repos?per_page=100")

# Extract repository names from the response
REPO_NAMES=($(echo "$REPOS_RESPONSE" | jq -r '.[].name'))

# Loop through the repositories and perform the archive clone
for REPO_NAME in "${REPO_NAMES[@]}"; do
  perform_archive_clone "$REPO_NAME"
done

