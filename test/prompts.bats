#!/usr/bin/env bats

load test_helper
load 'libs/bats-assert/load'
load 'libs/bats-support/load'
load 'libs/bats-file/load'

MAINSCRIPT="$BATS_TEST_DIRNAME/../src/main.sh"
source "$MAINSCRIPT"

@test "accept_eula() accepts 1" {
  run accept_eula <<< '1'
  assert_success
  assert_output --partial 'proceeding' 
}

@test "accept_eula() reprompt until valid choice" {
  run accept_eula <<< '01'
  assert_success
  assert_output --partial 'proceeding'
}

@test "accept_eula() accepts 2 and exits" {
  run accept_eula <<< '2'
  assert_failure
  assert_output --partial 'exiting'
}

@test "enable_ad_bridge() accepts 1" {
  run enable_ad_bridge <<< '1'
  assert_success
  assert_output --partial 'proceeding'
}

@test "enable_ad_bridge() reprompt until valid choice" {
  run enable_ad_bridge <<< '01'
  assert_success
  assert_output --partial 'proceeding'
}

@test "enable_ad_bridge() accepts 2 and proceeds" {
  run enable_ad_bridge <<< '2'
  assert_success
  assert_output --partial 'proceeding'
}

@test "dir_prompt() success" {
  temp_dir="$BATS_TEST_DIRNAME/tmp/temp_dir"
  mkdir $temp_dir
  run dir_prompt <<< $temp_dir
  assert_output --partial 'proceeding'
}

@test "dir_prompt() directory not found, user exit" {
  run dir_prompt <<< "WrongDirectory
2"
  assert_failure
  assert_output --partial 'exiting'
}

@test "dir_prompt() directory not found, retry, success" {
  temp_dir="$BATS_TEST_DIRNAME/tmp/temp_dir"
  mkdir $temp_dir
  run dir_prompt <<< "WrongDirectory
1
$temp_dir"
  assert_output --partial 'proceeding'
}

@test "dir_prompt() repeated directory not found, 2x retry, success" {
  temp_dir="$BATS_TEST_DIRNAME/tmp/temp_dir"
  mkdir $temp_dir
  run dir_prompt <<< "WrongDirectory
1
WrongDirectoryAgain
1
$temp_dir"
  assert_output --partial 'proceeding'
}

@test "address_prompt() valid address" {
  valid_ip="192.168.100.1"
  run address_prompt <<< $valid_ip
  assert_output --partial 'proceeding'
}

@test "address_prompt() invalid address (1.1.256.0), user exit" {
  invalid_ip="1.1.256.0"
  run address_prompt <<< "$invalid_ip
2"
  assert_failure
}

@test "address_prompt() invalid address (1.1.2456), user exit" {
  invalid_ip="1.1.2456"
  run address_prompt <<< "$invalid_ip
2"
  assert_failure
}

@test "address_prompt() invalid address, retry, success" {
  valid_ip="192.168.100.1"
  invalid_ip="300.168.100.1"
  run address_prompt <<< "$invalid_ip
1
$valid_ip"
  assert_output --partial 'proceeding'
}

@test "input_confirm() confrim address, user selects proceed" {
  address_var="192.168.100.1"
  input_var="Address"
  run confirm_input $address_var $input_var <<< '1'
  assert_output --partial 'proceeding'
}

@test "input_confirm() confirm address, user selects change" {
  address_var="192.168.100.1"
  input_var="Address"
  run confirm_input $address_var $input_var <<< '2'
  assert_output --partial 'Requesting Vault IP'
}

@test "input_confirm() confirm username, user selects proceed" {
  uservar="sample_username"
  inputvar="Username"
  run confirm_input $uservar $inputvar <<< '1'
  assert_output --partial 'proceeding'
}

@test "input_confirm() confirm username, user selects change" {
  uservar="sample_username"
  inputvar="Username"
  run confirm_input $uservar $inputvar <<< '2'
  assert_output --partial 'Requesting Vault Username'
}

@test "mode_prompt() accepts 1 and proceeds" {
  run mode_prompt <<< '1'
  assert_success
  assert_output --partial 'proceeding'
}

@test "mode_prompt() accepts 2 and proceeds" {
  run mode_prompt <<< '2'
  assert_success
  assert_output --partial 'proceeding'
}

@test "mode_prompt() accepts 3 and proceeds" {
  run mode_prompt <<< '3'
  assert_success
  # TODO: Validate variable set properly
  assert_output --partial 'proceeding'
}

@test "mode_prompt() reprompt until valid choice" {
  run mode_prompt <<< '01'
  assert_success
  assert_output --partial 'proceeding'
}

@test "user_prompt() invalid username" {
  uservar="samplelongusername01samplelongusername02samplelongusername03samplelongusername04samplelongusername05samplelongusername06samplelongusername07"
  run username_prompt <<< $uservar
  assert_failure
}

@test "user_prompt() invalid username, retry, success" {
  invalid_user="username@#$\\@"
  valid_user="username"
  run username_prompt <<< "$invalid_user
1
$valid_user"
  assert_output --partial 'proceeding'
}

@test "pass_prompt() valid password" {
  pass1="test1234"
  pass2="test1234"
  run pass_prompt <<< "$pass1
$pass2"
  assert_output --partial 'proceeding'
}

@test "pass_prompt() password mismatch" {
  pass1="test1234"
  pass2="1234test"
  run pass_prompt <<< "$pass1
$pass2"
  assert_output --partial 'Please try again.'
}

@test "pass_prompt() password mismatch, retry, success" {
  pass1="test1234"
  pass2="1234test"
  run pass_prompt <<< "$pass1
$pass2
$pass1
$pass1"
  assert_output --partial 'proceeding'
}
