#!/bin/bash

SCRIPTNAME=`basename "$0"`
# get IP address of the machine running the script
MYIP=`curl -s http://whatismyip.akamai.com`

INTERACTIVE=1 # menu based interactive mode is the default mode unless parameters are supplied

# set an initial value for the flags/parameters
OPERATION=0 # -o --operation
COMPONENT=0 # -c --component
SERVER=0
OPERATION_LIST=( "build" "stop" "start" "debug" "access" "ps" "images" )
COMPONENT_LIST=( "api" "elasticsearch" "existdb" "graphdb" "jenkins" "kibana" "logstash" "tomcat" )
SERVER_LIST=( "dev" "stage" "live" )
declare -A SERVER_NAME=( ["52.123.45.678"]="dev" ["52.234.56.789"]="stage" ["52.345.67.890"]="live" )
declare -A AWS_IPS=( ["dev"]="ec2-52-123-45-678.compute-1.amazonaws.com" ["stage"]="ec2-52-234-56-789.compute-1.amazonaws.com" ["live"]="ec2-52-345-67-890.compute-1.amazonaws.com" )
declare -A AWS_FLASK_CONF=( ["dev"]="dockerdebug" ["stage"]="dockerdebug" ["live"]="dockerdebug" )
declare -A AWS_SWAGGER_FILTER=( ["dev"]="none" ["stage"]="internal" ["live"]="internal" )

# other docker utils
SEE_DOCKER=0 # to run the "docker ps [-a]" command

usage(){
    echo ""
    echo " Usage: $0 -soh [-c]"
    echo "" #where options are:"
    echo "    -s,--server <"${SERVER_LIST[*]}"> "
    echo "        mandatory parameter to indicate the server where deploying."
    echo "        dev, stage, and live will also change the IP/URL addresses in docker-compose-aws.yml"
    echo ""
    echo "    -o,--operation <"${OPERATION_LIST[*]}"> "
    echo "        mandatory parameter to indicate the operation required."
    echo "        build   -- build the image of one container or them all"
    echo "        stop    -- stop and remove the instance of one container or them all"
    echo "        start   -- start a container or them all"
    echo "        debug   -- start a container or them all and get STDOUT/STDERR in the terminal"
    echo "        access  -- start a container and access it. It enables to run bash commands. "
    echo "        ps      -- list running images or them all "
    echo "        images  -- list all existing images"
    echo ""
    echo "    -c,--component <"${COMPONENT_LIST[*]}"> "
    echo "        optional parameter to indicate the name of the component. "
    echo "        If none is provided, all the components will be built, stopped or started."
    echo ""
    echo "    -h,--help "
    echo "        This message. "
    echo ""
}


array_contains () { 
    local array="$1[@]"
    local seeking=$2
    local in=1
    for element in "${!array}"; do
        if [[ $element == $seeking ]]; then
            in=0
            break
        fi
    done
    return $in
}


update_aws_yaml_file() {
    NEWIP=${AWS_IPS["$SERVER"]}
	FLASKCONF=${AWS_FLASK_CONF["$SERVER"]}
	SWAGGER_FILTER=${AWS_SWAGGER_FILTER["$SERVER"]}
	
	# jenkins - IP
    sed -ri "s|HOSTNAME_URL ?= ?(.*)$|HOSTNAME_URL=http://$NEWIP|" docker-compose-aws.yml
	# elastic search IP
    sed -ri "s|ELASTICSEARCH_URL ?= ?(.*)$|ELASTICSEARCH_URL=http://$NEWIP:9200|" docker-compose-aws.yml  
	# api - FLASK_CONFIG
    sed -ri "s|FLASK_CONFIG ?= ?(.*)$|FLASK_CONFIG=$FLASKCONF|" docker-compose-aws.yml  
	# api - swagger filter
    sed -ri "s|python3 (.*py) (.*yaml) (.*json) (.*)$|python3 \1 \2 \3 $SWAGGER_FILTER \&\& \\\ |" api/Dockerfile
}


