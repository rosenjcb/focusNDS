#!/bin/sh
#Copyright (C) The openNDS Contributors 2004-2023
#Copyright (C) BlueWave Projects and Services 2015-2024
#Copyright (C) Francesco Servida 2023
#This software is released under the GNU GPL license.
#
# Warning - shebang sh is for compatibliity with busybox ash (eg on OpenWrt)
# This must be changed to bash for use on generic Linux
#

title="theme_voucher"
location_logo="/images/location-logo.png"
focus_logo="/images/focus.png"
backdrop="/images/backdrop.png"
css_test="/splash-test.css"
phone_validation_script="/phone-validation.js"
FOCUS_LOCATION_ID=$(uci get focus.@settings[0].LOCATION_ID 2>/dev/null)
FOCUS_LOCATION_NAME=$(uci get focus.@settings[0].LOCATION_NAME 2>/dev/null)

# functions:

generate_splash_sequence() {
	login_as_guest
}

header() {
# Define a common header html for every page served
	gatewayurl=$(printf "${gatewayurl//%/\\x}")
	echo "<!DOCTYPE html>
		<html>
		<head>
		<meta http-equiv=\"Cache-Control\" content=\"no-cache, no-store, must-revalidate\">
		<meta http-equiv=\"Pragma\" content=\"no-cache\">
		<meta http-equiv=\"Expires\" content=\"0\">
		<meta charset=\"utf-8\">
		<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
		<link rel=\"shortcut icon\" href=\"$gatewayurl$location_logo\" type=\"image/x-icon\">
		<link rel=\"stylesheet\" type=\"text/css\" href=\"$gatewayurl$css_test\">
		<script type=\"text/javascript\" src=\"$gatewayurl$phone_validation_script\"></script>
		<title>Guest WiFi Access - $FOCUS_LOCATION_NAME</title>
		</head>
		<body>
		<div class=\"page-root\">
		<div class=\"content-root\">
		<img src=\"$gatewayurl$location_logo\" alt=\"$FOCUS_LOCATION_NAME\">
	"
}

footer() {
	# Define a common footer html for every page served
	year=$(date +'%Y')
	echo "
		<footer>
			<hr />
			<flex-column-center>
				<img src=\"$gatewayurl$focus_logo\" />
				<med-black>Thanks for trying us out!</med-black>
				<med-black>Powered by FOCUS</med-black>
			</flex-column-center>
		</footer>
		</div>
		</div>
		</body>
		</html>
	"

	exit 0
}

login_as_guest() {
	# This is the simple click to continue splash page with no client validation.
	# The client is however required to accept the terms of service.

	if [[ "$is_guest_ready" = "true" ]]; then
		guest_validation
	else
		guest_form
	fi
	footer
}

fetch_most_recent_visit() {
	
	# Strict Voucher Validation for shell escape prevention - Only formatted national phone numbers are allowed.
	most_recent_visit="{}"
	most_recent_visit=$(curl -X GET "http://localhost:8000/api/visits/recent?phoneNumber=$phonenumber&locationId=$FOCUS_LOCATION_ID")

 	if [ -n "$most_recent_visit"  ]; then 
		current_time=$(date +%s)
		upload_rate=1024
		download_rate=5120
		upload_quota=0
		download_quota=0
		start_time=$(echo "$most_recent_visit" | jq -r '.startTime' | sed 's/T/ /; s/\..*Z//' | while read ts; do date -u -d "$ts" +%s; done)
		end_time=$(echo "$most_recent_visit" | jq -r '.endTime' | sed 's/T/ /; s/\..*Z//' | while read ts; do date -u -d "$ts" +%s; done)

		if [ $current_time -le $end_time ]; then
			time_remaining=$(( ($end_time - $current_time) / 60 ))
			session_length=$time_remaining
			return 0
		else
			return 1
		fi
	else
		echo "<p class="stand-out">Something went wrong when fetching your most recent visit. Please try again.</p>"
		return 1
	fi
	
	# Should not get here
	return 1
}

