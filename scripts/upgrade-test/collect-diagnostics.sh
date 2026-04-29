#!/usr/bin/env bash
# Failure-time dump for the run-upgrade-test job. Always runs (even on
# success) so the workflow log is self-contained. Exit code is ignored;
# this script never fails the job by itself.

set +e

section() {
  echo
  echo "=============================================================="
  echo "=== $* ==="
  echo "=============================================================="
}

section "helm history"
helm history diracx-demo

section "helm status"
helm status diracx-demo

section "all resources"
kubectl get all -A

section "pods (full)"
kubectl get pods -o wide

section "non-Ready pods (describe)"
kubectl get pods --no-headers \
  | awk '$2 !~ /^([0-9]+)\/\1$/ || $3 != "Running" { print $1 }' \
  | xargs -r -n1 kubectl describe pod

section "recent warning events"
kubectl get events --field-selector type=Warning --sort-by=.lastTimestamp

section "secrets and configmaps"
kubectl get secret,configmap

exit 0
