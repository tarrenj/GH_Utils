#!/bin/bash
# Read team names from old org and warn if they don't exist in new org

# Read the GitHub personal access token from a file
read -r TOKEN < <(tr -d '[:space:]' < ".token.txt")

# Read the organizations from the file
ORG_FILE="orgs.txt"
while IFS= read -r line; do
  [[ "$OLD_ORG" ]] && NEW_ORG=$line || OLD_ORG=$line
done < "$ORG_FILE"

# Get all team names from the OLD_ORG organization
TEAM_NAMES=($(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/orgs/$OLD_ORG/teams" | jq -r '.[].name'))

# Check for missing teams in the NEW_ORG organization
MISSING_TEAMS=()
for TEAM_NAME in "${TEAM_NAMES[@]}"; do
  # Check if the team exists in the NEW_ORG organization
  echo -e "Checking:" $TEAM_NAME
  EXISTS=$(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/orgs/$NEW_ORG/teams" | jq -r --arg team "$TEAM_NAME" '.[].name | select(. == $team)')
  if [[ -z "$EXISTS" ]]; then
    MISSING_TEAMS+=("$TEAM_NAME")
  fi
done

# Alert the user about missing teams in the NEW_ORG organization
if [ ${#MISSING_TEAMS[@]} -gt 0 ]; then
  echo -e "\e[31mMissing teams in $NEW_ORG organization:\e[0m"
  for TEAM_NAME in "${MISSING_TEAMS[@]}"; do
    echo -e "\t$TEAM_NAME"
  done
else
  echo -e "\e[32mAll teams from $OLD_ORG organization exist in $NEW_ORG organization.\e[0m"
fi

