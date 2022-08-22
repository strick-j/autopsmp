#!/usr/bin/env bash

export TMP="$BATS_TEST_DIRNAME/tmp"

setup() {
    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    # make executables in src/ visible to PATH
    PATH="$DIR/../src:$PATH"
}

teardown() {
    rm -rf "${TMP:?}"/*
    rm -rf '/var/tmp/autopsmp_install.log'
}

