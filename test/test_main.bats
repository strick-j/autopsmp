#!/usr/bin/env bats

load test_helper
load 'libs/bats-file/load'
load 'libs/bats-assert/load'
load 'libs/bats-support/load'

bats_src="${BATS_TEST_DIRNAME}/../src"
main_script="${bats_src}/main.sh"
static_version="$(grep AUTOPSMP_VERSION "$main_script" | head -1 | cut -d'"' -f 2)"

@test "main.sh must be executable" {
    assert_file_executable "$main_script"
}

@test "run 'main.sh --version'" {
    run $main_script --version
    assert_equal "$output" "$static_version" 
}
