#!/bin/bash
unset CD_PATH
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${SCRIPT_DIR}" || exit 1

for cl in cluster{0..2}; do
  kind delete cluster \
  --name "${cl}"
done
