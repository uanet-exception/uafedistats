#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";

SERVERS=(
    $(curl -s -f --retry 5 https://relay.social.net.ua/nodeinfo/2.1.json | jq -r .metadata.peers[])
);

TOTAL_USERS=0;
LOCAL_POSTS=0;
ACTIVE_HALFYEAR=0;
for SERVER in ${SERVERS[@]}; do
    NODEINFO_URL=$(curl -s -f --retry-delay 2 --retry 5 "https://$SERVER/.well-known/nodeinfo" | jq -r .links[-1].href);
    test -n "$NODEINFO_URL" || {
        echo "[$(date -u +"%d-%m-%Y %H:%M:%S")] [ERROR] Can't get nodeinfo url from $SERVER" 1>&2;
        continue;
    };
    NODEINFO=$(curl -s -f --retry-delay 2 --retry 5 "$NODEINFO_URL");
    test -n "$NODEINFO" || {
        echo "[$(date -u +"%d-%m-%Y %H:%M:%S")] [ERROR] Can't get nodeinfo from $SERVER" 1>&2;
        continue;
    };
    let TOTAL_USERS+=$(echo $NODEINFO | jq -r '.usage.users.total // 0');
    let LOCAL_POSTS+=$(echo $NODEINFO | jq -r '.usage.localPosts // 0');
done

echo "[$(date -u +"%d-%m-%Y %H:%M:%S")] [INFO] Total: $TOTAL_USERS, localPosts: $LOCAL_POSTS";

echo "$(date +%s),$TOTAL_USERS,${#SERVERS[@]},$LOCAL_POSTS" >> "$DIR/workspace/mastostats.csv";

cd "$DIR/workspace/" && gnuplot generate.gnuplot;

exit 0;