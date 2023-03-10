#!/usr/bin/env bash

set -e;

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";

# Dependencies check
for COMMAND in curl jq tac grep mv mktemp sed gnuplot; do
    which $COMMAND &> /dev/null || {
        echo "[$(date -u +"%d-%m-%Y %H:%M:%S")] [ERROR] Unresolved dependencies: $COMMAND" 1>&2;
        exit 1;
    };
done

# Read config variables
unset AUTH_TOKEN;
unset API_HOST;
unset HISTSIZE;
test -e "$DIR/main.cfg" && {
    while read -r line; do
        [[ "$line" =~ ^(AUTH_TOKEN|API_HOST|HISTSIZE)=* ]] || continue;
        declare +x -- "${line}";
    done < "$DIR/main.cfg";
} || {
    echo "[$(date -u +"%d-%m-%Y %H:%M:%S")] [ERROR] main.cfg file is not found" 1>&2;
    exit 1;
}

function usage() {
    echo "Usage: $0 [COMMAND]" 1>&2;
    echo -e "\tupdate - update stats" 1>&2;
    echo -e "\tpost - draw and post graph" 1>&2;
}

function get_nodeinfo_cached() {
    local NODEINFO_URL;
    local NODEINFO;
    NODEINFO_URL=$(
        curl -s -f --retry-delay 2 --retry 5 --connect-timeout 8 -m 10 \
        -H "Accept: application/json" "https://$SERVER/.well-known/nodeinfo" \
            | jq -r .links[-1].href 2>/dev/null \
        || true
    );
    test -n "$NODEINFO_URL" && NODEINFO=$(
        curl -s -f --retry-delay 2 --retry 5 --connect-timeout 8 -m 10 \
        -H "Accept: application/json" "$NODEINFO_URL" || true
    );
    test -n "$NODEINFO" && {
        TMP="$(mktemp)";
        grep -v "^$SERVER " "$DIR/workspace/cache.db" 2>/dev/null > "$TMP";
        mv "$TMP" "$DIR/workspace/cache.db";
        echo -n "$SERVER " >> "$DIR/workspace/cache.db";
        echo "$NODEINFO" | jq -c >> "$DIR/workspace/cache.db";
        echo "$NODEINFO";
        return 0;
    }

    echo "[$(date -u +"%d-%m-%Y %H:%M:%S")] [WARNING] $SERVER is not reachable, checking for cached response..." 1>&2;
    grep -m1 "^$SERVER " "$DIR/workspace/cache.db" 2>/dev/null | sed "s/^$SERVER //";
}

function update() {
    SERVERS=(
        $(
            curl -s -f --retry 5 --connect-timeout 8 -m 10 \
            -H "Accept: application/json" https://relay.social.net.ua/nodeinfo/2.1.json \
                | jq -r .metadata.peers[] 2>/dev/null \
            || true
        )
    );

    test "${#SERVERS[@]}" -gt 0 || {
       echo "[$(date -u +"%d-%m-%Y %H:%M:%S")] [ERROR] Can't fetch the list of servers" 1>&2;
       return 1;
    }

    declare -i SERVERS_ACTIVE=0;
    declare -i TOTAL_USERS=0;
    declare -i LOCAL_POSTS=0;
    for SERVER in ${SERVERS[@]}; do
        NODEINFO=$(get_nodeinfo_cached "$SERVER");
        test -n "$NODEINFO" || {
            echo "[$(date -u +"%d-%m-%Y %H:%M:%S")] [WARNING] Can't get nodeinfo from $SERVER" 1>&2;
            continue;
        };
        let SERVERS_ACTIVE+=1;
        let TOTAL_USERS+=$(echo "$NODEINFO" | jq -r '.usage.users.total // 0');
        let LOCAL_POSTS+=$(echo "$NODEINFO" | jq -r '.usage.localPosts // 0');
    done

    echo "$(date +%s),$TOTAL_USERS,$SERVERS_ACTIVE,$LOCAL_POSTS" >> "$DIR/workspace/mastostats.csv";

    TMP="$(mktemp)";
    tail -n ${HISTSIZE:-10000} "$DIR/workspace/mastostats.csv" > "$TMP";
    mv "$TMP" "$DIR/workspace/mastostats.csv";
}

