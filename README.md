# Multi-Stage CI/CD Pipeline with Automated Rollback

A production-grade CI/CD pipeline that builds a Docker image **once**, promotes it through **Beta → Gamma → Production**, runs health checks at every stage, requires **manual approval** before prod, and **auto-rolls back** on failure — all authenticated via **GitHub OIDC** (no AWS keys) and deployed via **AWS SSM** (no SSH).

---

## Problem it solves

Most demo pipelines deploy straight to production. Real teams need **gated environments**:

- Test in Beta first.
- Validate in Gamma second.
- Only then — with human approval — ship to Production.

This project shows that full flow end-to-end: **one image**, **three gates**, **automatic rollback**, **email alerts on prod outcome**, and **zero long-lived AWS credentials**.

---

## Architecture
┌──────────────────────────────────────────────────────────────────────┐
│ GitHub Repository │
│ push to main ──► GitHub Actions workflow (.github/workflows) │
└───────────────────────────────┬──────────────────────────────────────┘
│ OIDC token (no static keys)
▼
┌──────────────────────────────────────────────────────────────────────┐
│ AWS Account (us-east-1) │
│ │
│ ┌────────────┐ 1. build + push ┌──────────────────────────┐ │
│ │ ECR │◄─────────────────────│ GitHub Actions Runner │ │
│ │ (one image)│ └────────────┬─────────────┘ │
│ └─────┬──────┘ │ SSM SendCommand │
│ │ ▼ │
│ │ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│ └──────────►│ Beta │──►│ Gamma │──►│ Prod │ │
│ │ EC2 │ │ EC2 │ │ EC2 │ │
│ │ t3.small │ │ t3.small │ │ t3.small │ │
│ └────┬─────┘ └────┬─────┘ └────┬─────┘ │
│ │ │ │ │
│ ▼ ▼ ▼ │
│ ┌─────────────────────────────────────┐ │
│ │ CloudWatch Logs │ │
│ │ /cicd-pipeline/<env>/app │ │
│ └─────────────────────────────────────┘ │
│ │
│ Health checks fail ──► restore previous image ──► verify ──► SNS │
│ Manual approval gate before Prod (GitHub Environment) │
└──────────────────────────────────────────────────────────────────────┘



### Deployment flow

| Stage | Action | Gate |
|-------|--------|------|
| 1 | Unit tests | Must pass |
| 2 | Build Docker image, push to ECR | Once only |
| 3 | Deploy to **Beta**, health check | Must pass |
| 4 | Deploy to **Gamma**, health check | Must pass |
| 5 | **Manual approval** (GitHub Environment `production`) | Human |
| 6 | Deploy to **Prod**, smoke test | Must pass |
| 7 | SNS email on prod success / rollback success / rollback failure | — |

**Rollback:** every deploy writes `/opt/app/.current_image`. If health checks fail, the previous image is redeployed and verified. Pipeline stops on Beta/Gamma failure.

---

## Tech stack

| Layer | Tool | Why |
|-------|------|-----|
| IaC | **Terraform** | Reproducible VPC, EC2, IAM, ECR, CloudWatch, SNS |
| CI/CD | **GitHub Actions** | Native to repo, reusable workflows, environment gates |
| Auth | **AWS IAM OIDC** | Short-lived tokens — no `AWS_ACCESS_KEY_ID` secrets |
| Compute | **AWS EC2** (`t3.small` × 3) | Separate hosts per environment |
| Containers | **Docker + Compose** | Same image everywhere, simple per-host runtime |
| Registry | **Amazon ECR** | Single source of truth for the image |
| Remote exec | **AWS SSM** | No SSH, no open port 22, no key management |
| Logs | **CloudWatch Logs** | Centralized app + deploy logs per env |
| Alerts | **Amazon SNS** | Email on prod success / rollback outcomes |
| App | **Node.js + Express** | In-memory task API with `/health` + colored UI |

---

## Repository layout
├── .github/workflows/
│ ├── deploy.yml # orchestrator: test → build → beta → gamma → approve → prod
│ └── _deploy-env.yml # reusable: deploy one image to one env + rollback + SNS
├── app/
│ ├── server.js # Express API + /health
│ ├── test.js # unit tests
│ └── public/ # colored UI (index.html, style.css, app.js)
├── terraform/
│ ├── versions.tf # provider pinning
│ ├── providers.tf # AWS provider + default tags
│ ├── variables.tf # region, project, repo, email
│ ├── vpc.tf # dedicated VPC, 2 public subnets, IGW, SG
│ ├── ec2.tf # 3 instances + EIPs + user_data (docker, compose)
│ ├── iam.tf # EC2 role (SSM, ECR read, logs, SNS publish)
│ ├── oidc.tf # GitHub OIDC provider + deploy role
│ ├── ecr.tf # single repo
│ ├── cloudwatch.tf # log groups per env
│ ├── sns.tf # topic + email subscription
│ ├── outputs.tf # role ARN, IPs, IDs, ECR URL
│ └── terraform.tfvars # your values
├── Dockerfile
└── docker-compose.yml


---

## How to deploy

### 1. Provision infrastructure

```bash
cd terraform
terraform init
terraform apply
Copy outputs:

github_deploy_role_arn

sns_topic_arn

instance_ids → map to BETA_INSTANCE_ID, GAMMA_INSTANCE_ID, PROD_INSTANCE_ID

2. Configure GitHub
Settings → Secrets and variables → Actions

Type	Name	Value
Secret	AWS_DEPLOY_ROLE_ARN	from Terraform output
Secret	SNS_TOPIC_ARN	from Terraform output
Variable	BETA_INSTANCE_ID	Terraform output
Variable	GAMMA_INSTANCE_ID	Terraform output
Variable	PROD_INSTANCE_ID	Terraform output
Settings → Environments → production → add Required reviewers (yourself).

3. Confirm SNS email
Check inbox for AWS Notification - Subscription Confirmation → click Confirm subscription.

git push origin main
# Health of each env (replace IPs with terraform output)
curl http://<BETA_IP>:3000/health
curl http://<GAMMA_IP>:3000/health
curl http://<PROD_IP>:3000/health
# → {"status":"ok","env":"beta","version":"<sha>",...}

# UI
open http://<IP>:3000

Troubleshooting log (real issues hit + fixes)
Symptom	Root cause	Fix
Not authorized to perform sts:AssumeRoleWithWebIdentity	OIDC trust sub mismatched repo	Set github_repo = "ORG/REPO" in terraform.tfvars and re-apply
ssm:SendCommand returns InvalidInstanceId	Instance not yet registered with SSM	Wait 2–3 min after apply; check aws ssm describe-instance-information
Docker pull no basic auth credentials	ECR login not run inside SSM script	Add aws ecr get-login-password | docker login to deploy script (included)
Health check hits wrong env	Beta/Gamma/Prod share port 3000	/health returns env; workflow asserts env == expected
Rollback ran but new version still live	Compose cached old container	docker compose down before up -d (included)
Duplicate aws_iam_instance_profile	Two resources with same name	Keep only the one in iam.tf
GitHub Action fails at OIDC step	Provider thumbprint / audience	Re-apply oidc.tf; thumbprint 6938fd4d...
Instance has no public IP	Subnet without map_public_ip_on_launch	Set in vpc.tf (included) + EIP attached
Cost note
3 × t3.small running 24/7 ≈ $45–50/month in us-east-1. Destroy when done:

cd terraform && terraform destroy
ECR repo uses force_delete = true, log groups expire in 7 days, EIPs are attached (no idle charge).
