#!/usr/bin/env bats

load test_helper
load 'libs/bats-assert/load'
load 'libs/bats-support/load'
load 'libs/bats-file/load'

MAINSCRIPT="$BATS_TEST_DIRNAME/../src/main.sh"
source "$MAINSCRIPT"

@test "install_psmp() - rpm not found" {
  run install_psmp

  [[ "${lines[3]}" == "PSMP rpm install file not found, verify needed files have been copied over. Exiting now..." ]] 
  assert_failure
}

@test "install_psmp() - rpm found - dryrun - no install" {
  tmp_dir="$BATS_TEST_DIRNAME/tmp/tmp_dir"
  tmp_file="CARKpsmp-12.06.0.26.x86_64.rpm"
  mkdir $tmp_dir
  touch $tmp_dir/$tmp_file
  export INSTALLFILES="$tmp_dir"
  export DRYRUN=1
  run install_psmp
  assert_success
}
