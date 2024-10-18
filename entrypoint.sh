#!/bin/bash

set -e

github_token="$INPUT_TOKEN"
repository_name="$INPUT_REPO_NAME"
org_name="$INPUT_ORG_NAME"
cookie_cutter_template="$INPUT_COOKIECUTTER_TEMPLATE"
template_directory="$INPUT_TEMPLATEDIRECTORY"
monorepo_url="$INPUT_MONOREPOURL"
scaffold_directory="$INPUT_SCAFFOLDDIRECTORY"
branch_name="scaffold_$repository_name"
git_url="$INPUT_GITHUB_URL"

create_repository() {
    resp=$(curl -H "Authorization: token $github_token" -H "Accept: application/json" -H "Content-Type: application/json" $git_url/users/$org_name)

    userType=$(jq -r '.type' <<<"$resp")

    if [ $userType == "User" ]; then
        curl -X POST -i -H "Authorization: token $github_token" -H "X-GitHub-Api-Version: 2022-11-28" \
            -d "{ \
          \"name\": \"$repository_name\", \"private\": true
        }" \
            $git_url/user/repos
    elif [ $userType == "Organization" ]; then
        curl -i -H "Authorization: token $github_token" \
            -d "{ \
          \"name\": \"$repository_name\", \"private\": true
        }" \
            $git_url/orgs/$org_name/repos
    else
        echo "Invalid user type"
    fi
}

apply_cookiecutter_template() {
    extra_context=$(prepare_cookiecutter_extra_context)

    echo "🍪 Applying cookiecutter template $cookie_cutter_template with extra context $extra_context"
    # Convert extra context from JSON to arguments
    args=()
    for key in $(echo "$extra_context" | jq -r 'keys[]'); do
        args+=("$key=$(echo "$extra_context" | jq -r ".$key")")
    done

    # Call cookiecutter with extra context arguments

    echo "cookiecutter --no-input $cookie_cutter_template $args"

    # Call cookiecutter with extra context arguments

    if [ -n "$template_directory" ]; then
        cookiecutter --no-input $cookie_cutter_template --directory $template_directory "${args[@]}"
    else
        cookiecutter --no-input $cookie_cutter_template "${args[@]}"
    fi
}

push_to_repository() {
    if [ -n "$monorepo_url" ] && [ -n "$scaffold_directory" ]; then
        git config user.name "GitHub Actions Bot"
        git config user.email "github-actions[bot]@users.noreply.github.com"
        git add .
        git commit -m "Scaffolded project in $scaffold_directory"
        git push -u origin $branch_name

        send_log "Creating pull request to merge $branch_name into main 🚢"

        owner=$(echo "$monorepo_url" | awk -F'/' '{print $4}')
        repo=$(echo "$monorepo_url" | awk -F'/' '{print $5}')

        echo "Owner: $owner"
        echo "Repo: $repo"

        PR_PAYLOAD=$(jq -n --arg title "Scaffolded project in $repo" --arg head "$branch_name" --arg base "main" '{
      "title": $title,
      "head": $head,
      "base": $base
    }')

        echo "PR Payload: $PR_PAYLOAD"

        pr_url=$(curl -X POST \
            -H "Authorization: token $github_token" \
            -H "Content-Type: application/json" \
            -d "$PR_PAYLOAD" \
            "$git_url/repos/$owner/$repo/pulls" | jq -r '.html_url')

        send_log "Opened a new PR in $pr_url 🚀"
        add_link "$pr_url"

    else
        cd "$(ls -td -- */ | head -n 1)"
        git init
        git config user.name "GitHub Actions Bot"
        git config user.email "github-actions[bot]@users.noreply.github.com"
        git add .
        git commit -m "Initial commit after scaffolding"
        git branch -M main
        git remote add origin https://oauth2:$github_token@github.com/$org_name/$repository_name.git
        git push -u origin main
    fi
}


main() {
  access_token=$(get_access_token)

  if [ -z "$monorepo_url" ] || [ -z "$scaffold_directory" ]; then
    send_log "Creating a new repository: $repository_name 🏃"
    create_repository
    send_log "Created a new repository at https://github.com/$org_name/$repository_name 🚀"
  else
    send_log "Using monorepo scaffolding 🏃"
    clone_monorepo
    cd_to_scaffold_directory
    send_log "Cloned monorepo and created branch $branch_name 🚀"
  fi

  send_log "Starting templating with cookiecutter 🍪"
  apply_cookiecutter_template
  send_log "Pushing the template into the repository ⬆️"
  push_to_repository

  url="https://github.com/$org_name/$repository_name"

  if [[ "$create_port_entity" == "true" ]]
  then
    send_log "Reporting to Port the new entity created 🚢"
    report_to_port
  else
    send_log "Skipping reporting to Port the new entity created 🚢"
  fi

  if [ -n "$monorepo_url" ] && [ -n "$scaffold_directory" ]; then
    send_log "Finished! 🏁✅"
  else
    send_log "Finished! Visit $url 🏁✅"
  fi
}

main