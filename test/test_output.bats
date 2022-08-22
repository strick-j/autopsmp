#!/usr/bin/env bats

load test_helper
load 'libs/bats-assert/load'
load 'libs/bats-support/load'
load 'libs/bats-file/load'

main_script="$BATS_TEST_DIRNAME/../src/main.sh"
source "$main_script"

@test "write_to_terminal() success" {
    run write_to_terminal "test"
    assert_success
    assert_output "test"
}

@test "write_log() success" {
    run write_log "test"
    assert_exists "$VAR_INSTALL_LOG_F"   
}
