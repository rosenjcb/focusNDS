# FOCUS ThemeSpec
This ThemeSpec provides a simple portal requiring a phonenumber to login. If the phonenumber isn't used previously, more info is requested from the user before completing authentication.

# Installation (openWRT)
**Copies all themespec settings and resources (e.g. `theme_focus.sh`) needed to run FocusNDS.**
Run in order:
- `send-config.sh`
- `send-over.sh`

This will set the FOCUS and OpenNDS Configs and send all assets needed to work.
