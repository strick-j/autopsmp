#!/usr/bin/env bash

# Bash:

# echos 0 if function exists, otherwise non-zero
function _function_exists {
  local function_name="$1" # required

  declare -f -F "$function_name" > /dev/null 2>&1
  echo $?
}
