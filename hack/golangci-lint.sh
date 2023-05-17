#!/usr/bin/env bash
#
# Copyright Confidential Containers Contributors
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

function echoerr() {
    echo "$@" 1>&2
}

function usage() {
    echoerr golangci-lint wrapper script
    echoerr "Usage: $0 [-v]"
    echoerr
    echoerr "Options:"
    echoerr "  -v     verbose output"
}

# Parse flags
verbose=false
while getopts "v" opt; do
    case $opt in
        v)
            verbose=true
            ;;
        \?)
            echoerr # newline
            usage
            exit 1
            ;;
    esac
done

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echoerr "Go is not installed, please install it."
    echoerr "You can find installation instructions at https://golang.org/doc/install."
    exit 1
fi

# Check if golangci-lint is installed
if ! command -v golangci-lint &> /dev/null; then
    echoerr "golangci-lint is not installed, please install it."
    echoerr "You can find installation instructions at https://golangci-lint.run/usage/install/."
    exit 1
fi

# Configuration
excludeModules=(
    "./podvm" # see the comment in podvm/go.mod
)
flags=()

goModules=$(find . -name go.mod -exec sh -c 'dirname $1' shell {} \;)

# Exclude modules
for module in "${excludeModules[@]}"; do
    goModules=$(echo "$goModules" | grep -v "$module")
done

if [ "$verbose" = true ]; then
    echo "Excluded modules:"
    for module in "${excludeModules[@]}"; do
        echo "  $module"
    done
    echo # newline

    echo "Checking the following Go modules:"
    for module in $goModules; do
        echo "  $module"
    done
    echo # newline

    flags+=("--verbose")
fi

statuscode=0

flags+=("--path-prefix=<placeholder>")
for module in $goModules; do
    pushd "$module" >/dev/null
    flags[${#flags[@]}-1]="--path-prefix=${module}"
    golangci-lint run "${flags[@]}" || statuscode=$?
    popd >/dev/null
done

exit $statuscode
