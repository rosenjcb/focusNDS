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
location_name="Basecamp Cafe"

# functions:

generate_splash_sequence() {
	login_with_voucher
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
		<title>Guest WiFi Access - $location_name</title>
		</head>
		<body>
		<div class=\"page-root\">
		<div class=\"content-root\">
		<img src=\"$gatewayurl$location_logo\" alt=\"$location_name\">
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

login_with_voucher() {
	# This is the simple click to continue splash page with no client validation.
	# The client is however required to accept the terms of service.

	if [[ "$is_guest_ready" = "true" ]]; then
		voucher_validation
	else
		voucher_form
	fi
	footer
}

check_voucher() {
	
	# Strict Voucher Validation for shell escape prevention - Only formatted national phone numbers are allowed.
	if validation=$(echo -n $voucher |  grep -oE "^\([0-9]{3}\) [0-9]{3} - [0-9]{4}"); then
		voucher=$(echo "$voucher" | sed 's/[^0-9+]//g')
		: #no-op
	else
		return 1
	fi

	##############################################################################################################################
	# WARNING
	# The voucher roll is written to on every login
	# If its location is on router flash, this **WILL** result in non-repairable failure of the flash memory
	# and therefore the router itself. This will happen, most likely within several months depending on the number of logins.
	#
	# The location is set here to be the same location as the openNDS log (logdir)
	# By default this will be on the tmpfs (ramdisk) of the operating system.
	# Files stored here will not survive a reboot.

	voucher_roll="$logdir""vouchers.txt"

	#
	# In a production system, the mountpoint for logdir should be changed to the mount point of some external storage
	# eg a usb stick, an external drive, a network shared drive etc.
	#
	# See "Customise the Logfile location" at the end of this file
	#
	##############################################################################################################################

	output=$(grep $voucher $voucher_roll | head -n 1) # Store first occurence of voucher as variable
 	if [ $(echo -n $output | wc -w) -ge 1 ]; then 
		current_time=$(date +%s)
		voucher_token=$(echo "$output" | awk -F',' '{print $1}')
		voucher_rate_down=$(echo "$output" | awk -F',' '{print $2}')
		voucher_rate_up=$(echo "$output" | awk -F',' '{print $3}')
		voucher_quota_down=$(echo "$output" | awk -F',' '{print $4}')
		voucher_quota_up=$(echo "$output" | awk -F',' '{print $5}')
		voucher_time_limit=$(echo "$output" | awk -F',' '{print $6}')
		voucher_first_punched=$(echo "$output" | awk -F',' '{print $7}')

		# Set limits according to voucher
		upload_rate=$voucher_rate_up
		download_rate=$voucher_rate_down
		upload_quota=$voucher_quota_up
		download_quota=$voucher_quota_down

		if [ $voucher_first_punched -eq 0 ]; then
			#echo "First Voucher Use"
			# "Punch" the voucher by setting the timestamp to now
			voucher_expiration=$(($current_time + $voucher_time_limit * 60))
			# Override session length according to voucher
			session_length=$voucher_time_limit
			sed -i -r "s/($voucher.*,)(0)/\1$current_time/" $voucher_roll
			return 0
		else
			# Current timestamp <= than Punch Timestamp + Validity (minutes) * 60 secs/minute
			voucher_expiration=$(($voucher_first_punched + $voucher_time_limit * 60))

			if [ $current_time -le $voucher_expiration ]; then
				time_remaining=$(( ($voucher_expiration - $current_time) / 60 ))
				# Override session length according to voucher
				session_length=$time_remaining
				# Nothing to change in the roll
				return 0
			else
				# Delete expired voucher from roll
				sed -i "/$voucher/"d $voucher_roll
				return 1
			fi
		fi
	else
		echo "<p class="stand-out">No Voucher Found - Retry</p>"
		return 1
	fi
	
	# Should not get here
	return 1
}

voucher_validation() {
	originurl=$(printf "${originurl//%/\\x}")

	check_voucher
	if [ $? -eq 0 ]; then
		#echo "Voucher is Valid, click Continue to finish login<br>"

		# Refresh quotas with ones imported from the voucher roll.
		quotas="$session_length $upload_rate $download_rate $upload_quota $download_quota"
		# Set voucher used (useful if for accounting reasons you track who received which voucher)
		userinfo="$title - $voucher"

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

voucher_form() {
	# Define a click to Continue form

	# From openNDS v10.2.0 onwards, QL code scanning is supported to pre-fill the "voucher" field in this voucher_form page.
	#
	# The QL code must be of the link type and be of the following form:
	#
	# http://[gatewayfqdn]/login?voucher=[voucher_code]
	#
	# where [gatewayfqdn] defaults to status.client (can be set in the config)
	# and [voucher_code] is of course the unique voucher code for the current user

	# Get the voucher code:

	voucher_code=$(echo "$cpi_query" | awk -F "voucher%3d" '{printf "%s", $2}' | awk -F "%26" '{printf "%s", $1}')

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
			<input type=\"tel\" name=\"voucher\" id=\"phone\" placeholder=\"(206) 413-5555\" maxlength=\"16\" pattern=\"\(\d{3}\) \d{3} - \d{4}\" required />
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
			<input type=\"hidden\" name=\"voucher\" value=\"$voucher\" />
			<input type=\"hidden\" name=\"id\" value=\"$guest_id\" />
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
