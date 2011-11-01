# Function to quit with error
# 
#	@in_param	$1 - The error message to die with
#
function die
{
	logger -p local1.error "ERROR: ${1}"
	echo "ERROR: ${1}" >&2
	exit
}

function error_echo
{
	echo "${@}" >&2
}

function debug_echo
{
[[ -n ${DEBUG} ]] && error_echo "debug: ${@}"
}

function echo_array
{
	RA=($@)
	for i in `seq 0 $(( ${#RA[@]} - 1 ))`; do
    	echo -n "RA[$i]=\"${RA[i]}\" "
	done
	echo
}

# Functions to handle request types
function handle_ping
{
	echo "PONG"
}

# Function to handle an unknown query
#
#	@in_param	$1 - The query type.
#
function handle_unknown_query
{
	echo "ERROR [Unknown Query]"
	[[ -n ${DEBUG} ]] && logger -p local1.warn "Unknown query: ${1}"
}

# Function to handle a query for an unknown OID
#
#	@in_param	$1 - The OID this query was for.
#
function handle_unknown_oid
{
	echo "NONE"
	[[ -n ${DEBUG} ]] && logger -p local1.warn "GET request for unknown OID: ${1} (RTYPE out of range)"
}

# Function to handle a SET request.
#
function handle_set
{
	local OID VALUE
	
	read OID
	read VALUE
	echo "not-writable"
	[[ -n ${DEBUG} ]] && logger -p local1.warn "Attempt to SET ${OID} to ${VALUE}"
}

# Function to get the request OID
#
function get_request_oid
{
	local TOID
	
	# Read the OID this request is for
	read TOID
	eval $1=${TOID} 
}

