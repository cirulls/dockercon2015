#!/bin/bash
echo "Load environment variable"
# find public IP address
alias myip='curl -s "http://checkip.dyndns.org/" | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | head -1'

# set SERVER environment variable according to public IP address
case $(myip) in
    54.123.45.678 ) SERVER="dev"
        ;;
    52.234.56.789 ) SERVER="stage"
        ;;
    52.345.67.890 ) SERVER="live"
        ;;
    * ) SERVER=""
        ;;
esac

# build api container
if [ $# -eq 0 ]
then docker build -t platform_api:latest .
else 
    docker build -t platform_api:$1 .
    docker tag -f platform_api:$1 platform_api:latest
fi

# stop and restart docker api container
cd $WORKSPACE && ./manage-leap-components.sh --operation stop --server $SERVER --component api
cd $WORKSPACE && ./manage-leap-components.sh --operation start --server $SERVER --component api    
