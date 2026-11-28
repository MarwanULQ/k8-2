# Argo CD deployment

Push k8-2-gitops changes first. Then push this repository with
[terraform apply] [deploy k8] [deploy webapp] in the commit message.
Terraform provisions AWS; Ansible installs pinned Argo CD v3.2.0; the webapp
workflow builds the triggering commit, pushes GHCR, bootstraps Secrets and the
root Application, then commits the image tag into the GitOps repository.
Argo CD performs deployment asynchronously. A green CI run means handoff
succeeded, not that all Applications are healthy.

Required GitHub Actions repository Secrets:

- Existing POSTGRES_PASSWORD, LIBRARY_SECRET_KEY, GHCR_READ_TOKEN.
- Optional GITOPS_TOKEN: Contents read/write access on MarwanULQ/k8-2-gitops,
  used only for automatic image-tag commits. Without it, CI reports the image
  reference in its summary; update and push the GitOps values file manually.
- Grafana uses lab credentials admin/admin; no GitHub password Secret is required.

Argo CD reads the public GitOps repository anonymously. Public read access does
not grant CI permission to push. GitOps token absence does not fail the build.
Existing Grafana databases retain their current password; the bootstrap password
is used when Grafana initializes a new database.

Never change the PostgreSQL password without rotating the actual database
password. Existing database PVC and namespace are preserved. No helm uninstall,
namespace deletion, or Terraform destroy is needed.

New NodePorts, restricted to admin_cidr when enable_nodeport_ingress=true:

| Service | Port | Protocol |
|---|---|---|
| Argo CD | 30443 | HTTPS (default self-signed certificate) |
| Grafana | 30300 | HTTP |
| Prometheus | 30090 | HTTP |
| Alertmanager | 30903 | HTTP |
| Loki gateway | 30310 | HTTP |
| Alloy | 31235 | HTTP |

Prometheus, Loki, Alertmanager, and Alloy endpoints are administrative endpoints.
They must stay restricted to the administrator CIDR. Existing web/database
rules are unchanged. No blanket NodePort-range rule is added.

Get Argo's initial password on the control plane:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
kubectl get applications -n argocd
kubectl get pods,pvc -n monitoring
```

Use https://NODE_PUBLIC_IP:30443 and http://NODE_PUBLIC_IP:30300.
Grafana includes Prometheus dashboards and a Loki datasource. Explore logs with
{namespace="library"}. Alloy reads pod logs through the Kubernetes API.

The pinned monitoring charts target a small lab: short Prometheus retention,
single-instance Loki, filesystem PVCs, and local-path storage. These are not HA
or backup solutions. t3.small nodes can run out of memory; inspect scheduling
events and available memory before increasing workloads. Node replacement loses
local-path data unless backed up and restored.

Old helm/library files are legacy references, not the deployment source.
The active playbook no longer writes /tmp/library-helm-values.yaml; historical
files from old deployments may still exist. It does not delete those files.
Argo manifests use server-side apply and force-conflicts to take ownership of
installation fields; review changes if an existing Argo install has custom settings.

For rollback, revert image/configuration commits in GitOps. Database migrations
are not automatically undone. Do not run legacy Helm deployment concurrently
with Argo CD reconciliation.
