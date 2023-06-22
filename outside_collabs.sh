#!/bin/bash

# Read the GitHub personal access token from a file
read -r TOKEN < <(tr -d '[:space:]' < ".token.txt")

# Read the organizations from the file
ORG_FILE="orgs.txt"
while IFS= read -r line; do
  [[ "$OLD_ORG" ]] && NEW_ORG=$line || OLD_ORG=$line
done < "$ORG_FILE"

# Function to check repositories for outside collaborators
check_repositories() {
  local ORG=$1

  echo -e "\nChecking repositories in $ORG organization for outside collaborators:"
  REPOS_RESPONSE=$(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/orgs/$ORG/repos")
  REPO_NAMES=($(echo "$REPOS_RESPONSE" | jq -r '.[].name'))

  for REPO_NAME in "${REPO_NAMES[@]}"; do
    echo -e "\nRepository: $ORG/$REPO_NAME"
    COLLABORATORS_RESPONSE=$(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/$ORG/$REPO_NAME/collaborators")
    COLLABORATOR_LOGINS=($(echo "$COLLABORATORS_RESPONSE" | jq -r '.[].login'))

    if [ ${#COLLABORATOR_LOGINS[@]} -gt 0 ]; then
      # Exclude team members
      TEAM_MEMBERS=($(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/orgs/$ORG/teams" | jq -r --arg repo "$REPO_NAME" '.[] | select(.permission != "admin") | .id' | xargs -I{} curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/teams/{}/members" | jq -r '.[].login'))

      OUTSIDE_COLLABORATORS=()
      for COLLABORATOR_LOGIN in "${COLLABORATOR_LOGINS[@]}"; do
        if [[ " ${TEAM_MEMBERS[@]} " != *" $COLLABORATOR_LOGIN "* ]]; then
          OUTSIDE_COLLABORATORS+=("$COLLABORATOR_LOGIN")
        fi
      done

      if [ ${#OUTSIDE_COLLABORATORS[@]} -gt 0 ]; then
        echo "Outside Collaborators:"
        for COLLABORATOR_LOGIN in "${OUTSIDE_COLLABORATORS[@]}"; do
          echo "- $COLLABORATOR_LOGIN"
        done
      else
        echo "No outside collaborators found."
      fi
    else
      echo "No collaborators found."
    fi
  done
}

# Check repositories in the OLD_ORG organization
check_repositories "$OLD_ORG"

# Check repositories in the NEW_ORG organization
check_repositories "$NEW_ORG"

echo -e "\nDone checking repositories for outside collaborators."

