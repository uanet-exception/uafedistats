#!/usr/bin/env bash

set -e;

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";

which gnuplot &> /dev/null || {
    echo "[$(date -u +"%d-%m-%Y %H:%M:%S")] [ERROR] Unresolved dependencies: gnuplot" 1>&2;
    exit 1;
};

cd "$DIR/workspace/" && gnuplot generate.gnuplot;