# Function to split the requested OID into component parts
#
#	@in_param	$1 - The base OID which this should be a request for
#	@in_param	$2 - The OID to split
#	@out_param	$3 - An array containing the request elements 
#
function split_request_oid
{	
	local ROID RFA BWD 

	# If the requested OID doesn't start with our base OID then we're done already.
	if [[ "${2}" != ${1}* ]]; then
		echo "NONE"
		[[ -n ${DEBUG} ]] && logger -p local1.warn "unknown base OID: ${2}"
		return 1
	fi
		
	# Split off our BASE_OID to get a R[elative]OID and then remove the leading "." of that ROID.
	BWD="${1}" 
	ROID=${2#${BWD}}
	ROID=${ROID#.}

	# If we got no R[elative]OID then we're done already.
	[[ -z "${ROID}" ]] && return 2

	# Split the ROID around the dots to get the fields for this request to get a R[equest]F[ield]A[rray].
	IFS="."
	RFA=(${ROID})
	unset IFS

	# If we got some array elements then place them in $3 and indicate success
	if (( ${#RFA[@]} > 0  )); then
		eval "$3=(${RFA[@]})"
		return
	fi
	
	# Indicate failure.
	return 3 
}

# Function to get and split the request OID
#
#	@in_param	$1 - The base OID to split off first
#	@out_param	$2 - The complete OID
#	@out_param	$3 - An array containing the request elements
#
function get_and_split_request_oid
{
	local TOID RAY=""
	
	# Read the OID this request is for
	read TOID
	
	# If we were passed an empty string then we're done already.
	[[ -z "${TOID}" ]] && return 1
	
	eval "$2=\"${TOID}\""
	split_request_oid $1 ${TOID} RAY
	[[ $? ]] && eval "$3=(${RAY[@]})" || return 2
}

# Helper function to send an integer - called: send_integer OID value
#
#	@in_param	$1 - The OID to send before the data
#	@in_param	$2 - The VALUE to send
#
function send_integer
{
[[ -n ${DEBUG} ]] && logger -p local1.info "Sent ${1} INTEGER ${2}"
	echo ${1}
	echo "integer"
	echo ${2}
}

# Helper function to send an integer - called: send_boolean OID value
#
#	@in_param	$1 - The OID to send before the data
#	@in_param	$2 - The VALUE to send (T for true, F for false)
#
function send_boolean
{
	[[ -n ${DEBUG} ]] && logger -p local1.info "Sent ${1} TruthValue ${2}"
	echo ${1}
	echo "integer"
	[[ ${2} == "T" ]] && echo 1 || echo 2
}

# Helper function to send a string - called: send_string OID value
#
#	@in_param	$1 - The OID to send before the data
#	@in_param	$2 - The VALUE to send
#
function send_string
{
	[[ -n ${DEBUG} ]] && logger -p local1.info "Sent ${1} STRING ${2}"
	echo ${1}
	echo "string"
	echo ${2}
}

# Helper function to send a gauge - called: send_gauge OID value
#
#	@in_param	$1 - The OID to send before the data
#	@in_param	$2 - The VALUE to send
#
function send_gauge
{
	[[ -n ${DEBUG} ]] && logger -p local1.info "Sent ${1} GAUGE ${2}"
	echo ${1}
	echo "gauge"
	echo ${2}
}

# Function to handle GETNEXT requests
#
#	@in_param	$1 - The OID this is a request for
#	@in_param	$2 - The base OID this is a request for
#	@in_param	$+ - An array containing the request elements
#
function handle_getnext
{
	echo "handle_getnext : ${@}"
	
	local BOID SOID RA COMMAND

	SOID=${1}
	shift
	BOID=${1}
	shift
	RA=(${@})

	# If we have an empty array 
	

	return

	# If the ROID starts with...
	case ${RTYPE} in
		0) # It is a base query so send the OID of the first index value
		OID=${1}1.1
		[[ -n ${DEBUG} ]] && logger -p local1.info "GETNEXT request passed to handle_get with new OID: ${OID}"
		handle_get
		;;
		
		*) # It is a normal query so...
		# If the next index is in range send the next OID...
		NINDEX=$((${RINDEX} + 1))
		if (( ${NINDEX} <= ${#DEVICES[@]} )); then
			OID=${1}${RTYPE}.${NINDEX}
			[[ -n ${DEBUG} ]] && logger -p local1.info "GETNEXT request passed to handle_get with new OID: ${OID}"
			handle_get
		else
			# ...otherwise send the next range if it is within this MIB or NONE
			NTYPE=$((${RTYPE} + 1))
		if (( ${NTYPE} <= ${#FTABLE[@]} )); then
				OID=${1}${NTYPE}.1
				[[ -n ${DEBUG} ]] && logger -p local1.info "GETNEXT request passed to handle_get with new OID: ${OID}"
				handle_get
			else
				echo "NONE"
			fi
		fi
		;;
	esac
}

# Function to handle GET requests
#
#	@in_param	$1 - The OID to send along with this request
#	@in_param	$2 - The base OID this is a request for
#	@in_param	$+ - An array containing the request elements
#
function handle_get
{
	echo "handle_get : ${@}"
	
	local BOID SOID RA COMMAND

	SOID=${1}
	shift
	BOID=${1}
	shift
	RA=(${@})

	# Check that a command is defined for this entry
	if [[ -z ${RTABLE[${RA[0]}]+defined} ]]; then
		echo "NONE"
		return
	fi	

	# Get the command from the root table
	COMMAND="${RTABLE[${RA[0]}]} ${SOID} ${BOID}.${RA[0]} ${RA[@]:1}"

	echo "COMMAND=\"${COMMAND}\""
	eval "${COMMAND}"
}

# Function to handle a table get request
#
#	@in_param	$1 - The name of the entry table
#	@in_param	$2 - The OID to send along with this request
#	@in_param	$3 - The base OID this is a request for
#	@in_param	$+ - An array containing the remaining request elements
#
function handle_table_get
{
	echo "handle_table_get : ${@}"
	
	local BOID SOID TABLE RA COMMAND
	
	TABLE="${1}"
	shift
	SOID=${1}
	shift
	BOID=${1}
	shift
	RA=(${@})

	TABLE="${TABLE}[${RA[0]}]"

	# Get the command from the specified entry table
	COMMAND="${!TABLE} ${SOID} ${BOID}.${RA[0]} ${RA[@]:1}"
	echo COMMAND=${COMMAND}
	eval "${COMMAND}"
}

# Function to handle a table entry get request
#
#	@in_param	$1 - The name of the function table
#	@in_param	$2 - The OID to send along with this request
#	@in_param	$3 - The base OID this is a request for
#	@in_param	$+ - An array containing the remaining request elements
#
function handle_table_entry_get
{
	echo "handle_table_entry_get : ${@}"

	local BOID SOID TABLE RA COMMAND
	
	TABLE="${1}"
	shift
	SOID=${1}
	shift
	BOID=${1}
	shift
	RA=(${@})
	
	TABLE="${TABLE}[${RA[0]}]"
	
	# Get the command from the specified entry table
	COMMAND="${!TABLE} ${SOID} ${BOID}.${RA[0]} ${RA[@]:1}"
	echo COMMAND=${COMMAND}
	
	eval "${COMMAND}"
}

# Main functional loop
function the_loop
{
	# Declare local variables
	local QUIT QUERY BASE_OID OID RARRAY

	# Try to resolve the numeric base oid from the base mib.
	BASE_OID="$(${SNMP_TRANSLATE} -On ${BASE_MIB})"
	(( $? != 0 )) && die "Unable to resolve base OID from ${BASE_MIB}"
	
	# Loop until we are instructed to quit
	QUIT=0
	while (( ${QUIT} == 0 )); do
	
		# Get the SNMP query type and convert to lower case.
		read QUERY
		QUERY=${QUERY,,}
					
		# What kind of request is this?
		case ${QUERY} in
			"ping")				# Handle PING request
			handle_ping
			;;
			
			"quit"|"exit"|"")	# Handle QUIT or EXIT request
			echo "Bye"
			exit
			;;
			
			"get")				# Handle GET requests
			get_and_split_request_oid ${BASE_OID} OID RARRAY
			(( ${#RARRAY[@]} > 0)) && handle_get ${OID} ${BASE_OID} ${RARRAY[@]} || echo "NONE"
			;;
	
			"getnext")			# Handle GETNEXT requests
			get_and_split_request_oid ${BASE_OID} OID RARRAY
			(( ${#RARRAY[@]} > 0)) && RARRAY="${RARRAY[@]}" || RARRAY="" 
			handle_getnext ${OID} ${BASE_OID} ${RARRAY}
			;;
	
			"set")				# Handle SET requests
			handle_set
			;;
	
			*)					# Handle unknown commands
			handle_unknown_query ${QUERY}
			;;
		esac
		
	done
}