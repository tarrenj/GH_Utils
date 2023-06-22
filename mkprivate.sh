#!/bin/bash
# Set repos to private so we can transfer them to an external org

# Read the GitHub personal access token from a file
read -r TOKEN < token.txt

# The file containing the list of repositories, one per line in the format "owner/repo"
REPO_LIST="repos.txt"

# Read the file line by line
while IFS= read -r REPO
do
  # Skip comments
  if [[ $REPO = \#* ]]; then
    continue
  fi

  # Make the API request to set the repository to private
  RESPONSE=$(curl -s -w "\n%{http_code}\n" -X PATCH -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" \
    -d "{\"visibility\": \"private\"}" "https://api.github.com/repos/$REPO")

  STATUS_CODE=$(echo "$RESPONSE" | tail -n1)

  # Check if the operation was successful
  if [ $STATUS_CODE -eq 200 ]; then
    echo -e "\e[32mVisibility of $REPO set to private.\e[0m"
  else
    echo -e "\e[31mSetting visibility of $REPO to private failed with status code $STATUS_CODE. Response was:\n$RESPONSE\e[0m"
  fi
done < "$REPO_LIST"