do_the_job() {
	# see docker containers
	if [ "$SEE_DOCKER" = 1 ]; then
		CMD="docker ps"
	elif [ "$SEE_DOCKER" = 2 ]; then
		CMD="docker ps -a"
	elif [ "$SEE_DOCKER" = 3 ]; then
		echo "It takes a while, be patient..."
		CMD="docker images"
	else
		update_aws_yaml_file
		SERVERFILE=docker-compose-aws.yml

		if [ "$COMPONENT" = "0" ]; then
			echo " Well done! You will "$OPERATION" all platform components on '"$SERVER"'. "
			if [ "$OPERATION" = "build" ]; then
			CMD="/usr/local/bin/docker-compose -p platform -f $SERVERFILE build"
			elif [ "$OPERATION" = "stop" ]; then
			CMD="/usr/local/bin/docker-compose -p platform -f $SERVERFILE stop -t 30" 
			elif [ "$OPERATION" = "start" ]; then
			CMD="/usr/local/bin/docker-compose -p platform -f $SERVERFILE up -d"
			fi
		else
			echo " Well done! You will "$OPERATION" the '"$COMPONENT"' component on '"$SERVER"'. "
			if [ "$OPERATION" = "build" ]; then
			CMD="/usr/local/bin/docker-compose -p platform -f $SERVERFILE build $COMPONENT"
			elif [ "$OPERATION" = "stop" ]; then
			CMD="/usr/local/bin/docker-compose -p platform -f $SERVERFILE stop -t 30 $COMPONENT && /usr/local/bin/docker-compose -p platform -f $SERVERFILE rm --force -v $COMPONENT"
			elif [ "$OPERATION" = "start" ]; then
			CMD="/usr/local/bin/docker-compose -p platform -f $SERVERFILE up --no-recreate -d $COMPONENT"
			elif [ "$OPERATION" = "debug" ]; then
			CMD="/usr/local/bin/docker-compose -p platform -f $SERVERFILE up --no-recreate $COMPONENT"
			elif [ "$OPERATION" = "access" ]; then
			CMD="/usr/local/bin/docker-compose -p platform -f $SERVERFILE run $COMPONENT /bin/bash"
			fi
		fi
    fi
	if [ "$INTERACTIVE" = "1" ]; then
		read -p "Command: $CMD 
 Continue [y/n]? " -n 1 -r 
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]
		then
			eval $CMD
		fi
	else
		echo " Command: $CMD "
		eval $CMD
	fi
	
}


determine_server_name(){
	# display type of environment in bash prompt
	SERVER=${SERVER_NAME["$MYIP"]}
	read -p "
The server is '$SERVER'. Use this one [y/n]? " -n 1 -r 
	echo
	if [[ $REPLY =~ ^[Nn]$ ]]
	then
		PS3='Please select the server: '
        options=("dev" "stage" "live")
		select opt in "${options[@]}"
		do
		case $opt in
			"dev")
				SERVER='dev'
				break
				;;
			"stage")
				SERVER='stage'
				break
				;;
			"live")
				SERVER='live'
				break
				;;
			*) echo "invalid option $opt";;
		esac
		done
	fi
}


select_component(){
		PS3='Please select the component: '
		componentoptions=("${COMPONENT_LIST[@]}")
		select copt in "${componentoptions[@]}"
		do
		case $copt in
			"existdb")
				COMPONENT='existdb'
				break
				;;
			"graphdb")
				COMPONENT='graphdb'
				break
				;;
			"elasticsearch")
				COMPONENT='elasticsearch'
				break
				;;
			"logstash")
				COMPONENT='logstash'
				break
				;;
			"tomcat")
				COMPONENT='tomcat'
				break
				;;
			"jenkins")
				COMPONENT='jenkins'
				break
				;;
			"api")
				COMPONENT='api'
				break
				;;
			"kibana")
				COMPONENT='kibana'
				break
				;;
			*) echo "invalid option $opt";;
		esac
		done
		
		array_contains COMPONENT_LIST $COMPONENT
		if [ "$?" = "1" ]; then
			echo " Value '"$COMPONENT"' for parameter '-c' is invalid!!" ; 
			echo " The valid values are: "${COMPONENT_LIST[*]}
			exit 1 
		fi
}

############################################# MAIN ####################################

