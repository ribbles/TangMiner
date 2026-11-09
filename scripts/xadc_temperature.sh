#!/usr/bin/env bash

set -u

TEMP_INTERVAL=${TEMP_INTERVAL:-30}
OPENFPGALOADER=${OPENFPGALOADER:-openFPGALoader}

while true; do
    json="$(eval "$OPENFPGALOADER $* -X" |
        sed -n '/^{/,$p' |
        tr -d '\r\n' |
        sed -E 's/,[[:space:]]*}/}/g')"

    if [ -n "$json" ]; then
        printf '%s ' "$(date '+%Y-%m-%d %H:%M:%S')"
        printf '%s\n' "$json" | jq -r '"TEMP=\((.temp * 100 | round) / 100)C (\((.mintemp * 100 | round) / 100), \((.maxtemp * 100 | round) / 100)) VCC=\((.vccaux * 1000 | round) / 1000)V (\((.minvccaux * 1000 | round) / 1000), \((.maxvccaux * 1000 | round) / 1000))"'
    else
        printf '%s XADC read failed\n' "$(date '+%Y-%m-%d %H:%M:%S')" >&2
    fi

    sleep "$TEMP_INTERVAL"
done
