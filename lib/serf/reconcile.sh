#!/usr/bin/env bash

COREDNS_NS="${COREDNS_NS:-"kube-system"}"
COREDNS_CM_CONFIGDIR="${COREDNS_CM_CONFIGDIR:-"coredns-configdir"}"
COREDNS_CM_ENV="${COREDNS_CM_ENV:-"coredns-env"}"
SYNC_PERIOD="${SYNC_PERIOD:-"10"}"

set -eu

reconcile_test() {
  sleep 1
  echo "${COREDNS_NS}"
  sleep 1
  echo "${COREDNS_CM_CONFIGDIR}"
  sleep 1
  echo "${COREDNS_CM_ENV}"
  echo
}

old_hash=""
reconcile() {
  self_cluster="$(
    serf info --format json | gojq -r '.tags.cluster'
    )"
  members="$(
    serf members --format json | gojq '[
      .members[] | select( .status != "left" )
        | .tags + {name,ip:.addr|sub(":[0-9]*$";"")}
    ] | sort_by(.name)'
    )"
  external_members="$(
    echo "${members}" | gojq '.[] | select( .cluster != "'"${self_cluster}"'" )'
    )"

  hash="$(
    printf "${self_cluster}\n${members}" | sha256sum
    )"
  if [ "${hash}" = "${old_hash}" ]; then
    return # no changes, do nothing
  fi
  old_hash="${hash}"
  
  bgp_peers="$(
    echo "${external_members}" | gojq --yaml-output '
      {
        apiVersion: "projectcalico.org/v3",
        kind: "BGPPeer",
        metadata: {
          name: .name,
          labels: {
            serf: "true"
          }
        },
        spec: {
          peerIP: .ip,
          asNumber: .asn
        }
      }'
    )"
  
  corefile_mc="$(
    echo "${external_members}" | gojq -sr '[ .[] |
"\(.cluster).lan:53 {
  forward . \(.dns)
}"
    ] | unique | .[]'
    )"

  removed_peers="$(
    comm -23 \
      <(kubectl get bgppeers -l serf --no-headers | awk '{print $1}' | sort -u) \
      <(echo "${external_members}" | gojq -r '.name' | sort -u)
    )"
  [ "${removed_peers}" ] && calicoctl delete bgppeers ${removed_peers}
  
  if [ "${bgp_peers}" ]; then
    echo "${bgp_peers}" | calicoctl apply -f -
  fi

  # https://kube-router.io example  *(kube-router does not seem to dynamically update peers)
  # kubectl annotate node --all --overwrite=true "kube-router.io/peer.ips=${ip_csv}"
  # kubectl annotate node --all --overwrite=true "kube-router.io/peer.asns=${asn_csv}"

  if [ "${self_cluster}" ]; then
    kubectl -n "${COREDNS_NS}" \
      get configmap "${COREDNS_CM_ENV}" &>/dev/null \
      ||  kubectl -n "${COREDNS_NS}" \
          create configmap "${COREDNS_CM_ENV}"
    kubectl -n "${COREDNS_NS}" \
      patch configmap "${COREDNS_CM_ENV}" \
      --type merge \
      -p "$(echo {} | gojq '.data["EXTRA_KUBE_ZONES"]="'"${self_cluster}.lan"'"')"
  fi

  if [ "${corefile_mc}" ]; then
    kubectl -n "${COREDNS_NS}" \
      get configmap "${COREDNS_CM_CONFIGDIR}" &>/dev/null \
      ||  kubectl -n "${COREDNS_NS}" \
          create configmap "${COREDNS_CM_CONFIGDIR}"
    kubectl -n "${COREDNS_NS}" \
      patch configmap "${COREDNS_CM_CONFIGDIR}" \
      --type merge \
      -p "$(echo {} | gojq '.data["Corefile.multi-cluster"]="'"${corefile_mc}"'"')"
  fi

  # free memory
  self_cluster=""
  members=""
  external_members=""
  bgp_peers=""
  corefile_mc=""
  removed_peers=""
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

while true; do
  reconcile_test & wait $!
  pause_loop & wait $!
done
