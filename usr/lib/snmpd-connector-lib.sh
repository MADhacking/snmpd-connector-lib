# Function to quit with error
# 
#	@param	$1 - The error message to die with
#
function die
{
	logger -p local1.error "ERROR: ${1}"
	echo "ERROR: ${1}" >&2
	exit
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
#	@param	$1 - The query type.
#
function handle_unknown_query
{
	echo "ERROR [Unknown Query]"
	[[ -n ${DEBUG} ]] && logger -p local1.warn "Unknown query: ${1}"
}

# Function to handle a query for an unknown OID
#
#	@param	$1 - The OID this query was for.
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
#	@param	$1 - The BASE_OID which this should be a request for
#	@param	$2 - The OID to split
#	@return	$3 - An array containing the request elements 
#
function split_request_oid
{	
	local ROID RFA BWD 
	
	# Split off our BASE_OID to get a R[elative]OID.
	BWD="${1}." 
	ROID=${2#${BWD}}

	# If the requested OID doesn't start with our base OID then we're done already.
	if [[ ${ROID} == ${2} ]]; then
		[[ -n ${DEBUG} ]] && logger -p local1.warn "unknown base OID: ${2}"
		echo "NONE"
		return
	fi

	# Split the ROID around the dots to get the fields for this request to get a R[equest]F[ield]A[rray].
	IFS="."
	RFA=(${ROID})
	unset IFS

	(( ${#RFA[@]} > 0  )) && eval "$3=(${RFA[@]})" 
}

# Function to get and split the request OID
#
#	@param	$1 - The BASE_OID to split off first
#	@return $2 - The complete OID
#	@return $3 - An array containing the request elements
#
function get_and_split_request_oid
{
	local TOID RAY
	
	# Read the OID this request is for
	read TOID
	
	if [[ -n "${TOID}" ]]; then
		eval "$2=\"${TOID}\""
		split_request_oid $1 ${TOID} RAY
		(( ${#RAY[@]} > 0  )) && eval "$3=(${RAY[@]})"
	fi 
}

# Helper function to send an integer - called: send_integer OID value
#
#	$1 - The OID to send before the data
#	$2 - The VALUE to send
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
#	$1 - The OID to send before the data
#	$2 - The VALUE to send (T for true, F for false)
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
#	$1 - The OID to send before the data
#	$2 - The VALUE to send
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
#	$1 - The OID to send before the data
#	$2 - The VALUE to send
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
#	$1 - The BASE_OID to handle requests for
#	$2 - The OID this request is for
#
function handle_getnext
{
	[[ -n ${DEBUG} ]] && logger -p local1.info "GETNEXT request for OID: ${OID}"
	
	local RTYPE RINDEX OID
	
	# Split the requested OID to get the R[equest]TYPE and R[equest]INDEX
	split_request_oid ${1} ${2} RTYPE RINDEX
		
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
#	@param	$1 - The OID to send along with this request
#	@param	$2 - The base OID this is a request for
#	@param	$+ - An array containing the request elements
#
function handle_get
{
	echo "handle_get : ${@}"
	
	local BOID SOID RA COMMAND

	BOID=${1}
	shift
	SOID=${1}
	shift
	RA=(${@})

	# Get the command from the root table
	COMMAND="${RTABLE[${RA[0]}]} ${SOID} ${BOID}.${RA[0]} ${RA[@]:1}"

	echo "COMMAND = \"${COMMAND}\""
	eval "${COMMAND}"
}

# Function to handle a table get request
#
#	@param	$1 - The name of the entry table
#	@param	$2 - The OID to send along with this request
#	@param	$3 - The base OID this is a request for
#	@param	$+ - An array containing the remaining request elements
#
function handle_table_get
{
	echo "handle_table_get : ${@}"
	
	local BOID SOID TABLE RA COMMAND
	
	TABLE=${1}
	shift
	BOID=${1}
	shift
	SOID=${1}
	shift
	RA=(${@})
	
	# Get the command from the specified entry table
	COMMAND="\${${TABLE}[${RA[0]}]} ${SOID} ${BOID}.${RA[0]} ${RA[@]:1}"
	eval "echo COMMAND=${COMMAND}"
	eval "${COMMAND}"
}

# Function to handle a table entry get request
#
#	@param	$1 - The name of the function table
#	@param	$2 - The OID to send along with this request
#	@param	$3 - The base OID this is a request for
#	@param	$+ - An array containing the remaining request elements
#
function handle_table_entry_get
{
	echo "handle_table_entry_get : ${@}"

	local BOID SOID TABLE RA COMMAND
	
	TABLE=${1}
	shift
	BOID=${1}
	shift
	SOID=${1}
	shift
	RA=(${@})
	
	# Get the command from the specified entry table
	COMMAND="\"\${${TABLE}[${RA[0]}]} ${SOID} ${BOID}.${RA[0]} ${RA[@]:1}\""
	eval "echo COMMAND=${COMMAND}"
	
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
			get_and_split_request_oid $BASE_OID OID RARRAY
			handle_get $BASE_OID ${OID} ${RARRAY[@]}
			;;
	
			"getnext")			# Handle GETNEXT requests
			get_and_split_request_oid $BASE_OID OID RARRAY
			handle_getnext $BASE_OID ${OID} ${RARRAY[@]}
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