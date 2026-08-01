# BastionHost Project

<p align="center">
  <img src="bastion.gif" alt="Bastion Host" width="300">
</p>

Terraform-based simulation of a Bastion Host (jump server) architecture on AWS.
The goal is to demonstrate how to isolate a private instance so it can only be
reached through a controlled entry point, using NACLs and Security Groups as
layered network controls.

> ⚠️ **Educational use only.** Some configurations (a single shared SSH key,
> `admin_cidr` defaulting to `0.0.0.0/0`, no IMDSv2 / EBS encryption) are
> intentionally simplified and are **not recommended for production environments**.
> A CI security scan (Trivy) runs on every pull request — see
> [Security Scanning](#security-scanning-trivy) and the [ROADMAP](#roadmap).

---

## Global Architecture

For an end-to-end view of the project, see the
[Complete Architecture file](complete_architecture.md). It traces the flow from the
**commit/push to `main`**, through the **GitHub Actions pipeline** and the
**Terraform S3 remote state (with native locking)**, down to the **complete
infrastructure provisioned on AWS** — two peered VPCs, subnets, NACLs, security
groups and EC2 instances.

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
        dtrivy["Trivy IaC scan (gate)"]
        auth["AWS auth (OIDC) + setup-terraform"]
        tinit["terraform init"]
        tplan["terraform plan"]
        tapply["terraform apply"]
        dtrivy -->|"needs: Trivy"| auth --> tinit --> tplan --> tapply
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

### NACL Rules

Rules are stateless, so each allowed flow is declared twice: SSH (TCP/22) in the
direction the connection is opened, and the ephemeral range (TCP/1024–65535) for
the return traffic.

| NACL         | VPC  | Direction | Rule | Action | Protocol / Ports    | Target                         |
|--------------|------|-----------|------|--------|---------------------|--------------------------------|
| ACL_subnetA  | VPC1 | ingress   | 1    | allow  | TCP 22              | `admin_cidr`                   |
| ACL_subnetA  | VPC1 | ingress   | 2    | allow  | TCP 1024–65535      | 192.168.0.64/26 (subnetB)      |
| ACL_subnetA  | VPC1 | ingress   | 3    | deny   | all                 | 192.168.0.128/26 (subnetC)     |
| ACL_subnetA  | VPC1 | egress    | 1    | allow  | TCP 1024–65535      | `admin_cidr`                   |
| ACL_subnetA  | VPC1 | egress    | 2    | allow  | TCP 22              | 192.168.0.64/26 (subnetB)      |
| ACL_subnetA  | VPC1 | egress    | 3    | deny   | all                 | 192.168.0.128/26 (subnetC)     |
| ACL_subnetB  | VPC1 | ingress   | 1    | allow  | TCP 22              | 192.168.0.0/26 (subnetA)       |
| ACL_subnetB  | VPC1 | ingress   | 2    | allow  | TCP 1024–65535      | 172.18.0.0/26 (subnetA_VPC2)   |
| ACL_subnetB  | VPC1 | ingress   | 3    | deny   | all                 | 192.168.0.128/26 (subnetC)     |
| ACL_subnetB  | VPC1 | egress    | 1    | allow  | TCP 1024–65535      | 192.168.0.0/26 (subnetA)       |
| ACL_subnetB  | VPC1 | egress    | 2    | allow  | TCP 22              | 172.18.0.0/26 (subnetA_VPC2)   |
| ACL_subnetB  | VPC1 | egress    | 3    | deny   | all                 | 192.168.0.128/26 (subnetC)     |
| ACL_subnetC  | VPC1 | in/out    | 1    | allow  | all                 | `admin_cidr`                   |
| subnetA_VPC2 | VPC2 | ingress   | 1    | allow  | TCP 22              | 192.168.0.64/26 (subnetB)      |
| subnetA_VPC2 | VPC2 | egress    | 1    | allow  | TCP 1024–65535      | 192.168.0.64/26 (subnetB)      |

> `admin_cidr` is the CIDR allowed to SSH into the public subnet, set in
> `terraform.tfvars` (`0.0.0.0/0` by default) — narrow it to your own address for
> a tighter setup, see [Prerequisites](#prerequisites).

### Security Groups

| Group           | VPC  | Instances        | Ingress                                                        | Egress                                                          |
|-----------------|------|------------------|----------------------------------------------------------------|-----------------------------------------------------------------|
| Bastion-Invasor | VPC1 | Bastion, Invasor | TCP 22 from `admin_cidr` · TCP 1024–65535 from subnetB          | TCP 1024–65535 to `admin_cidr` · TCP 22 to subnetB               |
| Server_1        | VPC1 | Server_1         | TCP 22 from subnetA · TCP 1024–65535 from subnetA_VPC2          | TCP 1024–65535 to subnetA · TCP 22 to subnetA_VPC2              |
| Server_2        | VPC2 | Server_2         | TCP 22 from subnetB                                            | TCP 1024–65535 to subnetB                                       |

> Server_1 only accepts SSH from **subnetA** (the Bastion subnet) and return
> traffic from **subnetA_VPC2** (Server_2, over the peering). Combined with
> `ACL_subnetB` rule 3, which denies subnetC, this is what blocks the Invasor
> from reaching Server_1. Server_2 in turn only talks to **subnetB** — it is
> unreachable from the public subnets entirely.

---

## Repository Layout

The configuration is split by responsibility instead of living in a single
`main.tf`, and every value is declared in `terraform.tfvars` rather than as a
variable default:

| File               | Contents                                                                                     |
|--------------------|----------------------------------------------------------------------------------------------|
| `Network.tf`       | VPCs, subnets, internet gateway, NACLs, route tables + associations, VPC peering and its routes |
| `Computer.tf`      | AWS provider, AMI data source, security groups, EC2 instances, SSH key pair                    |
| `variables.tf`     | Variable **declarations** (typed, no defaults) + the `ACLs` and `Security_groups` locals       |
| `terraform.tfvars` | Variable **values** — `admin_cidr`, VPC CIDRs, subnets, instance type and the EC2 → subnet/SG mapping |
| `terraform.tf`     | Required providers/version and the S3 backend                                                  |
| `outputs.tf`       | Public and private IP maps of every instance                                                   |

Because the variables are typed and have no defaults, `terraform.tfvars` is
committed and required — Terraform loads it automatically on `plan`/`apply`,
both locally and in CI. The NACL and security-group rules stay in
`variables.tf` as `locals` since they reference `var.admin_cidr` and other
subnets' CIDRs.

One variable is deliberately **not** in `terraform.tfvars`: `ssh_key` is marked
`sensitive` and holds the **public** key material used by `aws_key_pair`, so it
is supplied at run time instead of being committed — see
[Prerequisites](#prerequisites).

### Input Variables

| Variable                  | Type                | Source             | Description                                                        |
|---------------------------|---------------------|--------------------|--------------------------------------------------------------------|
| `admin_cidr`              | `string`            | `terraform.tfvars` | CIDR allowed to SSH into the public subnet — drives `ACL_subnetA`, `ACL_subnetC` and the `Bastion-Invasor` SG |
| `ssh_key`                 | `string` (sensitive)| runtime / CI secret| Public key material for `aws_key_pair` — never committed            |
| `vpc_configs`             | `map(object)`       | `terraform.tfvars` | VPC name → CIDR block                                               |
| `subnets`                 | `map(object)`       | `terraform.tfvars` | Subnet name → CIDR, AZ, `ip_publico`, parent VPC                    |
| `instance_configurations` | `object`            | `terraform.tfvars` | AMI `most_recent` flag and `instance_type` (both optional)          |
| `EC2_instances`           | `map(object)`       | `terraform.tfvars` | Instance name → subnet and security group                           |

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
`terraform.tf`). This feature requires Terraform >= 1.10; the pipeline pins 1.12, so
both CI and a compatible local Terraform acquire a lock (a `.tflock` object in the
bucket) for the duration of a `plan`/`apply`. There is **no DynamoDB lock table** —
locking is handled entirely by S3.

In practice this prevents two `apply` operations from writing state at the same time:
if a run is already in flight, a second one waits for (or fails to acquire) the lock
instead of corrupting the state file. If a local run reports a lock it cannot acquire,
check the Actions tab — a pipeline run is probably holding it.

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.2 — note
  the S3 native state locking (`use_lockfile`) requires **>= 1.10**; the pipeline
  pins **1.12**, so use a compatible local version to share the lock
- **AWS credentials** — for local use, your AWS session must have access to the S3 state bucket (`aws-panella-bucket2`) and the target account; for CI, the workflow uses OIDC role assumption via `secrets.ARN`
- An SSH key pair — the private half stays on your machine, the **public** half is
  passed to Terraform through the `ssh_key` variable

Generate the SSH key if you don't have one:
```bash
ssh-keygen -t rsa -b 4096 -f .ssh/terraform-key -N ""
```

**`ssh_key` variable:** `aws_key_pair` reads `var.ssh_key`, which is declared `sensitive` and has no default, so it
must be supplied on every run.

```bash
# environment variable (same mechanism the pipeline uses)
export TF_VAR_ssh_key="$(cat .ssh/terraform-key.pub)"
terraform plan
```

In CI the value comes from the `SSH_KEY_EC2_AWS` secret, exported as
`TF_VAR_ssh_key` — see [CI/CD Pipelines](#cicd-pipelines).

**Allowed SSH source:** both `ACL_subnetA` and the `Bastion-Invasor` security group
allow SSH from `var.admin_cidr`, set to `0.0.0.0/0` in `terraform.tfvars` so the lab
works out of the box. For a tighter setup, point it at your own address:
```bash
curl -s https://checkip.amazonaws.com   # → admin_cidr = "<your-ip>/32"
```

**Variable values:** `terraform.tfvars` is committed and holds `admin_cidr`, the VPC
CIDRs, subnets, instance type and the EC2 → subnet/SG mapping. The variables in
`variables.tf` have no defaults, so this file (or an equivalent `-var-file`) is
required — see [Repository Layout](#repository-layout).

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
| `deploy_main.yaml`| Push to `main`         | **Trivy** scan → `init` → `fmt -check` → `validate` → `plan` → **`apply`** | Yes |

Both the PR and the `main` deploy pipelines run in two dependent jobs: the
`Configuration` job has `needs: Trivy`, so **`plan`/`apply` only run if the
security scan passes**. Merging to `main` then triggers `deploy_main.yaml`, which
re-runs the Trivy gate and applies automatically.

### Supplying the SSH key in CI

No workflow writes a key file to the runner anymore — the public key reaches
Terraform as an environment variable, which it picks up as `var.ssh_key`.

`deploy_dev.yaml` sets it on the `plan` step:

```yaml
- name: "terraform plan"
  run: terraform plan
  env:
    TF_VAR_ssh_key: ${{ secrets.SSH_KEY_EC2_AWS }}
```

`pr_main.yaml` and `deploy_main.yaml` declare it once at workflow level, so both
`plan` and `apply` inherit it:

```yaml
env:
  TF_VAR_ssh_key: ${{ secrets.SSH_KEY_EC2_AWS }}
```

> Only the **public** key is needed — `aws_key_pair` registers it and the private
> half never touches the runner.

---

## Security Scanning (Trivy)

Every PR against `main` — and every push to `main` — runs
[Trivy](https://trivy.dev) in IaC (`config`) mode:

- **Gate:** `CRITICAL,HIGH` findings fail the run and block the `plan`/`apply` job.
- **Reporting:** results go as SARIF to **GitHub Security tab → Code scanning**
  (filter by the branch).
- **Suppressions:** the scan runs with `TRIVY_IGNOREFILE: .trivyignore`.

The checks currently suppressed in `.trivyignore` are the ones that are intentional
for this lab:

| AVD ID        | Finding                                    |
|---------------|--------------------------------------------|
| AVD-AWS-0104  | SG with unrestricted egress                |
| AVD-AWS-0107  | SG allowing SSH from a public CIDR          |
| AVD-AWS-0164  | Subnet with `map_public_ip_on_launch`       |
| AVD-AWS-0131  | Unencrypted EBS root volume                 |
| AVD-AWS-0028  | EC2 instance not enforcing IMDSv2           |

Hardening for the last two (and for VPC Flow Logs, which is not suppressed) is
tracked in the [ROADMAP](#roadmap).

---

## Deploy

Both paths operate on the same S3 state, so you can mix them freely.

### Via workflow (GitHub Actions)

Open a pull request to `main` to get a security scan + plan, then merge to apply.
See [CI/CD Pipelines](#cicd-pipelines) above for the full matrix.

### Local

```bash
export TF_VAR_ssh_key="$(cat .ssh/terraform-key.pub)"
terraform init
terraform plan
terraform apply
```

`TF_VAR_ssh_key` is required — see [Prerequisites](#prerequisites) for the
alternatives (`-var` flag or a `secret.auto.tfvars` file).

### Teardown

There is no destroy job in the pipeline — teardown is **local only**, and works against
pipeline-created infrastructure thanks to the shared backend:

```bash
export TF_VAR_ssh_key="$(cat .ssh/terraform-key.pub)"
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

  - [ ] **AWS Network Firewall policy ⚠️Need to do it out of free plan⚠️**
  - [ ] **SSM Session Manager** instead of SSH connection

### ✅ Done
  - [X] **Split `main.tf`** into `Network.tf` (VPCs, subnets, NACLs, routing, peering)
    and `Computer.tf` (provider, AMI, security groups, instances, key pair)
  - [X] **Typed variables + `terraform.tfvars`** — variable declarations no longer carry
    inline defaults; every value lives in `terraform.tfvars`
  - [X] Route tables + associations for VPC2 subnets
  - [X] NACLs / security groups scoped to VPC2
  - [X] A second Server instance (`Server_2`) in VPC2
  - [X] **Named Terraform outputs** (`outputs.tf`) — expose the public and private
    IPs of every instance instead of reading them from the console
  - [X] **Harden NACLs and security groups** — replace the `allow all` rules with
    specific protocols and port ranges (TCP/22 + ephemeral)
  - [X] **VPC peering** between VPC1 and VPC2 (with routes so Server_1 ↔ Server_2 works)
  - [X] **State locking** — enable `use_lockfile` on the S3 backend

---

## ⏳ Planned

### Security hardening (from Trivy findings)
> Most of these findings are suppressed in `.trivyignore` (so the gate stays
> meaningful for *unexpected* issues) and are tracked here to be **fixed** later —
> removing each AVD from `.trivyignore` once the corresponding hardening lands.

- [ ] **IMDSv2** — enforce `metadata_options { http_tokens = "required" }` on
  `aws_instance` (Trivy AVD-AWS-0028)
- [ ] **EBS encryption** — `root_block_device { encrypted = true }`
  (Trivy AVD-AWS-0131)
- [ ] **VPC Flow Logs** (Trivy AVD-AWS-0178 — not suppressed)
- [X] **Make the allowed SSH CIDR a variable** — `admin_cidr` drives the `ACLs` and
  `Security_groups` locals, so tightening the source address is a `terraform.tfvars`
  edit (Trivy AVD-AWS-0107 stays suppressed while it defaults to `0.0.0.0/0`)
- [X] **Keep the SSH public key out of the repo** — `aws_key_pair` reads the
  `sensitive` `ssh_key` variable instead of `file(".ssh/terraform-key.pub")`
- [X] **Narrow the Bastion security group** — ingress restricted to TCP/22 instead of
  all traffic (Trivy AVD-AWS-0107 — still suppressed while the source CIDR is
  `0.0.0.0/0`)
- [X] Add `.trivyignore` for the findings that are intentional in this lab
  (public subnets, etc.) so the gate stays meaningful

### CI/CD
- [X] **Pass the SSH public key via `TF_VAR_ssh_key` in all three workflows** —
  no runner writes `.ssh/terraform-key{,.pub}` from secrets anymore
- [ ] Drop the now-unused `SSH_KEY_EC2_AWS_PRIVATE` repository secret, and scope
  `TF_VAR_ssh_key` to the `Configuration` job so the `Trivy` job stops inheriting it
- [X] Add `terraform fmt -check` to the PR pipeline
- [X] Also run the Trivy scan on `push` to `main` so alerts populate the default
  branch view in the Security tab
- [ ] Mark the Trivy job as a **required status check** on the `main` branch
  protection rule


---

**LinkedIn:** https://www.linkedin.com/in/theo-panella-b079a4201
