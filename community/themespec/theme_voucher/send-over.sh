# Default IP
DEST_IP=${1:-10.0.0.2}

# Define file transfers
scp -O location-logo.png root@$DEST_IP:/etc/opennds/htdocs/images
scp -O focus.png root@$DEST_IP:/etc/opennds/htdocs/images
scp -O backdrop.jpg root@$DEST_IP:/etc/opennds/htdocs/images
scp -O styles.css root@$DEST_IP:/etc/opennds/htdocs
scp -O phone-validation.js root@$DEST_IP:/etc/opennds/htdocs
scp -O theme_focus.sh root@$DEST_IP:/usr/lib/opennds
scp -O ../../../forward_authentication_service/libs/libopennds.sh root@$DEST_IP:/usr/lib/opennds
scp -O ../../../forward_authentication_service/libs/client_params.sh root@$DEST_IP:/usr/lib/opennds
