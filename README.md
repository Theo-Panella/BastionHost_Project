# BastionHost Project

Terraform-based simulation of a Bastion Host (jump server) architecture on AWS.
The goal is to demonstrate how to isolate a private instance so it can only be
reached through a controlled entry point, using NACLs and Security Groups as
layered network controls.

> ⚠️ **Educational use only.** Some configurations (shared SSH key, broad SG rules)
> are intentionally simplified and are **not recommended for production environments**.
> A CI security scan (Trivy) flags these on every pull request — see
> [Security Scanning](#security-scanning) and the [ROADMAP](ROADMAP.md).

---

## Architecture

![Infrastructure Diagram](Diagrama-Infraestrutura.png)

The stack provisions **two VPCs** in `us-west-2`. VPC1 holds the full
bastion/jump-server scenario; VPC2 is being built out for a future peering
exercise (see [ROADMAP](ROADMAP.md)).

### VPC1 — `192.168.0.0/24`

| Resource | Name    | CIDR             | Type    | Instance |
|----------|---------|------------------|---------|----------|
| Subnet A | subnetA | 192.168.0.0/26   | Public  | Bastion  |
| Subnet B | subnetB | 192.168.0.64/26  | Private | Server_1 |
| Subnet C | subnetC | 192.168.0.128/26 | Public  | Invasor  |

### VPC2 — `172.18.0.0/24`

| Resource | Name         | CIDR           | Type    | Instance |
|----------|--------------|----------------|---------|----------|
| Subnet A | subnetA_VPC2 | 172.18.0.0/26  | Private | *(none yet)* |

> VPC2 currently provides only the VPC and one subnet. The internet gateway,
> route tables, NACLs and security groups are all still scoped to VPC1, so VPC2
> has no instances or connectivity yet — it is scaffolding for the planned
> second server and VPC peering.

### NACL Rules (VPC1)

| NACL        | Direction | Rule | Action | Target                          |
|-------------|-----------|------|--------|---------------------------------|
| ACL_subnetA | in/out    | 1    | allow  | 0.0.0.0/0                       |
| ACL_subnetB | in/out    | 1    | allow  | 192.168.0.0/26 (subnetA)        |
| ACL_subnetB | in/out    | 2    | deny   | 192.168.0.128/26 (subnetC)      |
| ACL_subnetC | in/out    | 1    | allow  | 0.0.0.0/0                       |

### Security Groups (VPC1)

| Group           | Instances        | Ingress / Egress                 |
|-----------------|------------------|----------------------------------|
| Bastion-Invasor | Bastion, Invasor | All traffic (0.0.0.0/0)          |
| Server_1        | Server_1         | subnetA only (`192.168.0.0/26`)  |

> Server_1 only accepts traffic from **subnetA** (the Bastion subnet). Combined
> with `ACL_subnetB` rule 2, which denies subnetC, this is what blocks the
> Invasor from reaching Server_1.

---

## Tech Stack

- **Terraform** >= 1.2 / AWS provider ~> 5.92
- **AWS S3** — remote state backend
- **AWS EC2** — Amazon Linux 2023, t3.micro
- **AWS VPC** — two VPCs, subnets, route tables, internet gateway
- **AWS NACLs** — subnet-level traffic control
- **AWS Security Groups** — instance-level traffic control
- **GitHub Actions** — OIDC-authenticated plan/apply pipeline
- **Trivy** — Infrastructure-as-Code security scanning on every PR (SARIF)

---

## Remote State (S3 Backend)

State lives in S3 instead of a local `terraform.tfstate` file:

```hcl
backend "s3" {
  bucket = "aws-panella-bucket2"
  key    = "terraform.tfstate"
  region = "us-east-1"
}
```

> The bucket is in `us-east-1` while the infrastructure is deployed to `us-west-2`.
> That split is intentional — the backend region is independent of the provider region.

### Why it matters

The pipeline and your machine now read and write the **same** state file. Before this,
a CI run and a local run each kept their own view of the world and would happily try to
create duplicate infrastructure. With shared state:

- **Create from either side** — the workflow applies on `main`, or you apply locally.
  Both converge on the same resources.
- **Destroy locally, even for infra the pipeline created.** There is no destroy job in
  the workflows, so teardown is a local operation — and it works because your local
  Terraform sees exactly what CI provisioned.
- **No drift between environments** — a local `terraform plan` reflects the real state
  of the deployed infrastructure, not a stale local copy.

### ⚠️ No state locking

This backend has **no DynamoDB lock table and no S3 native locking** (`use_lockfile`
requires Terraform >= 1.10; the pipeline pins 1.9.0). Two `apply` operations running at
the same time can corrupt the state file.

In practice: **don't run a local `apply`/`destroy` while a pipeline run is in flight.**
Check the Actions tab first.

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.2
- **AWS credentials** — for local use, your AWS session must have access to the S3 state bucket (`aws-panella-bucket2`) and the target account; for CI, the workflow uses OIDC role assumption via `secrets.ARN`
- An SSH key pair at `.ssh/terraform-key` (private) and `.ssh/terraform-key.pub` (public)

Generate the SSH key if you don't have one:
```bash
ssh-keygen -t rsa -b 4096 -f .ssh/terraform-key -N ""
```

**Local credentials:** set up with `aws configure` or `aws sso login`. The S3 backend
is in `us-east-1`; credentials need access to both that region (for state) and `us-west-2`
(for the provider).

> If `terraform init` fails with `No valid credential sources found`, your AWS session has
> expired — re-authenticate with `aws sso login` or `aws configure` before running anything.
> The error comes from the S3 backend, not the Terraform configuration.

---

## CI/CD Pipelines

Three GitHub Actions workflows, one per branch/event. All authenticate to AWS via
OIDC role assumption (`secrets.ARN`) — no static keys are stored.

| Workflow          | Trigger                | Jobs / Steps                                             | Applies? |
|-------------------|------------------------|---------------------------------------------------------|----------|
| `pr_main.yaml`    | Pull request → `main`  | **Trivy** scan → `init` → `validate` → `plan`           | No — gate + review |
| `deploy_dev.yaml` | Push to `dev`          | `init` → `plan`                                         | No — plan only |
| `deploy_main.yaml`| Push to `main`         | `init` → `validate` → `plan` → **`apply`**              | Yes |

The PR pipeline runs in two dependent jobs: the `Configuration` job (`terraform
plan`) has `needs: Trivy`, so **the plan only runs if the security scan passes**.
Merging to `main` then triggers `deploy_main.yaml`, which applies automatically.

### Security Scanning

Every pull request against `main` runs [Trivy](https://trivy.dev) in IaC
(`config`) mode:

- **Gate:** severity `CRITICAL,HIGH` with `exit-code: 1` — findings fail the PR
  and block the `plan` job (and therefore the merge, if set as a required check).
- **Reporting:** results are uploaded as SARIF to the **GitHub Security tab →
  Code scanning**. Because the scan runs on the `pull_request` event, alerts are
  associated with the PR — filter the Code scanning view by the PR branch (the
  default view shows `main`).

Known findings are intentional for this lab (bastion SG open to `0.0.0.0/0`,
public subnets, no IMDSv2/EBS encryption). Hardening them is tracked in the
[ROADMAP](ROADMAP.md).

---

## Deploy

Both paths operate on the same S3 state, so you can mix them freely.

### Via workflow (GitHub Actions)

Open a pull request to `main` to get a security scan + plan, then merge to apply.
See [CI/CD Pipelines](#cicd-pipelines) above for the full matrix.

### Local

```bash
terraform init
terraform plan
terraform apply
```

### Teardown

There is no destroy job in the pipeline — teardown is **local only**, and works against
pipeline-created infrastructure thanks to the shared backend:

```bash
terraform destroy
```

Confirm no workflow run is active before doing this (see the state-locking note above).

---

## Testing

Get the public IPs of your instances from the AWS console (EC2 → Instances) or
from the `terraform plan`/`apply` output. (Named outputs are not defined yet —
see the [ROADMAP](ROADMAP.md).)

### 1. Connect to Bastion (jump server)

```bash
ssh -A -i .ssh/terraform-key ec2-user@<Bastion_Public_IP>
```

### 2. From Bastion, reach Server_1 via private IP

```bash
[ec2-user@bastion ~]$ ssh ec2-user@<Server_1_Private_IP>
```

You should get a successful Amazon Linux 2023 login — the jump is working.

### 3. Verify Invasor is blocked from Server_1

In a separate terminal, connect to Invasor:

```bash
ssh -A -i .ssh/terraform-key ec2-user@<Invasor_Public_IP>
```

Then try to reach Server_1:

```bash
[ec2-user@invasor ~]$ ssh ec2-user@<Server_1_Private_IP>
```

The connection will hang indefinitely — blocked by ACL_subnetB rule 2 (deny from subnetC).
This confirms the network isolation is working correctly.

---

# Roadmap

## 🚧 In progress

- **VPC2 build-out** — the VPC and `subnetA_VPC2` exist, but there is no internet
  gateway, route table, NACL or security group scoped to VPC2 yet, so it has no
  instances or connectivity. Next steps:
  - [ ] Route tables + associations for VPC2 subnets
  - [ ] NACLs / security groups scoped to VPC2
  - [ ] A second Server instance (`Server_2`) in VPC2

---

## ⏳ Planned

### Networking
- [ ] **VPC peering** between VPC1 and VPC2 (with routes so Server_1 ↔ Server_2 works)
- [ ] **AWS Network Firewall** policy

### Reliability
- [ ] **State locking** — DynamoDB lock table, or bump to Terraform >= 1.10 and
  enable `use_lockfile` on the S3 backend
- [ ] **Named Terraform outputs** (`outputs.tf`) — expose the Bastion / Invasor
  public IPs and Server_1 private IP instead of reading them from the console

### Security hardening (from Trivy findings)
- [ ] **IMDSv2** — enforce `metadata_options { http_tokens = "required" }` on
  `aws_instance` (Trivy AVD-AWS-0028)
- [ ] **EBS encryption** — `root_block_device { encrypted = true }`
  (Trivy AVD-AWS-0131)
- [ ] **Narrow the Bastion security group** — restrict ingress from
  `0.0.0.0/0` (all ports) to TCP/22, ideally from a known admin CIDR
  (Trivy AVD-AWS-0107)
- [ ] **VPC Flow Logs** (Trivy AVD-AWS-0178)
- [ ] Add `.trivyignore` for the findings that are intentional in this lab
  (public subnets, etc.) so the gate stays meaningful

### CI/CD
- [ ] Add `terraform fmt -check` to the PR pipeline
- [ ] Also run the Trivy scan on `push` to `main` so alerts populate the default
  branch view in the Security tab
- [ ] Mark the Trivy job as a **required status check** on the `main` branch
  protection rule


---

**LinkedIn:** https://www.linkedin.com/in/theo-panella-b079a4201
