#!/bin/bash
set -ex

# Install Zilla to the Kubernetes cluster with helm and wait for the pod to start up
ZILLA_CHART=oci://ghcr.io/aklivity/charts/zilla
VERSION=0.9.46
helm install zilla-http-kafka-cache $ZILLA_CHART --version $VERSION --namespace zilla-http-kafka-cache --create-namespace --wait \
    --values values.yaml \
    --set-file zilla\\.yaml=zilla.yaml \
    --set-file secrets.tls.data.localhost\\.p12=tls/localhost.p12

# Install Kafka to the Kubernetes cluster with helm and wait for the pod to start up
helm install zilla-http-kafka-cache-kafka chart --namespace zilla-http-kafka-cache --create-namespace --wait

# Create the items-snapshots topic in Kafka with the cleanup.policy=compact topic configuration
KAFKA_POD=$(kubectl get pods --namespace zilla-http-kafka-cache --selector app.kubernetes.io/instance=kafka -o name)
kubectl exec --namespace zilla-http-kafka-cache "$KAFKA_POD" -- \
    /opt/bitnami/kafka/bin/kafka-topics.sh \
        --bootstrap-server localhost:9092 \
        --create \
        --topic items-snapshots \
        --config cleanup.policy=compact \
        --if-not-exists

# Start port forwarding
kubectl port-forward --namespace zilla-http-kafka-cache service/zilla-http-kafka-cache 8080 9090 > /tmp/kubectl-zilla.log 2>&1 &
kubectl port-forward --namespace zilla-http-kafka-cache service/kafka 9092 29092 > /tmp/kubectl-kafka.log 2>&1 &
until nc -z localhost 8080; do sleep 1; done
until nc -z localhost 9092; do sleep 1; done
