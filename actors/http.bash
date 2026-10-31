#!/usr/bin/env bash

broadcast() {
  echo "fetch"
}

fetch() {
  curl --request GET -sL \
       --url "$2"\
       --output "$2"
}

case "$1" in
  "broadcast")
    broadcast
    ;;
  "fetch")
    fetch "$@"
    ;;
  *)
    echo "Unsupported command."
    ;;
esac