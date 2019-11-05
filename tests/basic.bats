#!/usr/bin/env bats

# Include snmpd-connector-lib.sh or die.
source usr/lib/snmpd-connector-lib.sh

# Load bats modules
load '/usr/lib/bats-support/load.bash'
load '/usr/lib/bats-assert/load.bash'

# Function to get the next index value
#
#   @in_param   $1 - The (optional) starting index value
#   @echo          - The new index or nothing if out of range
#
function get_next_index
{
    # If we still have more than one element in the request array then something
    # is wrong so log an error and return 0.
    if (( $# > 1 )); then
        error_echo "get_next_index: called with $# request array elements!"
        return
    fi
    
    # If we were passed a starting index...
    if (( $# > 0 )); then
        # If the passed index is less than the number of devices then return it +1,
        # otherwise return 0 to indicate that the index would be out of range. 
        if (( ${1} < 4 )); then
            RETVAL=$(( ${1} + 1 ))
            debug_echo "next index is in range, returning ${RETVAL}"
            echo "${RETVAL}"
            return
        else
            debug_echo "next index would be out of range, returning nothing"
            return
        fi 
    fi  
    
    # If we got this far then we were not passed an index so return the first
    # available index.
    debug_echo "no index supplied, returning first index"
    echo "1"
    return
}

function func1
{
    send_string "${1}" "test ${2}"
}

function func2
{
    send_boolean "${1}" "T"
}

function func3
{
    send_integer "${1}" "1234"
}

function func4
{
    send_gauge "${1}" "45"
}

# Configure a nice obvious base OID.
BASE_OID="p.q.r"
BASE_MIB="example::test"

# Declare the tables
RTABLE[1]="#MIBOBJECTS1"
    MIBOBJECTS1[1]="#INFO"
        INFO_INDEX="get_next_index"
        INFO[1]="func1"
        INFO[2]="func2"
    MIBOBJECTS1[2]="#STATUS"
        STATUS[1]="func3"
        STATUS[2]="func4"
RTABLE[2]="#MIBOBJECTS2"
    MIBOBJECTS2[6]="func5"
    MIBOBJECTS2[7]="func6"
    MIBOBJECTS2[9]="func7"

#DEBUG="true"

# Mock for the snmptranslate command
function snmptranslate
{
    echo ".p.q.r"
}

@test "walk_oids" {
    function test_walk_oids
    {
        LASTOID=""
        NEXTOID=$(get_next_oid "#RTABLE" "${BASE_OID}")
        echo "${NEXTOID}"
        
        while [[ -n "${NEXTOID}" && "${NEXTOID}" != "${LASTOID}" ]]; do
            LASTOID="${NEXTOID}"
            split_request_oid "${BASE_OID}" "${NEXTOID}" RARRAY
            NEXTOID=$(get_next_oid "#RTABLE" "${BASE_OID}" "${RARRAY[@]}")
            echo "${NEXTOID}"
        done
    }

    run test_walk_oids
    
    assert_success
    assert_line --index 0 "p.q.r.1.1.1.1"
    assert_line --index 1 "p.q.r.1.1.1.2"
    assert_line --index 2 "p.q.r.1.1.1.3"
    assert_line --index 3 "p.q.r.1.1.1.4"
    assert_line --index 4 "p.q.r.1.1.2.1"
    assert_line --index 5 "p.q.r.1.1.2.2"
    assert_line --index 6 "p.q.r.1.1.2.3"
    assert_line --index 7 "p.q.r.1.1.2.4"
    assert_line --index 8 "p.q.r.1.2.1"
    assert_line --index 9 "p.q.r.1.2.2"
    assert_line --index 10 "p.q.r.2.6"
    assert_line --index 11 "p.q.r.2.7"
    assert_line --index 12 "p.q.r.2.9"
    assert_line --index 13 ""
}

@test "basic_loop" {
    run the_loop << 'END'
ping
quit
END

    assert_success
    assert_line --index 0 "PONG"
    assert_line --index 1 "Bye"
}

@test "unknown_query" {
    run the_loop << 'END'
fred
quit
END

    assert_success
    assert_line --index 0 "ERROR: ERROR [Unknown Query]"
    assert_line --index 1 "Bye"
}

@test "unknown_oid" {
    run the_loop << 'END'
get
.r.g.b.1.1.1.1
quit
END

    assert_success
    assert_line --index 0 "NONE"
    assert_line --index 1 ".r.g.b.1.1.1.1"
    assert_line --index 2 "NONE"
    assert_line --index 3 "N/A"
    assert_line --index 4 "Bye"
}

@test "set" {
    run the_loop << 'END'
set
.r.g.b.1.1.1.1
value
quit
END

    assert_success
    assert_line --index 0 "not-writable"
    assert_line --index 1 "Bye"
}


@test "get_string" {
    run the_loop << 'END'
get
.p.q.r.1.1.1.1
quit
END

    assert_success
    assert_line --index 0 ".p.q.r.1.1.1.1"
    assert_line --index 1 "string"
    assert_line --index 2 "test 1"
    assert_line --index 3 "Bye"
}

@test "get_boolean" {
    run the_loop << 'END'
get
.p.q.r.1.1.2.1
quit
END

    assert_success
    assert_line --index 0 ".p.q.r.1.1.2.1"
    assert_line --index 1 "integer"
    assert_line --index 2 "1"
    assert_line --index 3 "Bye"
}

@test "get_integer" {
    run the_loop << 'END'
get
.p.q.r.1.2.1
quit
END

    assert_success
    assert_line --index 0 ".p.q.r.1.2.1"
    assert_line --index 1 "integer"
    assert_line --index 2 "1234"
    assert_line --index 3 "Bye"
}

@test "get_gauge" {
    run the_loop << 'END'
get
.p.q.r.1.2.2
quit
END

    assert_success
    assert_line --index 0 ".p.q.r.1.2.2"
    assert_line --index 1 "gauge"
    assert_line --index 2 "45"
    assert_line --index 3 "Bye"
}

@test "get_next" {
    run the_loop << 'END'
getnext
.p.q.r.1.1.1.1
quit
END

    assert_success
    assert_line --index 0 ".p.q.r.1.1.1.2"
    assert_line --index 1 "string"
    assert_line --index 2 "test 2"
    assert_line --index 3 "Bye"
}
