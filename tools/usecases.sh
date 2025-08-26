#!/bin/bash
source $(git rev-parse --show-toplevel)/tools/tools.sh

_3DS_STAGING_1PASS_ITEM_IDS='2rtixn2nv37opwg6qxifc2tiny
nj6snmb5jmd46cslkhuezhiybq
2do4ojscmzdncpwc2bmc3zdcxm'

HEX_STAGING_1PASS_ITEM_IDS='gsaejqgof4alvoubrmxdu5xfcy
i5u4fj5gbukvivolu55j6scbam
whdofht77ee5gtddfuyupcnohe'

HEX_PRODUCTION_1PASS_ITEM_IDS='3xpuaa5bl6z7mthgurojr6u25a
6zhqa5ddy62ae5uuzdyst6isti
vtcogbuhyk2l3wai7x4ea42qcy'

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
	`' --cookie-domain=\"zxcvzxcvzxcv.xyz\"'`
	`' --cookie-name=\"_oauth2_proxy\"'`
	`' --cookie-refresh=\"30m\"'`
	`' --email-domain=\"*\"'`
	`' --htpasswd-file=\".htpasswd\"'`
	`' --pass-access-token=\"true\"'`
	`' --provider-display-name=\"Development SSO\"'`
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

function HEX_ES_PRODUCTION_DEPLOY_OA2PROXY() {
	if [ $# -ne 1 ]; then
		>&2 echo "ERROR__HEX_ES_PRODUCTION_DEPLOY_OA2PROXY: not enough params."
		return 1
	fi
	local OAUTH2_PROXY_DOWNLOAD_LINK="$1"

	local flags=`
	`' --http-address=\"0.0.0.0:$PORT\"'`
	`' --https-address=\"0.0.0.0:$PORT\"'`
	`' --redis-connection-url=\"$REDIS_URL\"'`
	`' --provider=\"oidc\"'`
	`' --oidc-email-claim=\"sub\"'`
	`' --cookie-domain=\"geomagic-entitlement-mi.hexagon.com\"'`
	`' --cookie-name=\"_oauth2_proxy\"'`
	`' --cookie-refresh=\"30m\"'`
	`' --email-domain=\"*\"'`
	`' --htpasswd-file=\".htpasswd\"'`
	`' --pass-access-token=\"true\"'`
	`' --provider-display-name=\"Hexagon SSO\"'`
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
		>&2 echo "ERROR__HEX_ES_PRODUCTION_DEPLOY_OA2PROXY: failed to create $WORKDIR"
		return 1
	fi

	local HTPASSWD_FILEPATH='/tmp/htpasswd_'"$(date +%s)"
	touch "$HTPASSWD_FILEPATH"
	if [[ $? -ne 0 ]]; then
		>&2 echo "ERROR__HEX_ES_PRODUCTION_DEPLOY_OA2PROXY: failed to create $HTPASSWD_FILEPATH file"
		return 1
	fi

	__create_htpasswd_from_1pass_items "$HEX_PRODUCTION_1PASS_ITEM_IDS" "$HTPASSWD_FILEPATH"
	if [[ $? -ne 0 ]]; then
		>&2 echo "ERROR__HEX_ES_PRODUCTION_DEPLOY_OA2PROXY: failed to create .htpasswd file from 1Password items"
		return 1
	fi

	local EXECUTABLE_PATH="$WORKDIR/$EXECUTALE_FILENAME"
	__create_oauth2_proxy_app $WORKDIR $OAUTH2_PROXY_DOWNLOAD_LINK $EXECUTABLE_PATH
	if [[ $? -ne 0 ]]; then
		>&2 echo "ERROR__HEX_ES_PRODUCTION_DEPLOY_OA2PROXY: failed to create oauth2-proxy app"
		return 1
	fi

	cp "$HTPASSWD_FILEPATH" "$WORKDIR/.htpasswd"
	if [[ $? -ne 0 ]]; then
		>&2 echo "ERROR__HEX_ES_PRODUCTION_DEPLOY_OA2PROXY: failed to to copy file $HTPASSWD_FILEPATH to $WORKDIR/.htpasswd"
		return 1
	fi

	__deploy_new_app_with_slug "$WORKDIR" "auth-prod-hex" "$PROCESS_TYPES_JSON" "$EXECUTABLE_PATH" "$WORKDIR/.htpasswd"
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	return 0
}

function HEX_ES_STAGING_DEPLOY_OA2PROXY() {
	if [ $# -ne 1 ]; then
		>&2 echo "ERROR__HEX_ES_STAGING_DEPLOY_OA2PROXY: not enough params."
		return 1
	fi
	local OAUTH2_PROXY_DOWNLOAD_LINK="$1"

	local flags=`
	`' --http-address=\"0.0.0.0:$PORT\"'`
	`' --https-address=\"0.0.0.0:$PORT\"'`
	`' --redis-connection-url=\"$REDIS_URL\"'`
	`' --provider=\"oidc\"'`
	`' --oidc-email-claim=\"sub\"'`
	`' --cookie-domain=\"geomagic-entitlement-mi-staging.hexagon.com\"'`
	`' --cookie-name=\"_oauth2_proxy\"'`
	`' --cookie-refresh=\"30m\"'`
	`' --email-domain=\"*\"'`
	`' --htpasswd-file=\".htpasswd\"'`
	`' --pass-access-token=\"true\"'`
	`' --provider-display-name=\"Hexagon SSO\"'`
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
		>&2 echo "ERROR__HEX_ES_STAGING_DEPLOY_OA2PROXY: failed to create $WORKDIR"
		return 1
	fi

	local HTPASSWD_FILEPATH='/tmp/htpasswd_'"$(date +%s)"
	touch "$HTPASSWD_FILEPATH"
	if [[ $? -ne 0 ]]; then
		>&2 echo "ERROR__HEX_ES_STAGING_DEPLOY_OA2PROXY: failed to create $HTPASSWD_FILEPATH file"
		return 1
	fi

	heroku whoami > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		>&2 echo "ERROR__HEX_ES_STAGING_DEPLOY_OA2PROXY: !!! Sign in into Heroku: (heroku login) !!!"
		return 1
	fi

	#heroku redis:credentials $REDIS_URL --reset --app 'auth-staging-hex'
	#heroku config:set OAUTH2_PROXY_COOKIE_SECRET=$(__generate_oa2p_cookie_secret) --app 'auth-staging-hex'

	local HEX_STAGING_DB_URL=
	HEX_STAGING_DB_URL=$(heroku config:get DATABASE_URL --app ses-staging-hex)
	if [[ $? -ne 0 ]]; then
		>&2 echo "$HEX_STAGING_DB_URL"
		>&2 echo "ERROR__HEX_ES_STAGING_DEPLOY_OA2PROXY: failed to get ses-staginx-hex database url"
		return 1
	fi

	__create_htpasswd_from_1pass_items "$HEX_STAGING_1PASS_ITEM_IDS" "$HTPASSWD_FILEPATH"
	if [[ $? -ne 0 ]]; then
		>&2 echo "ERROR__HEX_ES_STAGING_DEPLOY_OA2PROXY: failed to create .htpasswd file from 1Password items"
		return 1
	fi

	psql "$HEX_STAGING_DB_URL" \
	--field-separator=':' \
	--tuples-only \
	--no-align \
	--command="SELECT uid, encrypted_password FROM users WHERE encrypted_password LIKE '\$2a\$%' AND (LOWER(uid) LIKE '%@3dsystems.com' OR LOWER(uid) LIKE '%@oqton.com' OR LOWER(uid) LIKE '%@hexagon.com')" \
	>> "$HTPASSWD_FILEPATH"

	local EXECUTABLE_PATH="$WORKDIR/$EXECUTALE_FILENAME"
	__create_oauth2_proxy_app $WORKDIR $OAUTH2_PROXY_DOWNLOAD_LINK $EXECUTABLE_PATH
	if [[ $? -ne 0 ]]; then
		>&2 echo "ERROR__HEX_ES_STAGING_DEPLOY_OA2PROXY: failed to create oauth2-proxy app"
		return 1
	fi

	cp "$HTPASSWD_FILEPATH" "$WORKDIR/.htpasswd"
	if [[ $? -ne 0 ]]; then
		>&2 echo "ERROR__HEX_ES_STAGING_DEPLOY_OA2PROXY: failed to to copy file $HTPASSWD_FILEPATH to $WORKDIR/.htpasswd"
		return 1
	fi

	__deploy_new_app_with_slug "$WORKDIR" "auth-staging-hex" "$PROCESS_TYPES_JSON" "$EXECUTABLE_PATH" "$WORKDIR/.htpasswd"
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	return 0
}
