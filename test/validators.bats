#!/usr/bin/env bats

load test_helper
load 'libs/bats-assert/load'
load 'libs/bats-support/load'
load 'libs/bats-file/load'

MAINSCRIPT="$BATS_TEST_DIRNAME/../src/main.sh"
source "$MAINSCRIPT"

@test "valid_username() valid username" {
  testusername=$(head /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 36)  
  run valid_username $testusername
  echo $output
  assert_output '0'
}

@test "valid_username() invalid username, length > 128" {
  testusername=$(head /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 129)  
  run valid_username $testusername
  assert_output '2'
}

@test "valid_username() invalid username, starts with ." {
  run valid_username ".InvalidUsername"
  assert_output '3'
}

@test "valid_username() invalid username, ends with ." {
  run valid_username "InvalidUsername."
  assert_output '3'
}

@test "valid_username() invalid username, starts with space" {
  run valid_username " InvalidUsername"
  assert_output '3'
}

@test "valid_username() invalid username, ends with space" {
  run valid_username "InvalidUsername "
  assert_output '3'
}

@test "valid_username() invalid username, invalid characters" {
  testusername=$(head /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9"$<>|' | head -c 36)
  invalidchars='|<>'
  usernameconcat="${testusername}${invalidchars}"
  run valid_username $usernameconcat
  assert_output '4' 
}

@test "valid_pass() valid password" {
  testpass=$(head /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9!"#$%&()*+,-./:;<=>?@[\]^_`{|}~' | head -c 18)  
  run valid_pass $testpass
  assert_output '0'
}

@test "valid_pass() invalid password, length > 39" {
  testpass=$(head /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9!"#$%&()*+,-./:;<=>?@[\]^_`{|}~' | head -c 40)  
  run valid_pass $testpass
  assert_output '1'
}

@test "valid_ip() valid IP" {
  run valid_ip '192.168.100.1'
  assert_output '0'
}

@test "valid_ip() invalid IP, IP out of range (192.168.100.256)" {
  run valid_ip '192.168.100.256'
  assert_output '1'
}

@test "valid_ip() invalid IP, incorrect format (192.168.100))" {
  run valid_ip '192.168.100'
  assert_output '1'
}
