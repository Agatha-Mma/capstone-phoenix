# Runbook — Rebuilding the Cluster from Scratch

This runbook documents how to fully rebuild the TaskApp Kubernetes infrastructure
from zero. This was tested and validated during the capstone project.

## Prerequisites

- WSL Ubuntu with terraform, aws cli, kubectl, ansible installed
- AWS credentials configured (`aws configure`)
- SSH key at `~/.ssh/capstone-phoenix`
- DuckDNS account with `taskapp-agatha.duckdns.org` pointing at control plane public IP

## Step 1 — Provision Infrastructure (Terraform)

```bash
cd infra/terraform
aws s3api create-bucket --bucket capstone-phoenix-tfstate-agdevops --region us-east-1
aws dynamodb create-table --table-name capstone-phoenix-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region us-east-1
terraform init
terraform apply -var="my_ip=$(curl -s ifconfig.me)/32"
```

## Step 2 — Disable Source/Dest Check (required for Flannel)

```bash
for id in $(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=k3s-control-plane,k3s-worker-*" \
  --query "Reservations[].Instances[].InstanceId" --output text); do
  aws ec2 modify-instance-attribute --instance-id "$id" --no-source-dest-check
done
```

## Step 3 — Install k3s Cluster (Ansible)

Update `infra/ansible/inventory.ini` with IPs from `terraform output`, then:

```bash
cd infra/ansible
ansible-playbook -i inventory.ini site.yml
```

## Step 4 — Configure kubectl

```bash
CONTROL_PLANE_IP=$(cd infra/terraform && terraform output -raw control_plane_public_ip)
ssh -i ~/.ssh/capstone-phoenix ubuntu@$CONTROL_PLANE_IP \
  "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/capstone-config
sed -i "s/127.0.0.1/$CONTROL_PLANE_IP/" ~/.kube/capstone-config
export KUBECONFIG=~/.kube/capstone-config
kubectl get nodes
```

## Step 5 — Deploy Application

```bash
cd manifests
kubectl create namespace taskapp
kubectl create secret generic taskapp-secret --namespace=taskapp \
  --from-literal=DATABASE_PASSWORD="$(openssl rand -base64 24)" \
  --from-literal=POSTGRES_PASSWORD="$(openssl rand -base64 24)" \
  --from-literal=SECRET_KEY="$(openssl rand -base64 32)"
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f postgres.yaml
kubectl wait --for=condition=Ready pod/postgres-0 -n taskapp --timeout=120s
kubectl apply -f jobs/migration-job.yaml
kubectl wait --for=condition=Complete job/taskapp-migrate -n taskapp --timeout=60s
kubectl apply -f backend.yaml
kubectl apply -f frontend.yaml
kubectl apply -f pdb.yaml
kubectl apply -f hpa.yaml
kubectl apply -f resourcequota.yaml
```

## Step 6 — Install cert-manager + Ingress

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=cert-manager \
  -n cert-manager --timeout=120s
kubectl apply -f clusterissuer.yaml
kubectl apply -f taskapp-ingress.yaml
```

Update DuckDNS to point at the new control plane public IP, then verify:
```bash
kubectl get certificate -n taskapp
curl -I https://taskapp-agatha.duckdns.org
```

## Step 7 — Install Argo CD

```bash
kubectl create namespace argocd
curl -sL https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  -o /tmp/argocd-install.yaml
kubectl apply -n argocd -f /tmp/argocd-install.yaml --server-side --force-conflicts
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=120s
kubectl apply -f argocd-app.yaml
kubectl get application -n argocd
```

## Day-to-Day Operations

### Update IP after laptop restart
```bash
cd infra/terraform
terraform apply -var="my_ip=$(curl -s ifconfig.me)/32"
```

### Deploy a change
```bash
# Edit any file in manifests/
git add manifests/
git commit -m "describe change"
git push
# Argo CD auto-deploys within 3 minutes, or trigger immediately:
argocd app sync taskapp --insecure
```

### Check cluster health
```bash
kubectl get nodes
kubectl get pods -n taskapp
kubectl get hpa -n taskapp
kubectl top nodes
```

### Failover demo
```bash
kubectl drain <worker-node> --ignore-daemonsets --delete-emptydir-data
# App continues serving — verify with curl
curl -I https://taskapp-agatha.duckdns.org
kubectl uncordon <worker-node>
```
