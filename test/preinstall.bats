#!/usr/bin/env bats

load test_helper
load 'libs/bats-assert/load'
load 'libs/bats-support/load'
load 'libs/bats-file/load'

MAINSCRIPT="$BATS_TEST_DIRNAME/../src/main.sh"
source $MAINSCRIPT

@test "preinstall_infra() - rpm not found" {
  run preinstall_infra 
  assert_failure
}

@test "preinstall_infra() - rpm not found - naming error" {
  tmp_dir="${TMP}/tmp_dir"
  tmp_infra_dir="$BATS_TEST_DIRNAME/tmp/tmp_dir/IntegratedMode"
  tmp_file="CARKsmp-infra-12.06.0.26.x86_64.rpm"
  mkdir $tmp_dir
  mkdir $tmp_infra_dir
  touch $tmp_infra_dir/$tmp_file
  export CYBR_DIR=$tmp_dir
  run preinstall_infra
  assert_failure
}

@test "install_psmp() - rpm found - mock install" {
  tmp_dir="$BATS_TEST_DIRNAME/tmp/tmp_dir"
  tmp_infra_dir="$BATS_TEST_DIRNAME/tmp/tmp_dir/IntegratedMode"
  tmp_file="CARKpsmp-infra-12.06.0.26.x86_64.rpm"
  mkdir $tmp_dir
  mkdir $tmp_infra_dir
  touch $tmp_infra_dir/$tmp_file
  export CYBR_DIR="$tmp_dir"
  function rpm() { echo "Install successful"; }
  export -f rpm
  run preinstall_infra
  assert_line --index 3 --partial 'installed, proceeding...'
}

@test "preinstall_infra() - rpm found - dryrun - no install" {
  tmp_dir="$BATS_TEST_DIRNAME/tmp/tmp_dir"
  tmp_infra_dir="$BATS_TEST_DIRNAME/tmp/tmp_dir/IntegratedMode"
  tmp_file="CARKpsmp-infra-12.06.0.26.x86_64.rpm"
  mkdir $tmp_dir
  mkdir $tmp_infra_dir
  touch $tmp_infra_dir/$tmp_file
  export CYBR_DIR="$tmp_dir"
  export DRYRUN=1
  run preinstall_infra
  assert_success
}
