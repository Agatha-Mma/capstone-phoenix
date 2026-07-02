# Cost Analysis

## Current Monthly Estimate (us-east-1)

| Resource | Spec | Unit Price | Qty | Monthly Cost |
|---|---|---|---|---|
| EC2 t3.small | 2 vCPU, 2GB RAM | $0.0208/hr | 3 | ~$45.00 |
| EBS gp2 (OS disk) | 8GB per instance | $0.10/GB/mo | 3 x 8GB | ~$2.40 |
| EBS gp2 (PVC) | 1GB Postgres PVC | $0.10/GB/mo | 1GB | ~$0.10 |
| Data transfer out | ~10GB/mo estimate | $0.09/GB | 10GB | ~$0.90 |
| S3 (Terraform state) | <1MB | negligible | — | ~$0.01 |
| DynamoDB (state lock) | on-demand, minimal | negligible | — | ~$0.01 |
| **Total** | | | | **~$48.42/mo** |

## Cost Reduction Strategies

### Use Spot Instances (~70% saving)
Replace on-demand t3.small with spot instances for worker nodes:
- t3.small spot price: ~$0.0063/hr vs $0.0208/hr on-demand
- Workers on spot: 2 x $0.0063 x 730hr = ~$9.20/mo (vs ~$30.37)
- Keep control plane on-demand for stability
- Estimated saving: ~$21/mo

### Downsize to t3.micro for workers (~25% saving)
- t3.micro: $0.0104/hr — sufficient for light workloads
- Saving: ~$11/mo

### Use ARM-based instances (t4g.small) (~20% saving)
- t4g.small: $0.0166/hr — same specs, ARM architecture
- Images are x86 only (would need rebuild for ARM)

### Teardown when not in use
```bash
terraform destroy  # saves ~$1.50/day when not running
```

## Production Recommendations

For a real production deployment replace this setup with:
- **RDS PostgreSQL** (managed, automated backups, Multi-AZ) — ~$25/mo for db.t3.micro
- **EKS** (managed Kubernetes control plane) — $0.10/hr (~$73/mo) but eliminates operational overhead
- **ALB** (Application Load Balancer) instead of Traefik — ~$16/mo base + usage
- **Route53** with Elastic IP for stable domain — ~$0.50/mo per hosted zone
- Estimated production cost: ~$150-200/mo for a small production workload
