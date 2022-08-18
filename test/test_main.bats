#!/usr/bin/env bats

load _test_helper

MAINSCRIPT="$BATS_TEST_DIRNAME/../src/main.sh"

@test "TestMain: must be executable" {
    existsAndExecutable "$MAINSCRIPT"
}
