#!/usr/bin/env bats

load _test_helper
load 'libs/bats-assert/load'
load 'libs/bats-support/load'
load 'libs/bats-file/load'

MAINSCRIPT="$BATS_TEST_DIRNAME/../src/main.sh"
source "$MAINSCRIPT"

@test "TestOutput: WriteToTerminal" {
    run WriteToTerminal "test"

    assert_equal "$status" 0
    assert_output "test"
}

@test "TestOutput: WriteToLog" {
    run WriteLog "test"
    
    assert_exists var/tmp/psmp_install.log   
}
