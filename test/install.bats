#!/usr/bin/env bats

load test_helper
load 'libs/bats-assert/load'
load 'libs/bats-support/load'
load 'libs/bats-file/load'

MAINSCRIPT="$BATS_TEST_DIRNAME/../src/main.sh"
source "$MAINSCRIPT"

@test "install_psmp() - rpm not found" {
  run install_psmp
  assert_line --index 2 --partial 'PSMP rpm install file not found, verify needed files have been copied over. Exiting now...'
}

@test "install_psmp() - rpm found - mock install" {
  tmp_dir="$BATS_TEST_DIRNAME/tmp/tmp_dir"
  tmp_file="CARKpsmp-12.06.0.26.x86_64.rpm"
  mkdir $tmp_dir
  touch $tmp_dir/$tmp_file
  export CYBR_DIR="$tmp_dir"
  function rpm() { echo "Install successful"; }
  export -f rpm
  run install_psmp
  assert_line --index 4 --partial 'PSMP install complete, proceeding...'
}

@test "install_psmp() - rpm found - dryrun - no install" {
  tmp_dir="$BATS_TEST_DIRNAME/tmp/tmp_dir"
  tmp_file="CARKpsmp-12.06.0.26.x86_64.rpm"
  mkdir $tmp_dir
  touch $tmp_dir/$tmp_file
  export CYBR_DIR="$tmp_dir"
  export DRYRUN=1
  run install_psmp
  assert_line --index 3 --partial 'Skipping installation for dryrun, proceeding...'
}
