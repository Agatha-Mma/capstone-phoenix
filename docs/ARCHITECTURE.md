# TaskApp Architecture

## Overview

TaskApp is a 3-tier web application (React frontend + Flask backend + PostgreSQL database)
deployed on a 3-node Kubernetes cluster on AWS EC2, with automated TLS, GitOps deployment,
and horizontal autoscaling.

## Infrastructure

- **Cloud:** AWS (us-east-1)
- **Nodes:** 3 x t3.small EC2 instances
  - 1 control plane (ip-10-0-1-203)
  - 2 workers (ip-10-0-1-229, ip-10-0-1-146)
- **Provisioned by:** Terraform (remote state in S3 + DynamoDB locking)
- **Configured by:** Ansible (k3s install, UFW hardening, VXLAN networking)

## Kubernetes Components

| Component | Kind | Replicas | Purpose |
|---|---|---|---|
| postgres | StatefulSet | 1 | Persistent database with PVC |
| backend | Deployment | 2-5 (HPA) | Flask API, gunicorn, health-checked |
| frontend | Deployment | 2 | nginx serving React SPA, proxies /api to backend |
| taskapp-migrate | Job | 1 (one-shot) | Runs alembic migrations before backend starts |

## Request Flow

## Key Design Decisions

| Decision | Reason |
|---|---|
| k3s instead of full k8s | Lightweight, includes Traefik + local-path-provisioner, suited for 3-node learner cluster |
| Headless Service for Postgres | StatefulSet with stable DNS, no load balancing needed for single DB instance |
| Job for migrations, not entrypoint | Prevents race condition when multiple backend replicas start simultaneously |
| gunicorn command override in Deployment | Skips entrypoint migration step on replicas — proven safe since Job runs first |
| DuckDNS + Let's Encrypt | Free, real HTTPS cert — no self-signed certs anywhere |
| source_dest_check=false on EC2 | Required for Flannel VXLAN overlay network to route cross-node pod traffic |
| UFW port 8472/udp + 10250/tcp open | Flannel VXLAN and kubelet metrics ports blocked by UFW by default — explicitly allowed |

## What Kubernetes Solves vs Single-Server Docker

| Problem (single server) | Solution (Kubernetes) |
|---|---|
| App dies if server reboots | Pods automatically restart, spread across nodes |
| Can't handle traffic spikes | HPA scales backend 2→5 replicas under load |
| Deployment causes downtime | RollingUpdate strategy — zero downtime deploys |
| Manual deploys are error-prone | Argo CD GitOps — git push = auto deploy |
| No resource guardrails | ResourceQuota limits CPU/memory per namespace |
| Planned maintenance kills app | PodDisruptionBudget guarantees 1 replica always up |

## Known Limitations / Future Improvements

- DuckDNS domain changes if EC2 IP changes (use Elastic IP + Route53 in production)
- Single Postgres instance (no replication) — use RDS or Postgres operator for HA
- Flannel CNI does not enforce NetworkPolicy — use Calico for real network segmentation
- Secrets managed manually (kubectl create secret) — use Sealed Secrets or Vault in production
