#!/usr/bin/env bash

export TMP="$BATS_TEST_DIRNAME/tmp"

setup() {
  mkdir -p "${TMP}"
  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  PATH="$DIR/../src:$PATH"
}

teardown() {
  rm -rf "${TMP:?}"/*
  rm -rf '/var/tmp/autopsmp_install.log'
}

function helper_vaultini() {
  touch "${TMP}/tmp_dir/vault.ini"
  cat << EOF > "${TMP}/tmp_dir/vault.ini"
VAULT="Demo Vault"
ADDRESS=1.1.1.1
PORT=1858
TIMEOUT=10
EOF
}

function helper_createcredfile() {
  touch "${TMP}/tmp_dir/CreateCredFile"
}

function helper_psmpparms() {
  touch "${TMP}/tmp_dir/psmpparms.sample"
  cat << EOF > "${TMP}/tmp_dir/psmpparms.sample"
[Main]
InstallationFolder=<Folder Path>
InstallCyberArkSSHD=Integrated
Hardening=Yes
AcceptCyberArkEULA=No
#EnableADBridge=Yes
EOF
}
