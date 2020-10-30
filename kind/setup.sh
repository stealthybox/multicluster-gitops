#!/bin/bash
unset CD_PATH
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${SCRIPT_DIR}" || exit 1

for cl in cluster{0..2}; do
  kind create cluster \
    --name "${cl}" \
    --config "./${cl}.yaml" &  # background job
done
wait

# provision the other cluster's kubeconfigs into cluster0 
# as if they were created by cluster API
kubectl config use-context kind-cluster0
kubectl create ns flux-system
for cl in cluster{1..2}; do
  kubectl -n flux-system delete secret "${cl}-kubeconfig"
  kubectl -n flux-system create secret generic "${cl}-kubeconfig" \
    --from-file=value=<(
      docker exec "${cl}-control-plane" cat /etc/kubernetes/admin.conf
      )
done
