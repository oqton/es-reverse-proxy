#!/bin/bash
source $(git rev-parse --show-toplevel)/tools/tools.sh

_3DS_STAGING_1PASS_ITEM_IDS='2rtixn2nv37opwg6qxifc2tiny
2do4ojscmzdncpwc2bmc3zdcxm'


function 3DS_ES_STAGING_DEPLOY_OA2PROXY() {
	if [ $# -ne 1 ]; then
		>&2 echo "ERROR__3DS_ES_STAGING_DEPLOY_OA2PROXY: not enough params."
		return 1
	fi
	local OAUTH2_PROXY_DOWNLOAD_LINK="$1"

	local flags=`
	`' --http-address=\"0.0.0.0:$PORT\"'`
	`' --https-address=\"0.0.0.0:$PORT\"'`
	`' --redis-connection-url=\"$REDIS_URL\"'`
	`' --provider=\"oidc\"'`
	`' --oidc-email-claim=\"sub\"'`
	`' --cookie-domain=\"es.staging.3dsystems.com\"'`
	`' --cookie-name=\"_oauth2_proxy\"'`
	`' --cookie-refresh=\"30m\"'`
	`' --email-domain=\"*\"'`
	`' --htpasswd-file=\".htpasswd\"'`
	`' --pass-access-token=\"true\"'`
	`' --provider-display-name=\"3DSystems SSO\"'`
	`' --redis-insecure-skip-tls-verify=\"true\"'`
	`' --session-store-type=\"redis\"'`
	`' --set-xauthrequest=\"true\"'`
	`' --skip-jwt-bearer-tokens=\"true\"'`
	`' --skip-provider-button=\"false\"'`
	`

	local EXECUTALE_FILENAME='oauth2-proxy'
	read -r -d '' PROCESS_TYPES_JSON << EOM
	{
		"web":"./$EXECUTALE_FILENAME $flags"
	}
EOM

	local WORKDIR="/tmp/oa2p_workdir_"$(date +%s)
	mkdir "$WORKDIR"
	if [[ $? -ne 0 ]]; then
		>&2 echo "ERROR__3DS_ES_STAGING_DEPLOY_OA2PROXY: failed to create $WORKDIR"
		return 1
	fi

	local HTPASSWD_FILEPATH='/tmp/htpasswd_'"$(date +%s)"
	touch "$HTPASSWD_FILEPATH"
	if [[ $? -ne 0 ]]; then
		>&2 echo "ERROR__3DS_ES_STAGING_DEPLOY_OA2PROXY: failed to create $HTPASSWD_FILEPATH file"
		return 1
	fi

	__create_htpasswd_from_1pass_items "$_3DS_STAGING_1PASS_ITEM_IDS" "$HTPASSWD_FILEPATH"
	if [[ $? -ne 0 ]]; then
		>&2 echo "ERROR__3DS_ES_STAGING_DEPLOY_OA2PROXY: failed to create .htpasswd file from 1Password items"
		return 1
	fi

	local EXECUTABLE_PATH="$WORKDIR/$EXECUTALE_FILENAME"
	__create_oauth2_proxy_app $WORKDIR $OAUTH2_PROXY_DOWNLOAD_LINK $EXECUTABLE_PATH
	if [[ $? -ne 0 ]]; then
		>&2 echo "ERROR__3DS_ES_STAGING_DEPLOY_OA2PROXY: failed to create oauth2-proxy app"
		return 1
	fi

	cp "$HTPASSWD_FILEPATH" "$WORKDIR/.htpasswd"
	if [[ $? -ne 0 ]]; then
		>&2 echo "ERROR__3DS_ES_STAGING_DEPLOY_OA2PROXY: failed to to copy file $HTPASSWD_FILEPATH to $WORKDIR/.htpasswd"
		return 1
	fi

	__deploy_new_app_with_slug "$WORKDIR" "es-staging-auth" "$PROCESS_TYPES_JSON" "$EXECUTABLE_PATH" "$WORKDIR/.htpasswd"
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	return 0
	
}
