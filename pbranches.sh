#!/bin/bash

# Read the org name file
ORG_FILE="orgs.txt"
# Read the organizations from the file
while IFS= read -r line; do
  [[ "$OLD_ORG" ]] && NEW_ORG=$line || OLD_ORG=$line
done < $ORG_FILE
ORG_NAME=${NEW_ORG}

# Read the GitHub personal access token from a file
read -r TOKEN < ".token.txt"

# Deny list of repositories (one per line) to exclude from applying protected branch settings
DENY_LIST="pbranch_deny.txt"

# Directory containing branch templates
TEMPLATE_DIR="pbranch_templates"

# Read the deny list file and store repositories in an array
mapfile -t DENY_REPOS < "$DENY_LIST"

# Function to apply protected branch settings to a repository
apply_protected_branch_settings() {
  REPO=$1
  FILE=$2

  # Check if the repository is in the deny list
  for DENY_REPO in "${DENY_REPOS[@]}"; do
    if [[ "$REPO" == "$DENY_REPO" ]]; then
      echo "Skipping $REPO (in deny list)"
      return
    fi
  done

  # Read branch settings from the template file
  SETTINGS=$(<"$FILE")

  # Extract the branch name from the template file name
  BRANCH=$(basename "$FILE" .txt)

  # Make the API request to apply protected branch settings
  RESPONSE=$(curl -s -w "\n%{http_code}\n" -X PUT -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.luke-cage-preview+json" \
    -d "$SETTINGS" "https://api.github.com/repos/$ORG_NAME/$REPO/branches/$BRANCH/protection")

  STATUS_CODE=$(echo "$RESPONSE" | tail -n1)
  ERROR_MESSAGE=$(echo "$RESPONSE" | jq -r 'if type=="object" then .message // empty else empty end' 2>/dev/null)


  # Check if the protected branch settings were successfully applied
  if [ $STATUS_CODE -eq 200 ]; then
    echo -e "\e[32mProtected branch settings applied to branch '$BRANCH' of $REPO\e[0m"
  elif [[ $ERROR_MESSAGE == "Branch not found" ]]; then
    echo -e "\e[33mBranch '$BRANCH' of $REPO not found. Skipping...\e[0m"
  else
    echo -e "\e[31mFailed to apply protected branch settings to branch '$BRANCH' of $REPO (Status code: $STATUS_CODE). Error: $ERROR_MESSAGE\e[0m"
  fi
}

# Fetch repositories for the organization
REPOS_RESPONSE=$(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/orgs/$ORG_NAME/repos?per_page=100")

# Extract repository names from the response
REPO_NAMES=($(echo "$REPOS_RESPONSE" | jq -r '.[].name'))

# Loop through the repositories and apply protected branch settings for each file in the template directory
for REPO_NAME in "${REPO_NAMES[@]}"; do
  for FILE in "$TEMPLATE_DIR"/*.txt; do
    apply_protected_branch_settings "$REPO_NAME" "$FILE"
  done
done

