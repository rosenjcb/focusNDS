#!/bin/bash
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <DEST_IP> <LOCATION_ID> <LOCATION_NAME>"
    exit 1
fi

DEST_IP=$1
LOCATION_ID=$2
LOCATION_NAME=$3

ssh root@$DEST_IP <<EOF
# Check if 'focus' config file exists, create if missing
if [ ! -f /etc/config/focus ]; then
    touch /etc/config/focus
fi

# Check if @settings[0] exists, create it if missing
if ! uci show focus.@settings[0] >/dev/null 2>&1; then
    uci add focus settings >/dev/null
fi

# Set values
uci set focus.@settings[0].LOCATION_ID=$LOCATION_ID
uci set focus.@settings[0].LOCATION_NAME="$LOCATION_NAME"
uci commit focus
EOF

echo "UCI values set on $DEST_IP"
