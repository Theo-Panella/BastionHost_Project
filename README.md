# BastionHost Project

Terraform-based simulation of a Bastion Host (jump server) architecture on AWS.
The goal is to demonstrate how to isolate a private instance so it can only be
reached through a controlled entry point, using NACLs and Security Groups as
layered network controls.

> ⚠️ **Educational use only.** Some configurations (shared SSH key, broad SG rules)
> are intentionally simplified and are **not recommended for production environments**.
> A CI security scan (Trivy) flags these on every pull request — see
> [Security Scanning](#security-scanning-trivy) and the [ROADMAP](#roadmap).

---

## Global Architecture

An end-to-end view of the project: at [Complete Architecture file](complete_architecture.md) from the **commit/push to `main`**, through the
**GitHub Actions pipeline** and the **Terraform S3 remote state (with native locking)**,
down to the **complete infrastructure provisioned on AWS** — two peered VPCs, subnets,
NACLs, security groups and EC2 instances.

## Resume Architecture

```mermaid
flowchart TD
    %% ===================== DESKTOP =====================
    subgraph DEV["💻 Developer Desktop"]
        push["git push / open Pull Request"]
    end

    %% ===================== GITHUB =====================
    subgraph GH["🐙 GitHub"]
        pr{{"pull_request → main"}}
        merge{{"push → main"}}
    end

    %% ===================== PR PIPELINE (TRIVY) =====================
    subgraph PRWF["🛡️ pr_main.yaml — security gate"]
        direction TB
        trivy["Trivy IaC scan (config)<br/>severity: CRITICAL,HIGH · exit-code 1"]
        gate{"findings?"}
        sarif["Upload SARIF →<br/>GitHub Security tab"]
        prplan["terraform plan<br/>(needs: Trivy)"]
        trivy --> gate
        gate -->|"CRITICAL/HIGH"| fail["❌ fails the PR<br/>blocks plan"]
        gate -->|"clean"| prplan
        trivy --> sarif
    end

    %% ===================== DEPLOY PIPELINE =====================
    subgraph WF["⚙️ deploy_main.yaml — deploy"]
        direction TB
        auth["AWS auth (OIDC) + setup-terraform"]
        tinit["terraform init"]
        tplan["terraform plan"]
        tapply["terraform apply"]
        auth --> tinit --> tplan --> tapply
    end

    %% ===================== BACKEND / STATE =====================
    subgraph BK["🗄️ S3 Backend (us-east-1)"]
        state["terraform.tfstate + 🔒 lock<br/>(use_lockfile = true)"]
    end

    %% ===================== AWS PROVIDER =====================
    subgraph AWS["☁️ AWS (us-west-2)"]
        direction TB
        subgraph VPC1["VPC1 — 192.168.0.0/24"]
            bastion["EC2 Bastion<br/>subnetA · public"]
            invasor["EC2 Invasor<br/>subnetC · public"]
            server1["EC2 Server_1<br/>subnetB · private"]
        end
        subgraph VPC2["VPC2 — 172.18.0.0/24"]
            server2["EC2 Server_2<br/>subnetA_VPC2 · no IGW"]
        end
        peering["🔗 VPC Peering"]
    end

    %% ===================== FLOW =====================
    push --> pr
    push --> merge
    pr --> trivy
    merge --> trivy
    prplan -.->|"merge after approval"| merge
    merge --> auth
    tinit --> state
    tapply ==> VPC1
    tapply ==> VPC2
    tapply ==> peering

    %% ---- Traffic path ----
    bastion -->|"✅ SSH jump"| server1
    invasor -.->|"❌ blocked (deny rule 3)"| server1
    server1 <-->|"✅ subnetB ↔ subnetA_VPC2"| peering
    peering <--> server2

    %% ===================== STYLES =====================
    classDef dev fill:#e3f2fd,stroke:#1565c0,color:#0d47a1;
    classDef gh fill:#ede7f6,stroke:#5e35b1,color:#311b92;
    classDef trivy fill:#fce4ec,stroke:#ad1457,color:#880e4f;
    classDef wf fill:#fff3e0,stroke:#ef6c00,color:#e65100;
    classDef bk fill:#f1f8e9,stroke:#558b2f,color:#33691e;
    classDef ec2 fill:#fbe9e7,stroke:#d84315,color:#bf360c;
    classDef block fill:#ffebee,stroke:#c62828,color:#b71c1c;

    class push dev;
    class pr,merge gh;
    class trivy,gate,sarif,prplan trivy;
    class auth,tinit,tplan,tapply wf;
    class state bk;
    class bastion,invasor,server1,server2 ec2;
    class fail,invasor block;
  ```

  The stack provisions **two VPCs** in `us-west-2`. VPC1 holds the full
  bastion/jump-server scenario; VPC2 hosts a second private server (`Server_2`),
  reachable from VPC1 through a **VPC peering connection** (see
  [VPC Peering](#vpc-peering-vpc1--vpc2) below).

  ### VPC1 — `192.168.0.0/24`

  | Resource | Name    | CIDR             | Type    | Instance |
  |----------|---------|------------------|---------|----------|
  | Subnet A | subnetA | 192.168.0.0/26   | Public  | Bastion  |
  | Subnet B | subnetB | 192.168.0.64/26  | Private | Server_1 |
  | Subnet C | subnetC | 192.168.0.128/26 | Public  | Invasor  |

  ### VPC2 — `172.18.0.0/24`

  | Resource | Name         | CIDR           | Type    | Instance |
  |----------|--------------|----------------|---------|----------|
  | Subnet A | subnetA_VPC2 | 172.18.0.0/26  | Private | Server_2 |

  > VPC2 now has its own private route table, a NACL and a security group scoped
  > to it, and hosts `Server_2`. It has **no internet gateway** — the only way in
  > or out is the peering connection with VPC1, restricted to subnetB (Server_1).

  ### VPC Peering (VPC1 ↔ VPC2)

  An `aws_vpc_peering_connection` links the two VPCs (`auto_accept = true`, both
VPCs live in the same account/region). Two `aws_route` entries make the private
subnets routable across it:

| Route          | Route table              | Destination                | Target  |
|----------------|--------------------------|----------------------------|---------|
| `vpc1_to_vpc2` | private_route_table VPC1 | 172.18.0.0/24 (VPC2 CIDR)  | peering |
| `vpc2_to_vpc1` | private_route_table VPC2 | 192.168.0.0/24 (VPC1 CIDR) | peering |

Routing alone doesn't open traffic: the NACLs and security groups below only
allow **subnetB ↔ subnetA_VPC2**, so the peering effectively connects
`Server_1` and `Server_2` and nothing else.

### VPC2 — `172.18.0.0/24`

| Resource | Name         | CIDR           | Type    | Instance |
|----------|--------------|----------------|---------|----------|
| Subnet A | subnetA_VPC2 | 172.18.0.0/26  | Private | Server_2 |

> VPC2 now has its own private route table, a NACL and a security group scoped
> to it, and hosts `Server_2`. It has **no internet gateway** — the only way in
> or out is the peering connection with VPC1, restricted to subnetB (Server_1).

### VPC Peering (VPC1 ↔ VPC2)

An `aws_vpc_peering_connection` links the two VPCs (`auto_accept = true`, both
VPCs live in the same account/region). Two `aws_route` entries make the private
subnets routable across it:

| Route          | Route table              | Destination                | Target  |
|----------------|--------------------------|----------------------------|---------|
| `vpc1_to_vpc2` | private_route_table VPC1 | 172.18.0.0/24 (VPC2 CIDR)  | peering |
| `vpc2_to_vpc1` | private_route_table VPC2 | 192.168.0.0/24 (VPC1 CIDR) | peering |

Routing alone doesn't open traffic: the NACLs and security groups below only
allow **subnetB ↔ subnetA_VPC2**, so the peering effectively connects
`Server_1` and `Server_2` and nothing else.

### NACL Rules

| NACL         | VPC  | Direction | Rule | Action | Target                          |
|--------------|------|-----------|------|--------|---------------------------------|
| ACL_subnetA  | VPC1 | in/out    | 1    | allow  | 0.0.0.0/0                       |
| ACL_subnetB  | VPC1 | in/out    | 1    | allow  | 192.168.0.0/26 (subnetA)        |
| ACL_subnetB  | VPC1 | in/out    | 2    | allow  | 172.18.0.0/26 (subnetA_VPC2)    |
| ACL_subnetB  | VPC1 | in/out    | 3    | deny   | 192.168.0.128/26 (subnetC)      |
| ACL_subnetC  | VPC1 | in/out    | 1    | allow  | 0.0.0.0/0                       |
| subnetA_VPC2 | VPC2 | in/out    | 1    | allow  | 192.168.0.64/26 (subnetB)       |

### Security Groups

| Group           | VPC  | Instances        | Ingress / Egress                                        |
|-----------------|------|------------------|---------------------------------------------------------|
| Bastion-Invasor | VPC1 | Bastion, Invasor | All traffic (0.0.0.0/0)                                 |
| Server_1        | VPC1 | Server_1         | subnetA (`192.168.0.0/26`) + subnetA_VPC2 (`172.18.0.0/26`) |
| Server_2        | VPC2 | Server_2         | subnetB only (`192.168.0.64/26`)                        |

> Server_1 only accepts traffic from **subnetA** (the Bastion subnet) and
> **subnetA_VPC2** (Server_2, over the peering). Combined with `ACL_subnetB`
> rule 3, which denies subnetC, this is what blocks the Invasor from reaching
> Server_1. Server_2 in turn only talks to **subnetB** — it is unreachable from
> the public subnets entirely.

---

## Tech Stack

- **Terraform** >= 1.2 / AWS provider ~> 5.92
- **AWS S3** — remote state backend
- **AWS EC2** — Amazon Linux 2023, t3.micro
- **AWS VPC** — two VPCs, subnets, route tables, internet gateway, VPC peering
- **AWS NACLs** — subnet-level traffic control
- **AWS Security Groups** — instance-level traffic control
- **GitHub Actions** — OIDC-authenticated plan/apply pipeline
- **Trivy** — Infrastructure-as-Code security scanning on every PR (SARIF)

---

## Remote State (S3 Backend)

State lives in S3 instead of a local `terraform.tfstate` file:

```hcl
backend "s3" {
  bucket       = "aws-panella-bucket2"
  key          = "terraform.tfstate"
  region       = "us-east-1"
  use_lockfile = true
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

### State locking (S3 native)

State locking is **enabled** via S3 native locking (`use_lockfile = true` in
`terraform.tf`). This feature requires Terraform >= 1.10; the pipeline pins 1.11, so
both CI and a compatible local Terraform acquire a lock (a `.tflock` object in the
bucket) for the duration of a `plan`/`apply`. There is **no DynamoDB lock table** —
locking is handled entirely by S3.

In practice this prevents two `apply` operations from writing state at the same time:
if a run is already in flight, a second one waits for (or fails to acquire) the lock
instead of corrupting the state file. If a local run reports a lock it cannot acquire,
check the Actions tab — a pipeline run is probably holding it.

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
| `pr_main.yaml`    | Pull request → `main`  | **Trivy** scan → `init` → `fmt -check` → `validate` → `plan`         | No — gate + review |
| `deploy_dev.yaml` | Push to `dev`          | `init` → `fmt -check` → `plan`                                       | No — plan only |
| `deploy_main.yaml`| Push to `main`         | `init` → `fmt -check` → `validate` → `plan` → **`apply`**            | Yes |

The PR pipeline runs in two dependent jobs: the `Configuration` job (`terraform
plan`) has `needs: Trivy`, so **the plan only runs if the security scan passes**.
Merging to `main` then triggers `deploy_main.yaml`, which applies automatically.

---

## Security Scanning (Trivy)

Every PR against `main` runs [Trivy](https://trivy.dev) in IaC (`config`) mode:

- **Gate:** `CRITICAL,HIGH` findings fail the PR and block the `plan` job.
- **Reporting:** results go as SARIF to **GitHub Security tab → Code scanning**
  (filter by the PR branch).

Known findings are intentional for this lab (bastion SG open to `0.0.0.0/0`,
public subnets, no IMDSv2/EBS encryption) — hardening is tracked in the
[ROADMAP](#roadmap).

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

## Terraform Outputs

Named outputs are defined in `outputs.tf` — after an `apply` (or anytime via
`terraform output`) you get the IPs of every instance without opening the console:

| Output                | Content                                            |
|-----------------------|----------------------------------------------------|
| `instance_ip`         | Map of instance name → **public IP** (private-only instances show empty) |
| `instance_private_ip` | Map of instance name → **private IP**              |

```bash
terraform output instance_ip
terraform output instance_private_ip
```

---

## Testing

Get the IPs of your instances from the [Terraform outputs](#terraform-outputs)
above (or from the AWS console, EC2 → Instances).

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

The connection will hang indefinitely — blocked by ACL_subnetB rule 3 (deny from subnetC).
This confirms the network isolation is working correctly.

### 4. Cross-VPC: reach Server_2 through the peering

From Server_1 (reached via the Bastion in step 2), hop to Server_2 in VPC2:

```bash
[ec2-user@server_1 ~]$ ssh ec2-user@<Server_2_Private_IP>
```

A successful login confirms the peering routes (`vpc1_to_vpc2` / `vpc2_to_vpc1`)
and the subnetB ↔ subnetA_VPC2 NACL/SG rules are working. Server_2 has no public
IP and accepts traffic **only** from subnetB, so this jump path
(Bastion → Server_1 → Server_2) is the only way to reach it.

---

# Roadmap

## 🚧 In progress

- **VPC2 build-out** — the VPC and `subnetA_VPC2` exist, but there is no internet
  gateway, route table, NACL or security group scoped to VPC2 yet, so it has no
  instances or connectivity. Next steps:
  - [X] Route tables + associations for VPC2 subnets
  - [X] NACLs / security groups scoped to VPC2
  - [X] A second Server instance (`Server_2`) in VPC2
  - [X] **Named Terraform outputs** (`outputs.tf`) — expose the Bastion / Invasor
    public IPs and Server_1 private IP instead of reading them from the console
  - [X] **VPC peering** between VPC1 and VPC2 (with routes so Server_1 ↔ Server_2 works)
  - [X] **State locking** — enable `use_lockfile` on the S3 backend
  - [ ] **AWS Network Firewall policy ⚠️Need to do it out of free plan⚠️**
  - [ ] **SSM Session Manager** instead of SSH connection

---

## ⏳ Planned

### Security hardening (from Trivy findings)
- [ ] **IMDSv2** — enforce `metadata_options { http_tokens = "required" }` on
  `aws_instance` (Trivy AVD-AWS-0028)
- [ ] **EBS encryption** — `root_block_device { encrypted = true }`
  (Trivy AVD-AWS-0131)
- [ ] **Narrow the Bastion security group** — restrict ingress from
  `0.0.0.0/0` (all ports) to TCP/22, ideally from a known admin CIDR
  (Trivy AVD-AWS-0107)
- [ ] **VPC Flow Logs** (Trivy AVD-AWS-0178)
- [X] Add `.trivyignore` for the findings that are intentional in this lab
  (public subnets, etc.) so the gate stays meaningful

### CI/CD
- [X] Add `terraform fmt -check` to the PR pipeline
- [X] Also run the Trivy scan on `push` to `main` so alerts populate the default
  branch view in the Security tab
- [ ] Mark the Trivy job as a **required status check** on the `main` branch
  protection rule


---

**LinkedIn:** https://www.linkedin.com/in/theo-panella-b079a4201
