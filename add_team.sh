#!/bin/bash
# Add a specific team with specific role to each repo in an org

# Read the GitHub personal access token from a file
read -r TOKEN < <(tr -d '[:space:]' < ".token.txt")

# Prompt for the organization name
read -p "Enter the organization name: " ORG

# Prompt for the team name
read -p "Enter the team name: " TEAM_NAME

# Prompt for the role
read -p "Enter the role (admin, write, read): " ROLE

# Function to add the specified team to repositories with the specified role
add_team_to_repositories() {
  local ORG=$1
  local TEAM=$2
  local ROLE=$3

  echo -e "\nAdding team \"$TEAM\" to repositories in $ORG organization with the role \"$ROLE\":"
  REPOS_RESPONSE=$(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/orgs/$ORG/repos")
  REPO_NAMES=($(echo "$REPOS_RESPONSE" | jq -r '.[].name'))

  for REPO_NAME in "${REPO_NAMES[@]}"; do
    echo -e "\nRepository: $ORG/$REPO_NAME"

    # Get the team ID of the specified team
    TEAM_ID_RESPONSE=$(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/orgs/$ORG/teams")
    TEAM_ID=$(echo "$TEAM_ID_RESPONSE" | jq -r --arg team "$TEAM" '.[] | select(.name == $team) | .id')

    if [ -n "$TEAM_ID" ]; then
      # Make the API request to add the team to the repository with the specified role
      RESPONSE=$(curl -s -w "\n%{http_code}\n" -X PUT -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" \
        -d "{\"permission\": \"$ROLE\"}" "https://api.github.com/teams/$TEAM_ID/repos/$ORG/$REPO_NAME")
      STATUS_CODE=$(echo "$RESPONSE" | tail -n1)

      if [ $STATUS_CODE -eq 204 ]; then
        echo "Team \"$TEAM\" added to the repository with the role \"$ROLE\"."
      else
        echo "Failed to add team \"$TEAM\" to the repository with the role \"$ROLE\". Status code: $STATUS_CODE"
      fi
    else
      echo "Team \"$TEAM\" not found in the organization."
    fi
  done
}

# Add the specified team to repositories with the specified role
add_team_to_repositories "$ORG" "$TEAM_NAME" "$ROLE"

echo -e "\nDone adding team \"$TEAM_NAME\" to repositories."

