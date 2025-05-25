#!/usr/bin/env bash
# Deploy the app to fly.io

DEBUG="${DEBUG:-0}"
DRY_RUN="${DRY_RUN:-0}"

# Debug mode: Show commands and fail on any unbound variables
if [[ "$DEBUG" == "1" ]]; then
  set -xu -eE -o pipefail
  echo "DEBUG MODE: ON"
  echo "flyctl VERSION: $(flyctl --version)"
  echo "ENVIRONMENT VARIABLES: $(env | sort)"
else
  # Non-debug mode: Exit on any failure
  set -eE -o pipefail
fi

__dirname="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "$__dirname/lib/helper.sh"
source "$__dirname/lib/process-inputs.sh"

# Process all the "inputs" like env vars set by GitHub Actions (GITHUB_*) and action inputs (INPUT_*)
# this will also set the output variables for the the actual action logic in this file.
process_inputs

# Some sanity checks.
# If those output variables are empty, we exit with an error, since we can't proceed.
if [[
     -z "$WORKSPACE_NAME"
  || -z "$APP_NAME"
  || -z "$WORKSPACE_PATH_RELATIVE"
  ]]; then
  error "Something went wrong processing the necessary information needed for the deployment."
  exit 1
fi

apps_to_destroy=$APP_NAME

warning "Destroying the following apps: '$apps_to_destroy'."
echo -e "Destroy command: 'flyctl apps destroy --yes $apps_to_destroy'"
flyctl apps destroy --yes $apps_to_destroy

notice app_name=$APP_NAME
echo "app_name=$APP_NAME" >> $GITHUB_OUTPUT

notice workspace_name=$WORKSPACE_NAME
echo "workspace_name=$WORKSPACE_NAME" >> $GITHUB_OUTPUT

notice workspace_path=$WORKSPACE_PATH_RELATIVE
echo "workspace_path=$WORKSPACE_PATH_RELATIVE" >> $GITHUB_OUTPUT
