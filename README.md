# BastionHost Project

Terraform-based simulation of a Bastion Host (jump server) architecture on AWS.
The goal is to demonstrate how to isolate a private instance so it can only be
reached through a controlled entry point, using NACLs and Security Groups as
layered network controls.

> ⚠️ **Educational use only.** Some configurations (shared SSH key, broad SG rules)
> are intentionally simplified and are **not recommended for production environments**.

---

## Architecture

![Infrastructure Diagram](Diagrama-Infraestrutura.png)

### VPC — `192.168.0.0/24` (us-west-2)

| Resource | Name    | CIDR             | Type    | Instance |
|----------|---------|------------------|---------|----------|
| Subnet A | subnetA | 192.168.0.0/26   | Public  | Bastion  |
| Subnet B | subnetB | 192.168.0.64/26  | Private | Server_1 |
| Subnet C | subnetC | 192.168.0.128/26 | Public  | Invasor  |

### NACL Rules

| NACL        | Direction | Rule | Action | Target                          |
|-------------|-----------|------|--------|---------------------------------|
| ACL_subnetA | in/out    | 1    | allow  | 0.0.0.0/0                       |
| ACL_subnetB | in/out    | 1    | allow  | 192.168.0.0/26 (subnetA)        |
| ACL_subnetB | in/out    | 2    | deny   | 192.168.0.128/26 (subnetC)      |
| ACL_subnetC | in/out    | 1    | allow  | 0.0.0.0/0                       |

### Security Groups

| Group           | Instances        | Ingress / Egress         |
|-----------------|------------------|--------------------------|
| Bastion-Invasor | Bastion, Invasor | All traffic (0.0.0.0/0)  |
| Server_1        | Server_1         | subnetB only             |

---

## Tech Stack

- **Terraform** >= 1.2 / AWS provider ~> 5.92
- **AWS S3** — remote state backend
- **AWS EC2** — Amazon Linux 2023, t3.micro
- **AWS VPC** — subnets, route tables, internet gateway
- **AWS NACLs** — subnet-level traffic control
- **AWS Security Groups** — instance-level traffic control
- **GitHub Actions** — OIDC-authenticated plan/apply pipeline

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

## Deploy

Both paths operate on the same S3 state, so you can mix them freely.

### Via workflow (GitHub Actions)

| Branch | Steps                                     | Applies? |
|--------|-------------------------------------------|----------|
| `dev`  | `init` → `plan`                           | No — plan only, for review |
| `main` | `init` → `validate` → `plan` → **confirm** → `apply` | Yes, after manual approval |

The `main` pipeline pauses and renders the plan in an interactive prompt. Nothing is
applied unless you explicitly check `true`. Credentials come from an OIDC role assumption
(`secrets.ARN`) — no static keys are stored.

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

First, get the public IPs of your instances:

```bash
terraform output
```

Or from the AWS console: EC2 → Instances.

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

## Roadmap

- [ ] State locking (DynamoDB table, or Terraform >= 1.10 + `use_lockfile`)
- [ ] AWS Network Firewall policy
- [ ] VPC_2 with a second Server instance
- [ ] VPC Peering between VPC_1 and VPC_2
- [X] S3 remote backend for shared state
- [X] GitHub Actions pipeline for automated `terraform apply`

---

## Outputs

After `terraform apply`, key information is available via:

```bash
terraform output -json
```

Useful fields:
- `bastion_public_ip` — the Bastion host's public IP
- `invasor_public_ip` — the Invasor instance's public IP
- `server_1_private_ip` — the Server_1 private IP (reachable only from Bastion)

---

**LinkedIn:** https://www.linkedin.com/in/theo-panella-b079a4201
