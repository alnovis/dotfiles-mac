Kubernetes-manifest lens. Deployment-safety defects in k8s / jkube YAML (Deployment, StatefulSet, Service, ConfigMap) — the things that pass `kubectl apply` but bite in production.

HARD GATE: for every finding, cite the manifest file:line and the concrete runtime consequence — OOMKill, unschedulable pod, silent rollout of the wrong image, secret exposure, or traffic sent to an unready pod. If the value is set correctly by a base overlay, jkube default, or Helm value that governs this object, DROP it. A stylistic YAML nit is not a finding.

Where to look first (non-exhaustive — reason beyond this list):
- Container with no `resources.requests`/`limits` (memory especially) → noisy-neighbor eviction or OOMKill.
- Missing `livenessProbe`/`readinessProbe` → dead pods kept in rotation, traffic to not-ready pods.
- Image tag `:latest` or a mutable/floating tag → non-reproducible rollout with no rollback anchor.
- Secret value inline in `env` or a ConfigMap instead of a `Secret` referenced via `secretKeyRef`.
- `env` fieldRef/resourceFieldRef pointing at a field that doesn't exist, or a `valueFrom` key absent from the referenced ConfigMap/Secret.
- No `securityContext` (`runAsNonRoot`, `readOnlyRootFilesystem`) on a service reachable by untrusted input.
- StatefulSet `volumeClaimTemplate` / update-strategy mismatch; `replicas > 1` for a stateful service with no PodDisruptionBudget.
- Hardcoded namespace or cluster-specific host that breaks in another environment.
