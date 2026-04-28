#!/usr/bin/env bash
# Post-upgrade assertions for the run-upgrade-test job.
#
# Each named regression that's worth catching is one block here. When you add
# a new check, comment it with the PR/issue that motivated it so the next
# reader knows why this exact resource is being asserted.
#
# Requires KUBECONFIG to point at the kind cluster, and helm/kubectl on PATH
# (the workflow exports the released-tree's .demo/ binaries).

set -euo pipefail

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# 1. Helm release status should be "deployed" (not "failed", not "pending").
helm status diracx-demo -o json | jq -e '.info.status == "deployed"' >/dev/null \
  || fail "helm release status is not 'deployed'"

# 2. PR #262 regression: pre-upgrade hook deleted diracx-secrets and Helm's
#    manifest reconciliation never restored it. Asserts the Secret exists
#    after the upgrade.
kubectl get secret diracx-secrets -o name >/dev/null \
  || fail "diracx-secrets Secret is missing after upgrade (regression of PR #262)"

# 3. All Pods become Ready within a bounded window. Catches the broad class
#    of "upgrade succeeded but something CrashLoopBackOffs / FailedMounts".
kubectl wait --for=condition=Ready pod --all --timeout=600s \
  || fail "not all pods became Ready after upgrade"

# 4. No failed Helm hook Jobs. Catches the case where an upgrade hook (e.g.
#    validate-config) regressed and the upgrade somehow proceeded anyway.
failed_jobs=$(kubectl get jobs -o json \
  | jq -r '[.items[] | select((.status.failed // 0) > 0) | .metadata.name] | join(",")')
if [[ -n "$failed_jobs" ]]; then
  fail "failed Job(s) detected: $failed_jobs"
fi

# 5. Helm history shows a fresh deployed revision and the previous one
#    superseded. Catches the case where a previous step looked successful
#    but Helm didn't actually record the upgrade.
helm history diracx-demo -o json \
  | jq -e 'map({rev: .revision, status: .status})
           | (any(.[]; .rev == 2 and .status == "deployed"))
           and (any(.[]; .rev == 1 and .status == "superseded"))' >/dev/null \
  || fail "helm history not as expected (rev 2 deployed, rev 1 superseded)"

echo "All upgrade-health assertions passed."
