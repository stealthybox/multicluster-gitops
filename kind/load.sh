#!/bin/bash
unset CD_PATH
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${SCRIPT_DIR}" || exit 1

set -eu

cd ../config

config-build () {
  for dir in $(ls $1); do
    # echo "../config/$1/$dir"
    kustomize build "$1/$dir"
  done
}

parse-images() {
  grep 'image:' | sed 's/^[ -]*image:[ ]*//g' | sort -u
}

pull-then-load() {
  img=$1
  cl=$2
  docker image pull --quiet "$img"
  kind load docker-image "$img" --name "$cl"
}

for cl in cluster{0..2}; do
  for img in $(config-build "$cl" | parse-images); do
    pull-then-load "$img" "$cl" &
  done
  wait

  echo
  echo "  Loaded images for $cl"
  echo
done

echo "All cluster images loaded"
