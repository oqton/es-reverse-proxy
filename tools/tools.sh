function __get_username_password_from_1pass_login_item() {
	if [ $# -ne 1 ]; then
		>&2 echo "ERROR__get_username_password_from_1pass_login_item: not enough params."
		return 1
	fi
	local _1PASS_ITEM_ID="$1"

	if ! op whoami > /dev/null 2>&1; then
		>&2 echo "ERROR__get_username_password_from_1pass_login_item: !!! Sign in into 1Password !!!"
		return 1
	fi

	local _1PASS_CONTENT_JSON=
	_1PASS_CONTENT_JSON=$(op item get "$_1PASS_ITEM_ID" --format json)
	if [ $? -ne 0 ]; then
		>&2 echo "ERROR__get_username_password_from_1pass_login_item: failed getting 1Password item '$1'."
		return 1
	fi
	local USERNANE=$(echo "$_1PASS_CONTENT_JSON" | jq -r '.fields | map(select(.label == "username"))[0].value')
	local PASSWORD=$(echo "$_1PASS_CONTENT_JSON" | jq -r '.fields | map(select(.label == "password"))[0].value')

	echo "$USERNANE:$PASSWORD"

	unset _1PASS_CONTENT_JSON
	unset USERNANE
	unset PASSWORD
}

function __create_htpasswd_from_1pass_items() {
	if [ $# -ne 2 ]; then
		>&2 echo "ERROR__create_htpasswd_from_1pass_items: not enough params."
		return 1
	fi
	local _1PASS_ITEM_IDS="$1"
	local HTPASSWD_FILEPATH="$2"

	while read -r line
	do
		htpasswd -bB -C 12 "$HTPASSWD_FILEPATH" $(__get_username_password_from_1pass_login_item "$line" | awk -v FS=':' '{print $1 " " $2}') > /dev/null 2>&1 
		if [[ $? -ne 0 ]]; then
			>&2 echo "ERROR__create_htpasswd_from_1pass_items: failed to add $line credentials"
			return 1
		fi
	done < <(echo $_1PASS_ITEM_IDS)

	return 0
}

function __create_slug_archive(){
	if [ $# -ne 4 ]; then
		>&2 echo "ERROR__create_slug_archive: not enough params."
		return 1
	fi
	local workdir="$1"
	local executable_path="$2"
	local htpasswd_path="$3"
	local archive_path="$4"

	local app_dir="$workdir/app"
	mkdir "$app_dir"
	if [[ $? -ne 0 ]]; then
		>&2 echo "ERROR__create_slug_archive: failed to create $app_dir"
		return 1
	fi

	cp "$executable_path" "$app_dir"
	if [[ $? -ne 0 ]]; then
		>&2 echo "ERROR__create_slug_archive: failed to copy $executable_path into $app_dir"
		return 1
	fi

	cp "$htpasswd_path" "$app_dir"
	if [[ $? -ne 0 ]]; then
		>&2 echo "ERROR__create_slug_archive: failed to copy $htpasswd_path into $app_dir"
		return 1
	fi
	
	tar czfv "$archive_path" -C "$workdir" './app'
	if [[ $? -ne 0 ]]; then
		>&2 echo "ERROR__create_slug_archive: failed creating slug archive."
		return 1
	fi

	return 0
}

function __heroku_allocate_new_slug(){
	if [ $# -ne 3 ]; then
		>&2 echo "ERROR__heroku_allocate_new_slug: not enough params."
		return 1
	fi
	local checksum="$1"
	local app_name="$2"
	local process_types_json="$3"

	read -r -d '' PAYLOAD <<- EOM
	{
		"process_types":$process_types_json,
		"checksum":"$checksum"
	}
EOM

	response=$(curl -s -w "\n%{http_code}" \
	-X POST \
	-H "Content-Type: application/json" \
	-H "Accept: application/vnd.heroku+json; version=3" \
	-d "$PAYLOAD" \
	-n "https://api.heroku.com/apps/$app_name/slugs")

	http_code=$(echo "$response" | tail -n1)
	if [[ "$http_code" -ne 201 ]]; then
		>&2 echo "ERROR__heroku_allocate_new_slug: Heroku returned HTTP $http_code"
		return 1
	fi

	json_response=$(echo "$response" | sed '$d')  # remove last line

	blob_url=$(echo "$json_response" | jq -r '.blob.url')
	if [ -z "$blob_url" ]; then
		>&2 echo "ERROR__heroku_allocate_new_slug: Failed to get blob URL from Heroku response"
		return 1
	fi

	slug_id=$(echo "$json_response" | jq -r '.id')
	if [ -z "$slug_id" ]; then
		>&2 echo "ERROR__heroku_allocate_new_slug: Failed to get slug ID from Heroku response"
		return 1
	fi

	echo "$blob_url $slug_id"
	return 0
}

function __heroku_deploy_slug(){
	if [ $# -ne 2 ]; then
		>&2 echo "ERROR__heroku_deploy_slug: not enough params."
		return 1
	fi
	local blob_url="$1"
	local slug_path="$2"

	http_code=$(curl -s -o /dev/null -w "%{http_code}" \
	-X PUT \
	-H "Content-Type:" \
	--data-binary @"$slug_path" \
	"$blob_url")

	if [[ "$http_code" -ne 200 ]]; then
		>&2 echo "ERROR__heroku_deploy_slug: Upload failed with HTTP status: $http_code"
		return 1
	fi

	return 0
}

function __heroku_release_slug(){
	if [ $# -ne 2 ]; then
		>&2 echo "ERROR__heroku_release_slug: not enough params."
		return 1
	fi
	local slug_id="$1"
	local app_name="$2"

	http_code=$(curl -s -o /dev/null -w "%{http_code}" \
	-X POST \
	-H "Accept: application/vnd.heroku+json; version=3" \
	-H "Content-Type: application/json" \
	-d "{\"slug\":\"$slug_id\"}" \
	-n \
	"https://api.heroku.com/apps/$app_name/releases")

	if [[ "$http_code" -ne 201 ]]; then
		>&2 echo "ERROR__heroku_release_slug: Release failed with HTTP status: $http_code"
		return 1
	fi
}

function __create_oauth2_proxy_app(){
	if [ $# -ne 3 ]; then
		>&2 echo "ERROR__create_oauth2_proxy_app: not enough params."
		return 1
	fi
	local workdir="$1"
	local archive_url="$2"
	local executable_path="$3"


	local archive_path="$workdir/"$(__extract_filename_from_url $archive_url)
	curl -L $archive_url -o $archive_path 2> /dev/null
	if ! [ -f $archive_path ]; then
		echo "ERROR__create_oauth2_proxy_app: failed download oauth2-proxy binary file, archive not found in $app_dir ."
		return 1
	fi

	local archive_content="$workdir/content"
	mkdir "$archive_content"
	if [[ $? -ne 0 ]]; then
		echo "ERROR__create_oauth2_proxy_app: failed to create $archive_content"
		return 1
	fi
	
	tar -xzf "$archive_path" -C "$archive_content" --strip-components=1
	if [[ $? -ne 0 ]]; then
		echo "ERROR__create_oauth2_proxy_app: failed to extract archive"
		return 1
	fi


	filecount=$(find "$archive_content" -not -path "$archive_content" | wc -l)
	if [[ "$filecount" -gt 1 ]]; then
		echo "ERROR__create_oauth2_proxy_app: downloaded archive contains more then 1 file"
		return 1
	fi

	mv $(find "$archive_content" -not -path "$archive_content") "$executable_path"

	return 0
}

function __deploy_new_app_with_slug(){
	if [ $# -ne 5 ]; then
		>&2 echo "ERROR__deploy_new_app_with_slug: not enough params."
		return 1
	fi
	local workdir="$1"
	local app_name="$2"
	local process_types_json="$3"
	local executable_path="$4"
	local htpasswd_path="$5"

	heroku whoami > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		>&2 echo "ERROR__deploy_new_app_with_slug: !!! Sign in into Heroku: (heroku login) !!!"
		return 1
	fi

	local archive_path="$workdir/slug.tgz"
	__create_slug_archive $workdir "$executable_path" "$htpasswd_path" "$archive_path"
	if [ $? -ne 0 ]; then
		>&2 echo "ERROR__deploy_new_app_with_slug: Slug archive creation failed. Aborting deploy."
		return 1
	fi

	local checksum="SHA256:$(shasum -a 256 $archive_path | awk '{print $1}')"
	upload_url_and_slug_id=$(__heroku_allocate_new_slug "$checksum" "$app_name" "$process_types_json")
	if [ $? -ne 0 ]; then
		>&2 echo "$upload_url_and_slug_id"
		>&2 echo "ERROR__deploy_new_app_with_slug: Failed to allocate Heroku slug"
		return 1
	fi

	__heroku_deploy_slug $(echo "$upload_url_and_slug_id" | awk '{print $1}') "$archive_path"
	if [ $? -ne 0 ]; then
		>&2 echo "ERROR__deploy_new_app_with_slug: Failed to deploy the slug to Heroku"
		return 1
	fi

	__heroku_release_slug $(echo "$upload_url_and_slug_id" | awk '{print $2}') $app_name
	if [ $? -ne 0 ]; then
		>&2 echo "ERROR__deploy_new_app_with_slug: Failed to release Heroku slug"
		return 1
	fi
	return 0
}

function __extract_filename_from_url() {
	if [ $# -ne 1 ]; then
		>&2 echo "ERROR__extract_filename_from_url: not enough params."
		return 1
	fi
	local url="$1"

	local archive="${url##*/}" # strips everything up to the last /
	if [[ -z "$archive" ]]; then
		>&2 echo "ERROR__extract_filename_from_url: failed to extract filename from url"
		return 1
	fi

	echo "$archive"
}

