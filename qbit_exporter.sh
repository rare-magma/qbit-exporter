#!/usr/bin/env bash

set -Eeo pipefail

dependencies=(curl gzip jq)
for program in "${dependencies[@]}"; do
    command -v "$program" >/dev/null 2>&1 || {
        echo >&2 "Couldn't find dependency: $program. Aborting."
        exit 1
    }
done

CURL=$(command -v curl)
GZIP=$(command -v gzip)
JQ=$(command -v jq)

[[ -z "${QBIT_URL}" ]] && echo >&2 "QBIT_URL is empty. Aborting" && exit 1
[[ -z "${PUSHGATEWAY_URL}" ]] && echo >&2 "PUSHGATEWAY_URL is empty. Aborting" && exit 1

qbit_json=$($CURL --silent --compressed "$QBIT_URL/api/v2/transfer/info")

[[ -z "${qbit_json}" ]] && echo >&2 "Couldn't get any info from the QBIT API. Aborting" && exit 1

mapfile -t parsed_qbit_stats < <(echo "$qbit_json" | $JQ --raw-output '.dl_info_data,.dl_info_speed,.up_info_data,.up_info_speed')

dl_info_data_value=${parsed_qbit_stats[0]}
dl_info_speed_value=${parsed_qbit_stats[1]}
up_info_data_value=${parsed_qbit_stats[2]}
up_info_speed_value=${parsed_qbit_stats[3]}

qbit_stats=$(
    cat <<END_HEREDOC
# HELP dl_info_data Data downloaded this session (bytes)
# TYPE dl_info_data counter
# HELP dl_info_speed Global download rate (bytes/s)
# TYPE dl_info_speed gauge
# HELP up_info_data Data uploaded this session (bytes)
# TYPE up_info_data counter
# HELP up_info_speed Global upload rate (bytes/s)
# TYPE up_info_speed gauge
dl_info_data {host="$HOSTNAME"} ${dl_info_data_value}
dl_info_speed {host="$HOSTNAME"} ${dl_info_speed_value}
up_info_data {host="$HOSTNAME"} ${up_info_data_value}
up_info_speed {host="$HOSTNAME"} ${up_info_speed_value}
END_HEREDOC
)

echo "$qbit_stats" | $GZIP |
    $CURL --silent \
        --header 'Content-Encoding: gzip' \
        --data-binary @- "${PUSHGATEWAY_URL}"/metrics/job/qbit_exporter/host/"$HOSTNAME"