guest_validation() {
	originurl=$(printf "${originurl//%/\\x}")

    fetch_most_recent_visit	
	if [ $? -eq 0 ]; then
		#echo "Voucher is Valid, click Continue to finish login<br>"

		# Refresh quotas with ones imported from the voucher roll.
		quotas="$session_length $upload_rate $download_rate $upload_quota $download_quota"
		echo "quotas: $quotas"
		# Set voucher used (useful if for accounting reasons you track who received which voucher)
		userinfo="$title - $phonenumber"
		echo "userinfo: $userinfo"

		# Authenticate and write to the log - returns with $ndsstatus set
		auth_log

		# output the landing page - note many CPD implementations will close as soon as Internet access is detected
		# The client may not see this page, or only see it briefly
		auth_success="
			<h1 class="black-title">You're Online Now!</h1>
			<div class="section">
				<p>You are now logged in and have been granted access to the Internet.</p>
				<p>The session is valid for the rest of the day.</p>
				<p>You can use your Browser, Email and other network Apps as you normally would.</p>
				<p>Your device originally requested <b>$originurl</b></p>
			</div>
			<p class="stand-out">Click or tap Continue to go to there.</p>
		"
		auth_fail="
			<h1 class="black-title">Something went wrong and you have faild to login.</h1>
			<div class="section">
				<p>Your login attempt probably timed out.</p>
			</div>
			<p class="stand-out">Click or tap Continue to try again.</p>
		"

		if [ "$ndsstatus" = "authenticated" ]; then
			echo "$auth_success"
		else
			echo "$auth_fail"
		fi

		echo "
			<form>
				<input type=\"button\" VALUE=\"Continue\" onClick=\"location.href='$originurl'\" >
			</form>
			 "
	else
		echo "
			<h1 class="black-title">We can't find your phone number.</h1>
			<h2>Have you made a purchase in the last 2 hours?</h2>
		"
		echo "
			<form>
				<input type=\"button\" VALUE=\"Continue\" onClick=\"location.href='$originurl'\" >
			</form>
		"
	fi

	read_terms
}

guest_form() {
	if [[ "$is_guest_ready" = "false" ]]; then
		step_two
	else
		step_one
	fi

	read_terms
	footer
}

step_one() {
	echo "
		<h1 class=\"black-title\">Free Wi-Fi</h1>
		<form action=\"/opennds_preauth/\" method=\"get\" id="guestLogin">
			<input type=\"hidden\" name=\"fas\" value=\"$fas\" />
			Loyalty Rewards Phone Number 
			<input type=\"tel\" name=\"nationalPhonenumber\" id=\"phone\" placeholder=\"(206) 413-5555\" maxlength=\"16\" pattern=\"\(\d{3}\) \d{3} - \d{4}\" required />
			<flex-row>
				<input type=\"checkbox\" name=\"tos\" value=\"accepted\" required /> 
				I accept the Terms of Service
			</flex-row>
			<br />
			<input type=\"submit\" value=\"Connect\" />
		</form>
		"
}

step_two() {
	echo "
		<h1 class=\"black-title\">Free Wi-Fi</h1>
		<h2 class=\"black-subheading\">Just a few more things...</h1>
		<form action=\"/opennds_preauth/\" method=\"get\" id="guestLogin">
			<input type=\"hidden\" name=\"fas\" value=\"$fas\" />
			<input type=\"hidden\" name=\"complete\" value=\"true\" />
			<input type=\"hidden\" name=\"tos\" value=\"accepted\" />
			<input type=\"hidden\" name=\"guestId\" value=\"$guest_id\" />
			First Name 
			<input type=\"text\" name=\"firstname\" id=\"email\" placeholder=\"John\" required />
			Last Name
			<input type=\"text\" name=\"lastname\" id=\"email\" placeholder=\"Doe\" required />
			Email 
			<input type=\"text\" pattern=\"[^@\s]+@[^@\s]+\.[^@\s]+\" name=\"email\" id=\"email\" placeholder=\"you@domain.com\" required />
			Zipcode
			<input type=\"text\" pattern=\"[0-9]{5}\" name=\"zipcode\" id=\"zipcode\" placeholder=\"55555\" maxlength=\"5\" required />
			<br />
			<input type=\"submit\" value=\"Connect\" />
		</form>
		"
}

