#!/usr/bin/env bats

load test_helper
load 'libs/bats-assert/load'
load 'libs/bats-support/load'
load 'libs/bats-file/load'

MAINSCRIPT="$BATS_TEST_DIRNAME/../src/main.sh"
source "$MAINSCRIPT"

@test "clean_install() - success" {
  tmp_dir="$BATS_TEST_DIRNAME/tmp/tmp_dir"
  tmp_cred="user.cred"
  tmp_vault="vault.ini"
  tmp_createcred="CreateCredFile"
  mkdir $tmp_dir
  touch $tmp_dir/$tmp_cred
  touch $tmp_dir/$tmp_vault
  touch $tmp_dir/$tmp_parms
  export INSTALLFILES="$tmp_dir"
  run clean_install
  assert_success
}
