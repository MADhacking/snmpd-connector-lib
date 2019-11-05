#!/usr/bin/env bats

# Include snmpd-connector-lib.sh or die.
source usr/lib/snmpd-connector-lib.sh

# Load bats modules
load '/usr/lib/bats-support/load.bash'
load '/usr/lib/bats-assert/load.bash'


function test_run_echo_output
{
    MSG="\"${1}\" = "
    OUTPUT="$(${1})"
    MSG+="\"${OUTPUT}\""
    echo "${MSG}"
}

function test_walk_oids
{
    LASTOID=""
    NEXTOID=$(get_next_oid "#RTABLE" "${BASE_OID}")
    echo "${NEXTOID}"
    
    while [[ -n "${NEXTOID}" && "${NEXTOID}" != "${LASTOID}" ]]; do
        LASTOID="${NEXTOID}"
        split_request_oid "${BASE_OID}" "${NEXTOID}" RARRAY
        #echo "get_next_oid #RTABLE ${BASE_OID} ${RARRAY[@]}" >&2
        NEXTOID=$(get_next_oid "#RTABLE" "${BASE_OID}" "${RARRAY[@]}")
        echo "${NEXTOID}"
    done
}

# Function to get the next index value
#
#   @in_param   $1 - The (optional) starting index value
#   @echo          - The new index or nothing if out of range
#
function get_next_index
{
    debug_function_enter "get_next_index" ${@}
    
    # If we still have more than one element in the request array then something
    # is wrong so log an error and return 0.
    if (( $# > 1 )); then
        error_echo "get_next_index: called with $# request array elements!"
        debug_function_return
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
            debug_function_return
            return
        else
            debug_echo "next index would be out of range, returning nothing"
            debug_function_return
            return
        fi 
    fi  
    
    # If we got this far then we were not passed an index so return the first
    # available index.
    debug_echo "no index supplied, returning first index"
    echo "1"
    debug_function_return
    return
}

# Configure a nice obvious base OID.
BASE_OID="p.q.r"

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

@test "test_walk_oids" {
    run test_walk_oids
    
    assert_success
}

