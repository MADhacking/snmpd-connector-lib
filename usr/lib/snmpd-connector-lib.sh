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
	# Read the OID this request is for
	read OID
}

# Function to split the requested OID into component parts
#
#	@param	$1 - The BASE_OID which this should be a request for
#	@param	$2 - The OID to split
#	@return	$3 - The R[equest]TYPE
#	@return $4 - The R[equest]INDEX  
#
function split_request_oid
{	
	local ROID RFA 
	
	# Split off our BASE_OID to get a R[elative]OID. 
	ROID=${2#$1}

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

	(( ${#RFA[@]} == 1 )) && logger -p local1.info "split ROID: ${ROID} (and RTYPE: ${RFA[0]}) from OID: ${2}"
	(( ${#RFA[@]} > 1  )) && logger -p local1.info "split ROID: ${ROID} (and RTYPE: ${RFA[0]} RINDEX: ${RFA[1]}) from OID: ${2}"

	# Prepare R[equest]TYPE and R[equest]INDEX variables for easier use.
	eval $3=${RFA[0]}
	(( ${#RFA[@]} > 1  )) && eval $4=${RFA[1]} || eval $4=-1
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
#	$2 - The VALUE to send
#
function send_boolean
{
	[[ -n ${DEBUG} ]] && logger -p local1.info "Sent ${1} TruthValue ${2}"
	echo ${1}
	echo "integer"
	echo ${2}
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

function handle_getnext
{
	[[ -n ${DEBUG} ]] && logger -p local1.info "GETNEXT request for OID: ${OID}"
	
	local RTYPE RINDEX
	
	# Split the requested OID to get the R[equest]TYPE and R[equest]INDEX
	split_request_oid ${BASE_OID} ${OID} RTYPE RINDEX
		
	# If the ROID starts with...
	case ${RTYPE} in
		0) # It is a base query so send the OID of the first index value
		OID=${BASE_OID}1.1
		[[ -n ${DEBUG} ]] && logger -p local1.info "GETNEXT request passed to handle_get with new OID: ${OID}"
		handle_get
		;;
		
		*) # It is a normal query so...
		# If the next index is in range send the next OID...
		NINDEX=$((${RINDEX} + 1))
		if (( ${NINDEX} <= ${#DEVICES[@]} )); then
			OID=${BASE_OID}${RTYPE}.${NINDEX}
			[[ -n ${DEBUG} ]] && logger -p local1.info "GETNEXT request passed to handle_get with new OID: ${OID}"
			handle_get
		else
			# ...otherwise send the next range if it is within this MIB or NONE
			NTYPE=$((${RTYPE} + 1))
		if (( ${NTYPE} <= ${#FTABLE[@]} )); then
				OID=${BASE_OID}${NTYPE}.1
				[[ -n ${DEBUG} ]] && logger -p local1.info "GETNEXT request passed to handle_get with new OID: ${OID}"
				handle_get
			else
				echo "NONE"
			fi
		fi
		;;
	esac
}

function handle_get
{
	[[ -n ${DEBUG} ]] && logger -p local1.info "GET request for OID: ${OID}"
	
	local RTYPE RINDEX
	
	# Split the requested OID to get the R[equest]TYPE and R[equest]INDEX
	split_request_oid ${BASE_OID} ${OID} RTYPE RINDEX
	
	# Get the command from the function table
	COMMAND="${FTABLE[RTYPE]}"
	
	# If there is a function table entry...
	if [[ ! -z 	${COMMAND} ]]; then
		local RCOMMAND
		
		# Do string replacement
		do_string_replace "${COMMAND}" ${RTYPE} ${RINDEX} RCOMMAND
		RCOMMAND=${RCOMMAND/"%o"/${OID}}
				
		# Call it
		eval "${RCOMMAND}"
	else
		# Send an error.
		handle_unknown_oid ${OID}
	fi
}

# Main functional loop
function the_loop
{
	# Declare local variables
	local QUIT QUERY
	
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
			get_request_oid
			handle_get
			;;
	
			"getnext")			# Handle GETNEXT requests
			get_request_oid
			handle_getnext
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