#!/usr/bin/env bash
set -eu

# This script demonstrate safe interrupts of a
# polling control-loop in Bash.
# The reconcile() function is allowed to finish
# when a stop signal is recieved.
# The only jobs that are killed on-stop are pause_loop()

SYNC_PERIOD="${SYNC_PERIOD:-"10"}"

reconcile() {
  echo start
  sleep 2
  echo finish
  echo
}

pause_loop() {
  sleep "${SYNC_PERIOD}" || true
}

graceful_exit() {
  echo "--- received interrupt ---"
  job_ids="$(
    jobs \
      | grep "pause_loop" \
      | tr [] " " \
      | awk '{print "%" $1}'
    )"
  # shellcheck disable=SC2086
  if [ "${job_ids}" ]; then
    kill ${job_ids}
  fi
  wait
  echo "< clean exit >"
}

trap graceful_exit INT TERM

for _ in {1..2}; do
  reconcile & wait $!
  pause_loop & wait $!
done
