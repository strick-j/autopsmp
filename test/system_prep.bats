#!./test/libs/bats/bin/bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup() {
    source "../autopsmp.sh"
    cd "$BATS_TEST_TEMPDIR"
}

@test "run 'autopsmp.sh' with SHOULD_SHOW_LOGS=1" {
    run WriteToTerminal "Success"
    echo $output
    assert_output "Success"
}

@test "run 'autopsmp.sh' with SHOULD_SHOW_LOGS=0" {
    run WriteToTerminal "Success"
    assert_output ""
}
