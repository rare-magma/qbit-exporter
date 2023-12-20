#!/usr/bin/env bash

set -Eeo pipefail

dependencies=(awk curl gzip jq)
for program in "${dependencies[@]}"; do
    command -v "$program" >/dev/null 2>&1 || {
        echo >&2 "Couldn't find dependency: $program. Aborting."
        exit 1
    }
done

AWK=$(command -v awk)
CURL=$(command -v curl)
GZIP=$(command -v gzip)
JQ=$(command -v jq)

if [[ "${RUNNING_IN_DOCKER}" ]]; then
    source "/app/qbit_exporter.conf"
else
    # shellcheck source=/dev/null
    source "$CREDENTIALS_DIRECTORY/creds"
fi

[[ -z "${QBIT_URL}" ]] && echo >&2 "QBIT_URL is empty. Aborting" && exit 1
[[ -z "${PUSHGATEWAY_URL}" ]] && echo >&2 "PUSHGATEWAY_URL is empty. Aborting" && exit 1

if [[ -n "$QBIT_USER" ]] && [[ -n "$QBIT_PASS" ]]; then
    cookie=$(
        $CURL --include \
            --silent --fail --show-error \
            --compressed \
            --data "username=$QBIT_USER&password=$QBIT_PASS" \
            "$QBIT_URL/api/v2/auth/login" |
            $AWK '/set-cookie/ {print $2}'
    )
fi

if [[ -n "$cookie" ]]; then
    qbit_json=$(
        $CURL --silent --fail --show-error \
            --cookie "${cookie::-1}" \
            --compressed \
            "$QBIT_URL/api/v2/transfer/info"
    )

    qbit_alltime_json=$(
        $CURL --silent --fail --show-error \
            --cookie "${cookie::-1}" \
            --compressed \
            "$QBIT_URL/api/v2/sync/maindata"
    )
else
    qbit_json=$($CURL --silent --fail --show-error --compressed "$QBIT_URL/api/v2/transfer/info")
    qbit_alltime_json=$($CURL --silent --fail --show-error --compressed "$QBIT_URL/api/v2/sync/maindata")
fi

[[ -z "${qbit_json}" ]] && echo >&2 "Couldn't get info from the QBIT API. Aborting" && exit 1
[[ -z "${qbit_alltime_json}" ]] && echo >&2 "Couldn't get all time info from the QBIT API. Aborting" && exit 1

mapfile -t parsed_qbit_stats < <(
    echo "$qbit_json" | $JQ --raw-output '.dl_info_data,.dl_info_speed,.up_info_data,.up_info_speed'
)

mapfile -t parsed_qbit_alltime_stats < <(
    echo "$qbit_alltime_json" | $JQ --raw-output '.server_state | .alltime_dl,.alltime_ul'
)

dl_info_data_alltime_value=${parsed_qbit_alltime_stats[0]}
up_info_data_alltime_value=${parsed_qbit_alltime_stats[1]}
dl_info_data_value=${parsed_qbit_stats[0]}
dl_info_speed_value=${parsed_qbit_stats[1]}
up_info_data_value=${parsed_qbit_stats[2]}
up_info_speed_value=${parsed_qbit_stats[3]}

qbit_stats=$(
    cat <<END_HEREDOC
# HELP dl_info_data_alltime All-time download (bytes)
# TYPE dl_info_data_alltime counter
# HELP up_info_data_alltime All-time upload (bytes)
# TYPE up_info_data_alltime counter
# HELP dl_info_data Data downloaded this session (bytes)
# TYPE dl_info_data counter
# HELP dl_info_speed Global download rate (bytes/s)
# TYPE dl_info_speed gauge
# HELP up_info_data Data uploaded this session (bytes)
# TYPE up_info_data counter
# HELP up_info_speed Global upload rate (bytes/s)
# TYPE up_info_speed gauge
dl_info_data_alltime {host="$HOSTNAME"} ${dl_info_data_alltime_value}
up_info_data_alltime {host="$HOSTNAME"} ${up_info_data_alltime_value}
dl_info_data {host="$HOSTNAME"} ${dl_info_data_value}
dl_info_speed {host="$HOSTNAME"} ${dl_info_speed_value}
up_info_data {host="$HOSTNAME"} ${up_info_data_value}
up_info_speed {host="$HOSTNAME"} ${up_info_speed_value}
END_HEREDOC
)

echo "$qbit_stats" | $GZIP |
    $CURL --silent --fail --show-error \
        --header 'Content-Encoding: gzip' \
        --data-binary @- "${PUSHGATEWAY_URL}"/metrics/job/qbit_exporter/host/"$HOSTNAME"
