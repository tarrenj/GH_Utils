# Github Organization Tranfer Utilities

These scripts were created (with <3 by ChatGPT!) to help transfer a GH Enterprise org to a GH Teams org.

| :exclamation: These scripts can nuke your entire org! Execute with extreme caution!  |
|-----------------------------------------|

## Prep
0. **Install required utils**:
    - `sudo apt install jq`

1. **Generate a new API token**:
    - Navigate to [GitHub's New Personal Access Token page](https://github.com/settings/tokens/new).
    - Enter a note for the token (e.g., "Org Transfer Test Script").
    - Select the `repo`, `admin:org`, `delete_repo` and `user` scopes.
    - Click "Generate token" at the bottom of the page.
    - Copy the generated token.

2. **Save the API token**:
    - Open a new file in your text editor and paste the token into the file.
    - Save the file as `.token.txt` in the same directory as the scripts.

3. **Specify the organizations**:
    - Open a new file in your text editor.
    - On the first line, enter the name of the old (source) organization.
    - On the second line, enter the name of the new (destination) organization.
    - Save the file as `orgs.txt` in the same directory as the scripts.

    Please ensure that both organizations exist and that you have the necessary permissions to
    create and delete repositories in both.

4. **Specify the repos**:
    - Open a new file in your text editor.
    - Enter the repositories you wish to transfer from the old organization to the new organization.
        One entry per line.
    - Save the file as `repos.txt` in the same directory as the scripts.

## Scripts:
`auth_test.sh` - Test authentication stuff

`list_repos.sh` - Generate `origrepos_${ORG}.txt` for each org for your modifying pleasure

`transfer.sh` - Transfer repositories

`pbranches.sh` - Apply (a staticly defined) protected branch settings to all repos in ${NEW_ORG}, ignoreing those in `denylist.txt`.
    Protected branch settings are read from `source_pbranch.txt`
