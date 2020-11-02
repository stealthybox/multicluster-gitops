# multi-cluster mesh routing /w GitOps
This demo will build you 3 clusters that will all
share their routing information with each other and
forward DNS for cross-cluster Services.

The clusters are created using `kind`, and
`cluster0` is used as a [Flux](https://fluxcd.io) management cluster.
Access to apply to the remaining clusters is done by mocking ClusterAPI kubeconfigs.

Discovery of other clusters' Nodes is accomplished through
a fun bash controller that queries a multicast Serf cluster.
This works well on a single docker network or any network that supports multicast.
You can also configure Serf to bootstrap from some fixed IP's.

A neat thing about this strategy is that it's declarative!
Fork this repo and try it out :)

## Requirements:
1. your computer
2. these tools
   - git
   - hub (optional)
   - flux
   - docker
   - kind
   - kubectl

## Let's go
```shell
hub clone stealthybox/multicluster-gitops
cd multicluster-gitops
hub fork
  # alternatively fork in the web UI and clone
```

```shell
kind/setup.sh
kind/load.sh

# bootstrap Calico for Flux
kubectl apply --context kind-cluster0 -k ./config/cluster0/kube-system

GITHUB_USER=stealthybox
# set your own user here to match your fork

export GITHUB_TOKEN="<personal access token with repo and SSH key rights>"

flux bootstrap github \
  --owner "${GITHUB_USER}" \
  --personal \
  --repository "multicluster-gitops" \
  --path "./config/cluster0"
```
alternatively, if you want to not use github & flux, apply the `kube-system` and `default` kustomizations to the proper clusters:
```shell
for cl in cluster{0..2}; do
  kubectl apply --context "kind-${cl}" -k "./config/${cl}/"{default,kube-system}
done
```

## Looking around
- Get the `Kustomization` resources the cluster0 flux-system uses to apply to the other clusters
- Use the `kubectl --context` flag to switch between `kind-cluster0|1|2` on demand
- Check that the serf and calico dameonsets and deploys become ready
- Check out the Corefile ConfigMap extensions in kube-system
- Examine the `BGPPeer` resources that the serf-query controller created from the serf member list
- Exec into the debug pods for each cluster and run `host podinfo.default.svc.cluster1.lan`
- Try curling the service from and to different clusters!


## Tidying Up
```shell
kind/cleanup.sh
```

____


## More demos!
Check out this next demo featuring Flux's GPG signature verification and remote-cluster management over Cluster API: [stealthybox/capi-flux-demo](https://github.com/stealthybox/capi-flux-demo) 