# call usage function if no arguments supplied
if [[ $# -gt 0 ]]; then

    INTERACTIVE=0

    # read the options in the arguments
    args=$(getopt -o "s:o:c:h" --long "server:,operation:,component:" -- "$@")

    if [[ $? -ne 0 ]]; then # getopt reported failure
	    usage
	    exit 1
    fi
    
    eval set -- "$args"
    
    # extract options and their arguments into variables.
    while [ $# -ge 1 ]; do
	case "$1" in
	    --)
            # No more options left.
            shift
            break
    		;;
	    
        -s|--server)
		    SERVER="$2"
		    shift
		    shift
		    ;;
	    
        -c|--component)
		    COMPONENT="$2"
		    shift
		    shift
		    ;;
	    
        -o|--operation)
		    OPERATION="$2"
		    shift
		    shift 
		    ;;
        -h)
		    usage
		    exit 0
		    ;;
        *) 
		    echo " Invalid option '$1'!!" ; 
		    usage
		    exit 1 
		    ;;
	esac    
    done

    # check out the server parameter
    if [ "$OPERATION" != "ps" -a "$OPERATION" != "images" -a "$SERVER" = "0" ]; then
        echo " Server parameter is missing!!" ; 
	    usage
	    exit 1 
    fi
    array_contains SERVER_LIST $SERVER
    if [ "$?" = "1" ]; then
        echo " Value '"$SERVER"' for parameter '-s' is invalid!!" ; 
        usage
        exit 1 
    fi


    # check out the operation parameter
    if [ "$OPERATION" = "0" ]; then
	    echo " Operation parameter is missing!!" ; 
	    usage
	    exit 1 
    else
	    array_contains OPERATION_LIST $OPERATION
	    if [ "$?" = "1" ]; then
	        echo " Value '"$OPERATION"' for parameter '-o' is invalid!!" ; 
	        usage
	        exit 1 
	    fi
        #SEE DOCKER 
	    if [ "$OPERATION" = "ps" ]; then
            SEE_DOCKER=1
        elif [ "$OPERATION" = "images" ]; then
            SEE_DOCKER=3
	    fi
    fi
    

    # check out the component parameter
    if [ "$OPERATION" = "debug" -o "$OPERATION" = "debug" ]; then
        if [ "$COMPONENT" = "0" ]; then # it is required when debug operation is set
    	    echo " Component parameter is required for 'debug' operation. It is missing!!" ; 
            usage
            exit 1 
        fi
    fi
    if [ "$COMPONENT" != "0" ]; then
        array_contains COMPONENT_LIST $COMPONENT
        if [ "$?" = "1" ]; then
            echo " Value '"$COMPONENT"' for parameter '-c' is invalid!!" ; 
            usage
            exit 1 
        fi
    fi  
	
	do_the_job


####### end of command line mode    

else ################################################### interactive mode
    echo
    echo '    If you want to run the non-interactive command-line version, use "'$SCRIPTNAME' --help"'
	while :
	do
		# initialize variables
		OPERATION=0 # -o --operation
		COMPONENT=0 # -c --component
		SERVER=0
		SEE_DOCKER=0 # tu run the "docker ps [-a]" command
	
		echo     
		PS3='Please enter your choice: '
		options=("Stop Component" "Stop Platform" "Build Component" "Build Platform" "Start Component" "Start Platform" "Debug Component" "Access Container" "List running docker containers" "List running and exited docker containers" "List docker images" "Quit")
		select opt in "${options[@]}"
		do
		case $opt in
			"Stop Component")
				#read -p "Stop a single component. Please write the component name: " COMPONENT
				OPERATION='stop'
				echo "
				Stop a single component.
				"
				select_component
				break
				;;

			"Stop Platform")
				OPERATION='stop'
				COMPONENT=0
				break
				;;
				
			"Build Component")
				#read -p "Build a single component. Please write the component name: " COMPONENT
				OPERATION='build'
				echo "
				Build a single component.
				"
				select_component
				break
				;;

			"Build Platform")
				OPERATION='build'
				COMPONENT=0
				break
				;;

			"Start Component")
				#read -p "Start a single component. Please write the component name: " COMPONENT
				OPERATION='start'
				echo "
				Start a single component.
				"
				select_component
				break
				;;

			"Start Platform")
				OPERATION='start'
				COMPONENT=0
				break
				;;

			"Debug Component")
				#read -p "This option runs a component without the -d options. Please write the component name: " COMPONENT
				OPERATION='debug'
				echo "
				This option runs a component without the -d option.
				"
				select_component
				break
				;;

			"Access Container")
				#read -p "This option runs and access into a container with /bin/bash. Please write the component name: " COMPONENT
				OPERATION='access'
				echo "
				This options runs and access into a container with /bin/bash.
				"
				select_component
				break
				;;

			"List running docker containers")
				SEE_DOCKER=1
				break
				;;

			"List running and exited docker containers")
				SEE_DOCKER=2
				break
				;;

			"List docker images")
				SEE_DOCKER=3
				break
				;;

			"Quit")
				exit 0
				;;

			*) echo invalid option;;

		esac
		done

		if [ "$SEE_DOCKER" = "0" ]; then
			determine_server_name
		fi
		
		do_the_job
	done
fi


exit 0
