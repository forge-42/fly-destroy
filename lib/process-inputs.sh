
process_inputs () {
  group "Prepare destroy variables"

  # Enable globstar to allow ** globs which is needed in this function
  shopt -s globstar

  if [[ -z "$INPUT_WORKSPACE_NAME" ]]; then
    notice "workspace_name not set. Using current directory as workspace_path and 'name' from ./package.json as workspace_name"
    local workspace_path_relative="."
    local workspace_path="$(pwd)"
    local workspace_name="$(jq -rS '.name' ./package.json)"
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
  debug "GITHUB_REPOSITORY=$GITHUB_REPOSITORY"
  debug "GITHUB_SHA=$GITHUB_SHA"
  debug "GITHUB_WORKSPACE=$GITHUB_WORKSPACE"

  # GITHUB_REPOSITORY is the full owner and repository in the form of "owner/repository-name"
  local default_app_name_prefix="${GITHUB_REPOSITORY}"

  # If the workspace is in the root of the repository, use only the repository owner part as prefix instead of owner/repository
  # This is to avoid conflicts with the package.json name and the repository owner/repository name
  if [[ "${workspace_path_relative}" == "." ]]; then
    default_app_name_prefix="${GITHUB_REPOSITORY_OWNER}"
  fi

  if [[ "${GITHUB_EVENT_NAME}" == "pull_request" ]]; then
    local pr_number=$(jq -r .number $GITHUB_EVENT_PATH)
    local default_app_name="${default_app_name_prefix}-${workspace_name}-pr-${pr_number}"
  elif [[ "${GITHUB_EVENT_NAME}" == "push" || "${GITHUB_EVENT_NAME}" == "create" ]]; then
    local default_app_name="${default_app_name_prefix}-${workspace_name}-${GITHUB_REF_TYPE}-${GITHUB_REF_NAME}"
  else
    warning "Unhandled GITHUB_EVENT_NAME '${GITHUB_EVENT_NAME}'. Considering setting 'app_name' as input."
    local default_app_name="${default_app_name_prefix}-${workspace_name}-${GITHUB_EVENT_NAME}"
  fi
  debug "default_app_name=$default_app_name"

  local raw_app_name="${INPUT_APP_NAME:-$default_app_name}"
  if [[ -z "$raw_app_name" ]]; then
    error "Default for 'app_name' could not be generated for github event '${GITHUB_EVENT_NAME}'. Please set 'app_name' as input."
    return 1
  fi

  local app_name="$(echo $raw_app_name | sed 's/[\.\/_]/-/g; s/[^a-zA-Z0-9-]//g' | tr '[:upper:]' '[:lower:]')"
  if [[ "${GITHUB_EVENT_NAME}" == "pull_request" ]]; then
    local pr_number=$(jq -r .number $GITHUB_EVENT_PATH)
    debug "pr_number=$pr_number"
    if [[ $app_name != *"$pr_number"* ]]; then
      error "For pull requests, the 'app_name' must contain the pull request number."
      return 1
    fi
  fi
  debug "app_name=$app_name"

  # First check if the parameter is either string "true" or "false"
  if [[ -n "$INPUT_DESTROY_POSTGRES" && ( "${INPUT_DESTROY_POSTGRES,,}" == "true" || "${INPUT_DESTROY_POSTGRES,,}" == "false" ) ]]; then
    local destroy_postgres="${INPUT_DESTROY_POSTGRES,,}" # lowercase postgres fly app name
    local destroy_postgres_name="${app_name,,}-postgres"
  elif [[ -n "$INPUT_DESTROY_POSTGRES" ]]; then
    local destroy_postgres="true"
    local destroy_postgres_name="${INPUT_DESTROY_POSTGRES,,}"
  else
    local destroy_postgres="false"
    local destroy_postgres_name=""
  fi

  # Disable globstar again to avoid problems with the ** glob
  shopt -u globstar

  # After processing all "inputs" like env vars set by GitHub Actions (GITHUB_*) and action inputs (INPUT_*)
  # we can now set the "outputs" for the the actual action logic (entrypoint.sh).
  # These are readonly but globally available in the entrypoint.sh script, and you should only use these.
  declare -rg WORKSPACE_NAME="$workspace_name"
  declare -rg WORKSPACE_PATH="$workspace_path"
  declare -rg WORKSPACE_PATH_RELATIVE="$workspace_path_relative"
  declare -rg APP_NAME="$app_name"
  declare -rg DESTROY_POSTGRES="$destroy_postgres"
  declare -rg DESTROY_POSTGRES_NAME="$destroy_postgres_name"

  debug "WORKSPACE_NAME=$WORKSPACE_NAME"
  debug "WORKSPACE_PATH=$WORKSPACE_PATH"
  debug "WORKSPACE_PATH_RELATIVE=$WORKSPACE_PATH_RELATIVE"
  debug "APP_NAME=$APP_NAME"
  debug "DESTROY_POSTGRES=$DESTROY_POSTGRES"
  debug "DESTROY_POSTGRES_NAME=$DESTROY_POSTGRES_NAME"

  group_end
}