read_terms() {
	#terms of service button
	echo "
		<form action=\"/opennds_preauth/\" method=\"get\">
			<input type=\"hidden\" name=\"fas\" value=\"$fas\">
			<input type=\"hidden\" name=\"terms\" value=\"yes\">
			<input type=\"submit\" value=\"Read Terms of Service\" >
		</form>
	"
}

display_terms() {
	# This is the all important "Terms of service"
	# Edit this long winded generic version to suit your requirements.
	####
	# WARNING #
	# It is your responsibility to ensure these "Terms of Service" are compliant with the REGULATIONS and LAWS of your Country or State.
	# In most locations, a Privacy Statement is an essential part of the Terms of Service.
	####

	echo "
		<h1 class="black-title">Privacy</h1>
		By using this Wi-Fi, you agree to the following:

		<ul>
			<li><b>Privacy</b>: We may store login data and device information for security and functionality. Your data is kept secure and not shared with third parties.</li>
			<li><b>Proper Use</b>: Do not misuse the network, engage in illegal activities, or disrupt service for others. Unauthorized access, hacking, spamming, or other harmful actions are prohibited.</li>
			<li><b>Security & Liability</b>: You are responsible for securing your own data. While we take precautions, we do not guarantee a secure connection. We are not liable for any damages, data loss, or third-party content accessed through this service.</li>
			<li><b>Changes & Termination</b>: We may modify or terminate access at any time without notice.</li>
		</ul>
		<p>By continuing, you accept these terms.</p>
		<form>
			<input type=\"button\" VALUE=\"Continue\" onClick=\"history.go(-1);return true;\">
		</form>
	"
	footer
}

#### end of functions ####


#################################################
#						#
#  Start - Main entry point for this Theme	#
#						#
#  Parameters set here overide those		#
#  set in libopennds.sh			#
#						#
#################################################

# Quotas and Data Rates
#########################################
# Set length of session in minutes (eg 24 hours is 1440 minutes - if set to 0 then defaults to global sessiontimeout value):
# eg for 100 mins:
# session_length="100"
#
# eg for 20 hours:
# session_length=$((20*60))
#
# eg for 20 hours and 30 minutes:
# session_length=$((20*60+30))
session_length="0"

# Set Rate and Quota values for the client
# The session length, rate and quota values could be determined by this script, on a per client basis.
# rates are in kb/s, quotas are in kB. - if set to 0 then defaults to global value).
upload_rate="0"
download_rate="0"
upload_quota="0"
download_quota="0"

quotas="$session_length $upload_rate $download_rate $upload_quota $download_quota"

# Define the list of Parameters we expect to be sent sent from openNDS ($ndsparamlist):
# Note you can add custom parameters to the config file and to read them you must also add them here.
# Custom parameters are "Portal" information and are the same for all clients eg "admin_email" and "location" 
ndscustomparams=""
ndscustomimages=""
ndscustomfiles=""

ndsparamlist="$ndsparamlist $ndscustomparams $ndscustomimages $ndscustomfiles"

# The list of FAS Variables used in the Login Dialogue generated by this script is $fasvarlist and defined in libopennds.sh
#
# Additional custom FAS variables defined in this theme should be added to $fasvarlist here.
additionalthemevars="tos voucher"

fasvarlist="$fasvarlist $additionalthemevars"

# You can choose to define a custom string. This will be b64 encoded and sent to openNDS.
# There it will be made available to be displayed in the output of ndsctl json as well as being sent
#	to the BinAuth post authentication processing script if enabled.
# Set the variable $binauth_custom to the desired value.
# Values set here can be overridden by the themespec file

#binauth_custom="This is sample text sent from \"$title\" to \"BinAuth\" for post authentication processing."

# Encode and activate the custom string
#encode_custom

# Set the user info string for logs (this can contain any useful information)
userinfo="$title"

##############################################################################################################################
# Customise the Logfile location.
##############################################################################################################################
#Note: the default uses the tmpfs "temporary" directory to prevent flash wear.
# Override the defaults to a custom location eg a mounted USB stick.
#mountpoint="/mylogdrivemountpoint"
#logdir="$mountpoint/ndslog/"
#logname="ndslog.log"
