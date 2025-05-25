
process_inputs () {
  group "Prepare destroy variables"

  # Enable globstar to allow ** globs which is needed in this function
  shopt -s globstar

  # When workspace_name is not set, we assume the current "root" directory of the repository is the workspace_path
  # and we use the "name" from the package.json in that directory as workspace_name.
  if [[ -z "$INPUT_WORKSPACE_NAME" ]]; then
    notice "workspace_name not set. Using current working directory '.' as workspace_path and 'name' from ./package.json as workspace_name"
    local workspace_path_relative="."
    local workspace_path="$(pwd)"
    local workspace_name="$(jq -rS '.name' ./package.json)"

  # When workspace_name is set, we search in any package.json for the given name and use the directory of that package.json as workspace_path.
  else
    local found_workspace="$(grep -rls "\"name\":.*\"$INPUT_WORKSPACE_NAME\"" **/package.json | xargs -I {} dirname {})"
    if [[ -z "$found_workspace" ]]; then
      error "No workspace with name '$INPUT_WORKSPACE_NAME' found."
      return 1
    fi
    local workspace_path_relative="$found_workspace"
    local workspace_path="$(cd "$found_workspace" && pwd)"
    local workspace_name="$INPUT_WORKSPACE_NAME"
  fi

  debug "workspace_name=$workspace_name"
  debug "workspace_path=$workspace_path"
  debug "workspace_path_relative=$workspace_path_relative"

  debug "GITHUB_EVENT_NAME=$GITHUB_EVENT_NAME"
  debug "GITHUB_REF_TYPE=$GITHUB_REF_TYPE"
  debug "GITHUB_REF_NAME=$GITHUB_REF_NAME"
  debug "GITHUB_EVENT_PATH=$GITHUB_EVENT_PATH"

  # Handle if the user wants to set a custom prefix (like $GITHUB_REPOSITORY_OWNER or $GITHUB_REPOSITORY) for the app name
  local default_app_name_prefix=""
  if [[ -n "$INPUT_APP_NAME_PREFIX" ]]; then
    default_app_name_prefix="${INPUT_APP_NAME_PREFIX,,}"
  fi
  debug "default_app_name_prefix=$default_app_name_prefix"

  # Handle if the user wants to set a custom suffix (like "production", "pre-production", etc.) for the app name
  local default_app_name_suffix=""
  if [[ -n "$INPUT_APP_NAME_SUFFIX" ]]; then
    default_app_name_suffix="${INPUT_APP_NAME_SUFFIX,,}"
  fi
  debug "default_app_name_suffix=$default_app_name_suffix"

  if [[ "${GITHUB_EVENT_NAME,,}" == "pull_request" ]]; then
    local pr_number=$(jq -r .number $GITHUB_EVENT_PATH)
    local default_app_name="${workspace_name}-pr-${pr_number}"
  elif [[ "${GITHUB_EVENT_NAME,,}" == "push" || "${GITHUB_EVENT_NAME,,}" == "create" ]]; then
    # <workspace_name>-<ref_type>-<ref_name>
    # e.g. base-stack-branch-bug/some-bugfix
    # e.g. base-stack-branch-main
    # e.g. base-stack-tag-v1.0.0
    local default_app_name="${workspace_name}-${GITHUB_REF_TYPE}-${GITHUB_REF_NAME}"
  elif [[ "${GITHUB_EVENT_NAME,,}" == "workflow_dispatch" ]]; then
    local default_app_name="${workspace_name}"
  else
    if [[ -z "$INPUT_APP_NAME" ]]; then
      # If no app_name is set, we show a warning that even is unhandled and generated default app_name might not be what the user expects.
      warning "Unhandled GITHUB_EVENT_NAME '${GITHUB_EVENT_NAME}'. Considering setting 'app_name' as input."
    fi
    local default_app_name="${workspace_name}-${GITHUB_EVENT_NAME}"
  fi

  # If the user has set a prefix for the app name, we prepend it to the beginning of default app name.
  if [[ -n "$default_app_name_prefix" ]]; then
    default_app_name="${default_app_name_prefix}-${default_app_name}"
  fi

  # If the user has set a suffix for the app name, we append it to the end of the default app name.
  if [[ -n "$default_app_name_suffix" ]]; then
    default_app_name="${default_app_name}-${default_app_name_suffix}"
  fi
  debug "default_app_name=$default_app_name"

  local raw_app_name="${INPUT_APP_NAME:-$default_app_name}"
  # Just a sanity check that we have any value for raw_app_name, should not happen at this point, but better safe than sorry.
  if [[ -z "$raw_app_name" ]]; then
    error "Default for 'app_name' could not be generated for github event '${GITHUB_EVENT_NAME}'. Please set 'app_name' as input."
    return 1
  fi

  # Replace all dots, slashes and underscores with dashes, remove all other non-alphanumeric characters and convert to lowercase.
  # This is needed to ensure the app_name is valid for Fly.io and does not contain any invalid characters.
  # In the end app_name needs to be a valid URL subdomain: <app_name>.fly.dev
  # for example:
  # base-stack-tag-v1.0.0 gets converted to base-stack-tag-v1-0-0
  # base-stack-branch-bug/some-bugfix gets converted to base-stack-branch-bug-some-bugfix
  local app_name="$(echo $raw_app_name | sed 's/[\.\/_]/-/g; s/[^a-zA-Z0-9-]//g' | tr '[:upper:]' '[:lower:]')"

  # Sanity check if the final app_name contains the pull request number when the event is a pull request.
  # This is needed to ensure the app_name is unique for each pull request and does not conflict with other branches or tags.
  if [[ "${GITHUB_EVENT_NAME}" == "pull_request" ]]; then
    local pr_number=$(jq -r .number $GITHUB_EVENT_PATH)
    debug "pr_number=$pr_number"
    if [[ $app_name != *"$pr_number"* ]]; then
      error "For pull requests, the 'app_name' must contain the pull request number."
      return 1
    fi
  fi
  debug "app_name=$app_name"

  # Disable globstar again to avoid problems with the ** glob
  shopt -u globstar

  # After processing all "inputs" like env vars set by GitHub Actions (GITHUB_*) and action inputs (INPUT_*)
  # we can now set the "outputs" for the the actual action logic (entrypoint.sh).
  # These are readonly but globally available in the entrypoint.sh script, and you should only use these.
  declare -rg WORKSPACE_NAME="$workspace_name"
  declare -rg WORKSPACE_PATH="$workspace_path"
  declare -rg WORKSPACE_PATH_RELATIVE="$workspace_path_relative"
  declare -rg APP_NAME="$app_name"

  debug "WORKSPACE_NAME=$WORKSPACE_NAME"
  debug "WORKSPACE_PATH=$WORKSPACE_PATH"
  debug "WORKSPACE_PATH_RELATIVE=$WORKSPACE_PATH_RELATIVE"
  debug "APP_NAME=$APP_NAME"

  group_end
}
