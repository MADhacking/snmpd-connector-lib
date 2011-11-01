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
	echo "error: ${@}" >&2
}

function debug_echo
{
	[[ -n "${DEBUG}" ]] && echo "debug: ${@}" >&2
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
	error_echo "ERROR [Unknown Query]"
	[[ -n ${DEBUG} ]] && logger -p local1.warn "Unknown query: ${1}"
}

# Function to handle a query for an unknown OID
#
#	@in_param	$1 - The OID this query was for.
#
function handle_unknown_oid
{
	echo "NONE"
	debug_echo "GET request for unknown OID: ${1}"
}

# Function to handle a SET request.
#
function handle_set
{
	local OID VALUE
	
	read OID
	read VALUE
	echo "not-writable"
	debug_echo "Attempt to SET ${OID} to ${VALUE}"
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
		debug_echo "unknown base OID: ${2}"
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

# Helper function to send NONE
#
#	@in_param	$1 - The (optional) OID to send before the data
#
function send_none
{
	if [[ -n "$1" ]]; then
		echo ${1}
		debug_echo "Sent [${1}] NONE"
	else
		debug_echo "Sent NONE"
	fi
	echo "NONE"
}

# Helper function to send an integer - called: send_integer OID value
#
#	@in_param	$1 - The OID to send before the data
#	@in_param	$2 - The VALUE to send
#
function send_integer
{
	debug_echo "Sent ${1} INTEGER ${2}"
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
	debug_echo "Sent ${1} TruthValue ${2}"
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
	debug_echo "Sent ${1} STRING ${2}"
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
	debug_echo "Sent ${1} GAUGE ${2}"
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
	debug_echo "handle_getnext : ${@}"
	
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
		debug_echo "GETNEXT request passed to handle_get with new OID: ${OID}"
		handle_get
		;;
		
		*) # It is a normal query so...
		# If the next index is in range send the next OID...
		NINDEX=$((${RINDEX} + 1))
		if (( ${NINDEX} <= ${#DEVICES[@]} )); then
			OID=${1}${RTYPE}.${NINDEX}
			debug_echo "GETNEXT request passed to handle_get with new OID: ${OID}"
			handle_get
		else
			# ...otherwise send the next range if it is within this MIB or NONE
			NTYPE=$((${RTYPE} + 1))
		if (( ${NTYPE} <= ${#FTABLE[@]} )); then
				OID=${1}${NTYPE}.1
				debug_echo "GETNEXT request passed to handle_get with new OID: ${OID}"
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
#	@in_param	$1 - The name of an array, prefixed with a #, from which to retrieve
#					 either the command to execute or the name of another array.
#	@in_param	$2 - The OID to send along with this request
#	@in_param	$3 - The base OID this is a request for
#	@in_param	$+ - An array containing the request elements
#
function handle_get
{
	debug_echo "handle_get : ${@}"
	
	local BOID SOID TABLE RA COMMAND

	# Extract parameters
	TABLE="${1}";	shift
	SOID="${1}";	shift
	BOID="${1}";	shift
	RA=(${@})

	# If we were not passed the name of a table in $1 then we're done so log an
	# error, send NONE and return.
	if [[ "${TABLE}" != \#* ]]; then
		error_echo "handle_get: parameter 1 is not a table!"
		send_none ${SOID}
		return 1
	fi  
	
	# If the R[equest]A[array] does not contain any elements then we're done so
	# log an error, send NONE and return.
	if (( ${#RA[@]} == 0 )); then
		error_echo "handle_get: R[equest]A[array] is empty already!"
		send_none ${SOID}
		return 1
	fi  

	# We were passed the name of a table so strip the leading #, make the variable
	# name.
	TABLE="${TABLE#\#}"
	TABLE="${TABLE}[${RA[0]}]"
	debug_echo "handle_get: calculated table variable: ${TABLE}"

	# Check that something is defined for this entry.  If it isn't log an error,
	# send NONE and return.
	if [[ -z ${!TABLE+defined} ]]; then
		debug_echo "handle_get: table entry is empty!"
		send_none ${SOID}
		return 1
	fi	

	# If the deferenced value of TABLE starts with a # then it is a redirect to
	# another table, if not it is a command.
	if [[ "${!TABLE}" == \#* ]]; then
		# We have another table.  Simply call handle_get with the new table name,
		# BOID and RA.
		handle_get ${!TABLE} ${SOID} ${BOID}.${RA[0]} ${RA[@]:1}	
	else
		# We have a command.  Get it from the table, add the SOID, new BOID and
		# remaining R[equest]A[array] and eval it.
		COMMAND="${!TABLE} ${SOID} ${BOID}.${RA[0]} ${RA[@]:1}"
		debug_echo "handle_get: found command in table: \"${COMMAND}\""
		eval "${COMMAND}"
	fi
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
			(( ${#RARRAY[@]} > 0)) && handle_get "#RTABLE" ${OID} ${BASE_OID} ${RARRAY[@]} || send_none ${OID}
			;;
	
			"getnext")			# Handle GETNEXT requests
			get_and_split_request_oid ${BASE_OID} OID RARRAY
			(( ${#RARRAY[@]} > 0)) && RARRAY="${RARRAY[@]}" || RARRAY="" 
			handle_getnext "#RTABLE" ${OID} ${BASE_OID} ${RARRAY}
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