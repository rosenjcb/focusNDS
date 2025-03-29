# Default IP
DEST_IP=${1:-base-camp-wifi-1-ssh.gofocus.space}

# Define file transfers
scp -O backdrop.jpg root@$DEST_IP:/etc/opennds/htdocs/images # /images is wrong but I'm not sure if I want a backdrop.
scp -O location-logo.png root@$DEST_IP:/etc/opennds/htdocs/images
scp -O focus.png root@$DEST_IP:/etc/opennds/htdocs/images
scp -O backdrop.jpg root@$DEST_IP:/etc/opennds/htdocs/images
scp -O splash-test.css root@$DEST_IP:/etc/opennds/htdocs
scp -O phone-validation.js root@$DEST_IP:/etc/opennds/htdocs
scp -O theme_voucher.sh root@$DEST_IP:/usr/lib/opennds
scp -O ../../../forward_authentication_service/libs/libopennds.sh root@$DEST_IP:/usr/lib/opennds
scp -O ../../../forward_authentication_service/libs/client_params.sh root@$DEST_IP:/usr/lib/opennds
