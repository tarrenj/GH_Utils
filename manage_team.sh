#!/bin/bash
# Add or remove a specific team from each repo in an org

# Read the GitHub personal access token from a file
read -r TOKEN < <(tr -d '[:space:]' < ".token.txt")

# Prompt for the organization name
read -p "Enter the organization name: " ORG

# Prompt for the team name
read -p "Enter the team name: " TEAM_NAME

# Check if we need to add or remove teams
if [ "$1" == "--remove" ]; then
  OPERATION="remove"
else
  # Prompt for the role
  read -p "Enter the role (admin, maintain, write, read): " ROLE
  OPERATION="add"
fi

# Check if we need to do a dry run
if [ "$2" == "--dryrun" ]; then
  DRY_RUN=true
else
  DRY_RUN=false
fi

# Function to add the specified team to repositories with the specified role
add_team_to_repositories() {
  local ORG=$1
  local TEAM=$2
  local ROLE=$3
  operate_on_team $ORG $TEAM $ROLE "add"
}

# Function to remove the specified team from repositories
remove_team_from_repositories() {
  local ORG=$1
  local TEAM=$2
  operate_on_team $ORG $TEAM "" "remove"
}

# Function to either add or remove the specified team from repositories
operate_on_team() {
  local ORG=$1
  local TEAM=$2
  local ROLE=$3
  local OPERATION=$4

  echo -e "\n$OPERATION team \"$TEAM\" from repositories in $ORG organization."

  REPOS_RESPONSE=$(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/orgs/$ORG/repos")
  REPO_NAMES=($(echo "$REPOS_RESPONSE" | jq -r '.[].name'))

  for REPO_NAME in "${REPO_NAMES[@]}"; do
    echo -e "\nRepository: $ORG/$REPO_NAME"

    # Get the team ID of the specified team
    TEAM_ID_RESPONSE=$(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/orgs/$ORG/teams")
    TEAM_ID=$(echo "$TEAM_ID_RESPONSE" | jq -r --arg team "$TEAM" '.[] | select(.name == $team) | .id')

    if [ -n "$TEAM_ID" ]; then
      # Make the API request to add/remove the team to/from the repository with the specified role
      if [ "$OPERATION" == "add" ]; then
        HTTP_METHOD="PUT"
        DATA="{\"permission\": \"$ROLE\"}"
      else
        HTTP_METHOD="DELETE"
        DATA=""
      fi

      if [ "$DRY_RUN" == "true" ]; then
        echo "Would $OPERATION team \"$TEAM\" from the repository."
      else
        RESPONSE=$(curl -s -w "\n%{http_code}\n" -X $HTTP_METHOD -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" \
          -d "{ \"permission\": \"$ROLE\" }" "https://api.github.com/teams/$TEAM_ID/repos/$ORG/$REPO_NAME")
        STATUS_CODE=$(echo "$RESPONSE" | tail -n1)

        if [ $STATUS_CODE -eq 204 ]; then
          echo "Team \"$TEAM\" ${OPERATION}ed from the repository."
        else
          echo "Failed to $OPERATION team \"$TEAM\" from the repository. Status code: $STATUS_CODE"
        fi
      fi
    else
      echo "Team \"$TEAM\" not found in the organization."
    fi
  done
}

if [ "$OPERATION" == "add" ]; then
  add_team_to_repositories "$ORG" "$TEAM_NAME" "$ROLE"
  if [ "$DRY_RUN" == "true" ]; then
    echo -e "\nDone with dry run. Would have added team \"$TEAM_NAME\" to repositories."
  else
    echo -e "\nDone adding team \"$TEAM_NAME\" to repositories."
  fi
else
  remove_team_from_repositories "$ORG" "$TEAM_NAME"
  if [ "$DRY_RUN" == "true" ]; then
    echo -e "\nDone with dry run. Would have removed team \"$TEAM_NAME\" from repositories."
  else
    echo -e "\nDone removing team \"$TEAM_NAME\" from repositories."
  fi
fi
