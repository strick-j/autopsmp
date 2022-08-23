#!/usr/bin/env bats

load test_helper
load 'libs/bats-assert/load'
load 'libs/bats-support/load'
load 'libs/bats-file/load'

MAINSCRIPT="${BATS_TEST_DIRNAME}/../src/main.sh"
source "$MAINSCRIPT"

setup() {
  tmp_dir="${BATS_TEST_DIRNAME}/tmp/tmp_dir"
  tmp_vault_ini="vault.ini"
  tmp_psmpparms="psmpparms.sample"
  tmp_createcredfile="CreateCredFile"
  
  # Create test directory
  mkdir $tmp_dir

  export INSTALLFILES="$tmp_dir"
  # /var/tmp by default, $BATS_TEST_DIRNAME/tmp/tmp_dir for testing
  #export TMPDIR="$tmp_dir"
}

@test "create_vault_ini() - success" {
  skip
  touch "$tmp_dir/$tmp_vault_ini"
  cat << EOF > $tmp_vault_ini
VAULT="Demo Vault"
ADDRESS=1.1.1.1
PORT=1858
TIMEOUT=10
EOF
  run create_vault_ini
  assert_output "Completed vault.ini file modifications, proceeding..."  
}

@test "create_vault_ini() - vault.ini not found" {
  rm -f $tmp_vault_ini
  run create_vault_ini
  assert_failure
}

@test "create_credfile() - CreateCredFile utility not found" {
  rm -f $tmp_creatcredfile
  run create_credfile
  assert_failure
}

@test "create_psmpparms() - psmpparms.sample not found" {
  rm -f $tmp_psmpparms
  run create_psmpparms
  assert_failure
}
