FROM busybox as serf
ARG SERF_VERSION=0.8.2
ARG SERF_OSARCH=linux_amd64
WORKDIR /tmp/serf-dl
RUN wget https://releases.hashicorp.com/serf/${SERF_VERSION}/serf_${SERF_VERSION}_${SERF_OSARCH}.zip
RUN mkdir /serf-bin
RUN unzip serf_${SERF_VERSION}_${SERF_OSARCH}.zip -d /serf-bin

FROM busybox as calicoctl
ARG CALICOCTL_VERSION=v3.13.1
WORKDIR /calicoctl-bin
RUN wget https://github.com/projectcalico/calicoctl/releases/download/${CALICOCTL_VERSION}/calicoctl
RUN chmod +x calicoctl

FROM busybox as gojq
ARG GOJQ_VERSION=v0.9.0
ARG GOJQ_OSARCH=linux_amd64
WORKDIR /tmp/gojq-dl
RUN wget https://github.com/itchyny/gojq/releases/download/${GOJQ_VERSION}/gojq_${GOJQ_VERSION}_${GOJQ_OSARCH}.tar.gz
RUN mkdir /gojq-bin
RUN tar -xzf gojq_${GOJQ_VERSION}_${GOJQ_OSARCH}.tar.gz
RUN mv */gojq /gojq-bin

FROM bitnami/kubectl:1.17.4
COPY --from=serf /serf-bin /usr/local/bin
COPY --from=calicoctl /calicoctl-bin /usr/local/bin
COPY --from=gojq /gojq-bin /usr/local/bin
ENTRYPOINT ["/bin/bash"]
