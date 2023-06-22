#!/bin/bash
# Transfer targeted repos from one GH org to another, keeping team associations
  # Assumes identical team names exist!
# Output is messy, but whatever....

# Read the organizations from the file
ORG_FILE="orgs.txt"
while IFS= read -r line; do
  [[ "$OLD_ORG" ]] && NEW_ORG=$line || OLD_ORG=$line
done < "$ORG_FILE"

# Read the GitHub personal access token from a file
read -r TOKEN < <(tr -d '[:space:]' < ".token.txt")

# The file containing the list of repositories, one per line in the format "owner/repo"
REPO_LIST="repos.txt"

# Arrays to hold the successful/failed transfers, team additions, and existing people in $OLD_ORG/$REPO
SUCCESSFUL=()
FAILED=()
SKIPPED=()
SUCCESSFUL_TEAMS=()
FAILED_TEAMS=()
BAD_TEAMS=()
PEOPLE=()

# Read the file line by line
while IFS= read -r REPO
do
  # Skip lines starting with #
  [[ "$REPO" =~ ^#.*$ ]] && continue
  # Skip empty lines
  [[ -z "$REPO" ]] && continue
  # Extract the repository name from the "owner/repo" format
  # May require ZSH for this part to work?
  REPO=${REPO##*/}
  
  # Get the list of collaborators for the repository in the old org
  PEOPLE_RESPONSE=$(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/$OLD_ORG/$REPO/collaborators")
  # Extract collaborator names from the response
  PEOPLE_NAMES=($(echo "$PEOPLE_RESPONSE" | jq -r '.[].login' 2>/dev/null))
  # Output the identified collaborators
  echo -e "\e[33mIdentified collaborators for repository $REPO in the old organization $OLD_ORG:\e[0m"
  for ((i=0; i<${#PEOPLE_NAMES[@]}; i++)); do
    PERSON_NAME="${PEOPLE_NAMES[$i]}"
    echo "Collaborator: $PERSON_NAME"
    PEOPLE+=("$PERSON_NAME")
  done


  # Get the list of teams and their roles for the repository in the old org
  TEAMS_RESPONSE=$(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/$OLD_ORG/$REPO/teams")
  # Check if the response is not an error message (when the repository exists)
  if [[ "$(echo "$TEAMS_RESPONSE" | jq -r '.message' 2>/dev/null)" == "Moved Permanently" ]] || [[ "$(echo "$TEAMS_RESPONSE" | jq -r '.message' 2>/dev/null)" == "Not Found" ]]; then
    echo -e "\e[33mRepository not found, already transfered?:\e[0m $OLD_ORG/$REPO"
    SKIPPED+=("$OLD_ORG"::"$REPO")
    continue
  elif [[ "$(echo "$TEAMS_RESPONSE" | jq -e 2>/dev/null)" == "null" ]]; then
    FAILED_TEAMS+=("$NEW_ORG"::"$REPO::$TEAM_NAME")
    echo "Error occurred while getting teams for repository $REPO in the old organization $OLD_ORG."
    echo "Response: $TEAMS_RESPONSE"
    
  else
    # Extract team names and roles from the response
    TEAM_NAMES=($(echo "$TEAMS_RESPONSE" | jq -r '.[].name'))
    TEAM_ROLES=($(echo "$TEAMS_RESPONSE" | jq -r '.[].permission'))

    # Output the identified teams
    echo -e "\e[32mIdentified teams for repository $REPO in the old organization $OLD_ORG:\e[0m"
    for ((i=0; i<${#TEAM_NAMES[@]}; i++)); do
      TEAM_NAME="${TEAM_NAMES[$i]}"
      TEAM_ROLE="${TEAM_ROLES[$i]}"
      echo "Team Name: $TEAM_NAME, Role: $TEAM_ROLE"
    done
  fi
  
  # Make the API request to transfer the repository
  RESPONSE=$(curl -s -w "\n%{http_code}\n" -X POST -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" \
    -d "{\"new_owner\": \"$NEW_ORG\"}" "https://api.github.com/repos/$OLD_ORG/$REPO/transfer")
  STATUS_CODE=$(echo "$RESPONSE" | tail -n1)

  # Check if the transfer was successful or already done
  if [ $STATUS_CODE -eq 202 ] || [ $STATUS_CODE -eq 307 ]; then
    if [ $STATUS_CODE -eq 202 ]; then
      echo -e "\e[32mTransfer of $REPO to $NEW_ORG was successful.\e[0m"
      SUCCESSFUL+=("$REPO")
    else
      echo -e "\e[33mTransfer of $REPO to $NEW_ORG was already done.\e[0m"
      SKIPPED+=("$REPO")
    fi
  else
    echo -e "\e[31mTransfer of $REPO to $NEW_ORG failed with status code $STATUS_CODE. Response was:\n$RESPONSE\e[0m"
    FAILED+=("$REPO")
  fi

  # Loop through the teams and add them to the repository in the new org
  for ((i=0; i<${#TEAM_NAMES[@]}; i++)); do
    TEAM_NAME="${TEAM_NAMES[$i]}"
    TEAM_ROLE="${TEAM_ROLES[$i]}"
    # Find the team ID in the new org
    #TEAM_ID_RESPONSE=$(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/orgs/$NEW_ORG/teams" | jq -r '.[] | select(.name=="'$TEAM_NAME'") | .id')
    TEAM_ID_RESPONSE=$(curl -s -w "\n%{http_code}\n" -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/orgs/$NEW_ORG/teams")
    TEAM_ID_STATUS_CODE=$(echo "$TEAM_ID_RESPONSE" | tail -n1)

    # Check if getting the team ID was successful
    if [ $TEAM_ID_STATUS_CODE -eq 200 ]; then
      TEAM_ID=$(echo "$TEAM_ID_RESPONSE" | head -n -1 | jq -r '.[] | select(.name=="'$TEAM_NAME'") | .id' 2>/dev/null)
      if [ -z "$TEAM_ID" ]; then
        echo -e "\e[31mCouldn't find team $TEAM_NAME in organization $NEW_ORG.\e[0m"
        BAD_TEAMS+=("$TEAM_NAME")
        continue
      fi
    else
      echo -e "\e[31mGetting team ID for $TEAM_NAME in $NEW_ORG failed with status code $TEAM_ID_STATUS_CODE. Response was:\n$TEAM_ID_RESPONSE\e[0m"
        BAD_TEAMS+=("$TEAM_NAME")
      continue
    fi

    # Make the API request to add the team to the repository
    sleep 1 # Give the repo time to transfer
    ADD_TEAM_RESPONSE=$(curl -s -w "\n%{http_code}\n" -X PUT -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" \
      -d "{\"permission\": \"$TEAM_ROLE\"}" "https://api.github.com/teams/$TEAM_ID/repos/$NEW_ORG/$REPO")
    ADD_TEAM_STATUS_CODE=$(echo "$ADD_TEAM_RESPONSE" | tail -n1)
    # Check if adding the team was successful
    if [ $ADD_TEAM_STATUS_CODE -eq 204 ]; then
      echo -e "\e[32mTeam $TEAM_NAME with role $TEAM_ROLE added to $REPO in $NEW_ORG.\e[0m"
      SUCCESSFUL_TEAMS+=("$REPO::$TEAM_NAME")
    else
      echo -e "\e[31mAdding team $TEAM_NAME with role $TEAM_ROLE to $REPO in $NEW_ORG failed with status code $ADD_TEAM_STATUS_CODE.\e[0m"
      FAILED_TEAMS+=("$NEW_ORG"::"$REPO::$TEAM_NAME")
    fi
  done
  if [ ${#PEOPLE[@]} -gt 0 ]; then
    echo "-------------------------------------"
    echo "Summary of people:"
    echo -e "\e[33mPeople:\e[0m"
    for ENTRY in "${PEOPLE[@]}"; do
      echo -e "\t$ENTRY"
    done
  fi
done < "$REPO_LIST"

# Print the summary
echo "-------------------------------------"
echo "Summary of transfer:"
if [ ${#SUCCESSFUL[@]} -gt 0 ]; then
  echo -e "\e[32mSuccessful transfers:\e[0m"
  for ENTRY in "${SUCCESSFUL[@]}"; do
    echo -e "\t$ENTRY"
  done
fi
if [ ${#SKIPPED[@]} -gt 0 ]; then
  echo -e "\e[33mSkipped transfers:\e[0m"
  for ENTRY in "${SKIPPED[@]}"; do
    echo -e "\t$ENTRY"
  done
fi
if [ ${#FAILED[@]} -gt 0 ]; then
  echo -e "\e[31mFailed transfers:\e[0m"
  for ENTRY in "${FAILED[@]}"; do
    echo -e "\t$ENTRY"
  done
fi
if [ ${#BAD_TEAMS[@]} -gt 0 ]; then
  echo -e "\e[31mBad team:\e[0m"
  for ENTRY in "${BAD_TEAMS[@]}"; do
    echo -e "\t$ENTRY"
  done
fi
if [ ${#FAILED_TEAMS[@]} -gt 0 ]; then
  echo -e "\e[31mFailed teams:\e[0m"
  for ENTRY in "${FAILED_TEAMS[@]}"; do
    echo -e "\t$ENTRY"
  done
fi

