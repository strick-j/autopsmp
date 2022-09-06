#!/usr/bin/env bats

load test_helper
load 'libs/bats-assert/load'
load 'libs/bats-support/load'
load 'libs/bats-file/load'

MAINSCRIPT="${BATS_TEST_DIRNAME}/../src/main.sh"
source "$MAINSCRIPT"

setup() {
  tmp_dir="${BATS_TEST_DIRNAME}/tmp/tmp_dir"
  tmp_var_dir="${BATS_TEST_DIRNAME}/tmp/tmp_dir/var_tmp"
  tmp_vault_ini="vault.ini"
  tmp_psmpparms="psmpparms.sample"
  tmp_createcredfile="CreateCredFile"
  
  # Create test directory
  mkdir $tmp_dir
  mkdir $tmp_var_dir

  export CYBR_DIR="$tmp_dir"
  export VAR_TMP_D="$tmp_var_dir"
}

@test "create_vault_ini() - success" {
  skip
  # Create vault.ini file using helper
  helper_vaultini 
  run create_vault_ini
  # Validate backup file was created
  assert_exists "$tmp_dir/vault.ini.bak"
  # TODO: Check actual text in file
  # 
  assert_output "Completed vault.ini file modifications, proceeding..."  
}

@test "create_vault_ini() - vault.ini not found" {
  rm -f $tmp_vault_ini
  run create_vault_ini
  assert_failure
}

@test "create_credfile() - success" {
  skip
  # Create CreateCredFile utility using helper
  helper_createcredfile
  assert_success
}

@test "create_credfile() - CreateCredFile utility not found" {
  rm -f $tmp_creatcredfile
  run create_credfile
  assert_failure
}

@test "create_psmpparms() - success - CYBERARKSSHD=Integrated - ENABLEADBRIDGE=1" {
  skip
  export CYBERARKKSSHD="Integrated"
  export ENABLEADBRIDGE=1
  # Create psmpparms.sample file using helper
  helper_psmpparms
  assert_exists "$tmp_dir/psmpparms.sample"
  run create_psmpparms
  assert_exists "$tmp_var_dir/psmpparms"
  # TODO: Check actual text in file
  assert_success
}

@test "create_psmpparms() - success - CYBERARKSSHD=Integrated - ENABLEADBRIDGE=0" {
  skip
  export CYBERARKKSSHD="Integrated"
  export ENABLEADBRIDGE=0
  # Create psmpparms.sample file using helper
  helper_psmpparms
  assert_exists "$tmp_dir/psmpparms.sample"
  run create_psmpparms
  assert_exists "$tmp_var_dir/psmpparms"
  # TODO: Check actual text in file
  assert_success
}

@test "create_psmpparms() - success - CYBERARKSSHD=Yes - ENABLEADBRIDGE=1" {
  skip
  export CYBERARKKSSHD="Yes"
  export ENABLEADBRIDGE=1
  # Create psmpparms.sample file using helper
  helper_psmpparms
  assert_exists "$tmp_dir/psmpparms.sample"
  run create_psmpparms
  assert_exists "$tmp_var_dir/psmpparms"
  # TODO: Check actual text in file
  assert_success
}

@test "create_psmpparms() - success - CYBERARKSSHD=Yes - ENABLEADBRIDGE=0" {
  skip
  export CYBERARKKSSHD="Yes"
  export ENABLEADBRIDGE=0
  # Create psmpparms.sample file using helper
  helper_psmpparms
  assert_exists "$tmp_dir/psmpparms.sample"
  run create_psmpparms
  assert_exists "$tmp_var_dir/psmpparms"
  # TODO: Check actual text in file
  assert_success
}

@test "create_psmpparms() - success - CYBERARKSSHD=No - ENABLEADBRIDGE=1" {
  skip
  export CYBERARKKSSHD="No"
  export ENABLEADBRIDGE=1
  # Create psmpparms.sample file using helper
  helper_psmpparms
  assert_exists "$tmp_dir/psmpparms.sample"
  run create_psmpparms
  assert_exists "$tmp_var_dir/psmpparms"
  # TODO: Check actual text in file
  assert_success
}

@test "create_psmpparms() - success - CYBERARKSSHD=No - ENABLEADBRIDGE=0" {
  skip
  export CYBERARKKSSHD="No"
  export ENABLEADBRIDGE=0
  # Create psmpparms.sample file using helper
  helper_psmpparms
  assert_exists "$tmp_dir/psmpparms.sample"
  run create_psmpparms
  assert_exists "$tmp_var_dir/psmpparms"
  # TODO: Check actual text in file
  assert_success
}

@test "create_psmpparms() - psmpparms.sample not found" {
  rm -f $tmp_psmpparms
  run create_psmpparms
  assert_failure
}


