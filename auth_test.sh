#!/bin/bash
# Test API auth

# Read the org name file
ORG_FILE="orgs.txt"
# Read the organizations from the file
while IFS= read -r line; do
  [[ "$OLD_ORG" ]] && NEW_ORG=$line || OLD_ORG=$line
done < $ORG_FILE
echo "New org:" $OLD_ORG
echo "Old org:" $NEW_ORG

# Read the token from the file
read -r TOKEN < .token.txt

# The name for the test repo
REPO_NAME="API_Testing"

# -----

# Test basic auth
echo "Testing basic auth:"
RESPONSE=$(curl -s -w "\n%{http_code}\n" -H "Authorization: token $TOKEN" https://api.github.com/user)
STATUS_CODE=$(echo "$RESPONSE" | tail -n1)
if [ $STATUS_CODE -ne 200 ]; then
  echo -e "\e[31mBasic auth test failed with status code $STATUS_CODE. Response was:\n$RESPONSE\e[0m"
  exit 1
fi

# Loop over the organizations
for ORG in $OLD_ORG $NEW_ORG
do
  # Test creating a new repo
  echo "Testing repo creation in $ORG:"
  RESPONSE=$(curl -s -w "\n%{http_code}\n" -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/orgs/$ORG/repos -d "{\"name\": \"$REPO_NAME\"}")
  STATUS_CODE=$(echo "$RESPONSE" | tail -n1)
  if [ $STATUS_CODE -ne 201 ]; then
    echo -e "\e[31mRepo creation in $ORG failed with status code $STATUS_CODE. Response was:\n$RESPONSE\e[0m"
    exit 1
  fi

  # Pause to ensure repo is fully created before trying to delete
  sleep 10

  # Test deleting the repo
  echo "Testing repo deletion in $ORG:"
  RESPONSE=$(curl -s -w "\n%{http_code}\n" -X DELETE -H "Authorization: token $TOKEN" \
    https://api.github.com/repos/$ORG/$REPO_NAME)
  STATUS_CODE=$(echo "$RESPONSE" | tail -n1)
  if [ $STATUS_CODE -ne 204 ]; then
    echo -e "\e[31mRepo deletion in $ORG failed with status code $STATUS_CODE. Response was:\n$RESPONSE\e[0m"
    exit 1
  fi
done

# If the script reaches this point, all tests were successful
echo -e "\e[32mAll tests were successful!\e[0m"