function post() {
    test -z "$AUTH_TOKEN" && {
        echo "[$(date -u +"%d-%m-%Y %H:%M:%S")] [ERROR] AUTH_TOKEN is not defined" 1>&2;
        return 1;
    }

    test -z "$API_HOST" && {
        echo "[$(date -u +"%d-%m-%Y %H:%M:%S")] [ERROR] API_HOST is not defined" 1>&2;
        return 1;
    }

    # Collect stats first
    declare -i ONE_HOUR_AGO=$(date -d "1 hour ago" +%s);
    declare -i ONE_DAY_AGO=$(date -d "1 day ago" +%s);
    declare -i ONE_WEEK_AGO=$(date -d "1 week ago" +%s);

    declare -i LAST_HOUR_USERS=0;
    declare -i LAST_DAY_USERS=0;
    declare -i LAST_WEEK_USERS=0;
    declare -i MAX_USERS=0;

    while IFS=, read -r DATE USERS SERVERS POSTS; do
        test "$DATE" -ge "$ONE_HOUR_AGO" && LAST_HOUR_USERS=$USERS;
        test "$DATE" -ge "$ONE_DAY_AGO" && test "$USERS" -le "$LAST_HOUR_USERS" && LAST_DAY_USERS=$USERS;
        test "$DATE" -ge "$ONE_WEEK_AGO" && test "$USERS" -le "$LAST_DAY_USERS" && LAST_WEEK_USERS=$USERS;
        test "$MAX_USERS" -eq 0 && MAX_USERS=$USERS;
    done < <(tac "$DIR/workspace/mastostats.csv");

    # Normalize stats if no recent data
    test "$LAST_HOUR_USERS" -eq 0 && LAST_HOUR_USERS=$MAX_USERS;
    DIFF_LAST_HOUR=$(echo $((MAX_USERS - LAST_HOUR_USERS)) | sed 's/^\([0-9]*\)$/+\1/;s/^+0$/0/');

    test "$LAST_DAY_USERS" -eq 0 && LAST_DAY_USERS=$LAST_HOUR_USERS;
    DIFF_LAST_DAY=$(echo $((MAX_USERS - LAST_DAY_USERS)) | sed 's/^\([0-9]*\)$/+\1/;s/^+0$/0/');

    test "$LAST_WEEK_USERS" -eq 0 && LAST_WEEK_USERS=$LAST_HOUR_USERS;
    DIFF_LAST_WEEK=$(echo $((MAX_USERS - LAST_WEEK_USERS)) | sed 's/^\([0-9]*\)$/+\1/;s/^+0$/0/');

    echo "[$(date -u +"%d-%m-%Y %H:%M:%S")] [INFO] $MAX_USERS accounts" 2>&1;
    echo "[$(date -u +"%d-%m-%Y %H:%M:%S")] [INFO] $DIFF_LAST_HOUR in the last hour" 2>&1;
    echo "[$(date -u +"%d-%m-%Y %H:%M:%S")] [INFO] $DIFF_LAST_DAY in the last day" 2>&1;
    echo "[$(date -u +"%d-%m-%Y %H:%M:%S")] [INFO] $DIFF_LAST_WEEK in the last week" 2>&1;

    test "$(($MAX_USERS - $LAST_HOUR_USERS))" -eq 0 && {
        echo "[$(date -u +"%d-%m-%Y %H:%M:%S")] [INFO] No new users for the past hour, exiting..." 2>&1;
        return 0;
    }

    echo "[$(date -u +"%d-%m-%Y %H:%M:%S")] [INFO] executing generate.gnuplot:";
    cd "$DIR" && gnuplot "$DIR/generate.gnuplot" 1>&2;

    MEDIA_JSON=$(curl -H "Authorization: Bearer $AUTH_TOKEN" -X POST \
        -H "Content-Type: multipart/form-data" \
        -s -f --retry-delay 2 --retry 5 --connect-timeout 8 -m 10 \
        "https://$API_HOST/api/v1/media" --form file="@$DIR/workspace/graph.png"; true);

    MEDIA_ID=$(echo $MEDIA_JSON | jq -r '.id' 2>/dev/null; true)
    test -n $MEDIA_ID || {
        echo -e "[$(date -u +"%d-%m-%Y %H:%M:%S")] [ERROR] Can't upload graph.png\n$MEDIA_JSON" 1>&2;
        return 1;
    }

    POST_JSON=$(curl -H "Authorization: Bearer $AUTH_TOKEN" \
        "https://$API_HOST/api/v1/statuses" \
        -s -f --retry-delay 2 --retry 5 --connect-timeout 8 -m 10 \
        -F "status=$MAX_USERS ????????????????
$DIFF_LAST_HOUR ???? ?????????????? ????????????
$DIFF_LAST_DAY ???? ???????????????? ????????
$DIFF_LAST_WEEK ???? ???????????????? ??????????????" \
        -F "media_ids[]=$MEDIA_ID"; true);
    POST_URL="$(echo $POST_JSON | jq -r .url 2>/dev/null; true)";
    test -n "$POST_URL" || {
        echo -e "[$(date -u +"%d-%m-%Y %H:%M:%S")] [ERROR] Can't post status\n$POST_JSON" 1>&2;
        return 1;
    }
    echo "[$(date -u +"%d-%m-%Y %H:%M:%S")] [INFO] Status URL: $POST_URL" 2>&1;
}

function main() {
    COMMAND="$1";
    shift;

    test -z "$COMMAND" && usage && exit 1;
    case "$COMMAND" in
        update)
            update $@;
        ;;
        post)
            post $@;
        ;;
        *)
            echo "[$(date -u +"%d-%m-%Y %H:%M:%S")] [ERROR] Unknown '$COMMAND' command" 1>&2;
            usage;
            return 1;
        ;;
    esac
}

main $@;
