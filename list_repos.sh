#!/bin/bash
# Generate lists of repos per org

# Read the organizations from the file
ORG_FILE="orgs.txt"
while IFS= read -r line; do
  [[ "$OLD_ORG" ]] && NEW_ORG="$line" || OLD_ORG="$line"
done < "$ORG_FILE"

# Read the GitHub personal access token from a file
read -r TOKEN < ".token.txt"

# Function to fetch repositories for an organization and write to the output file
fetch_repos() {
  ORG="$1"
  
  # Make the API request to fetch repositories for the organization
  RESPONSE=$(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/orgs/$ORG/repos")
  
  # Extract repository names from the response and write to the output file
  echo "$RESPONSE" | jq -r '.[].full_name' > "origrepos_${ORG}.txt"
}

# Generate the files
for ORG in "$OLD_ORG" "$NEW_ORG"; do
    fetch_repos "$ORG"
    echo "Repositories in org ($ORG) written to 'origrepos_${ORG}.txt'"
done
