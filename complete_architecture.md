```mermaid
flowchart TD
    %% ===================== DESKTOP =====================
    subgraph DEV["💻 Developer Desktop"]
        direction TB
        code["Edits Terraform files<br/>Network.tf · Computer.tf · variables.tf<br/>terraform.tfvars · terraform.tf · outputs.tf"]
        commit["git commit"]
        push["git push origin main"]
        code --> commit --> push
    end

    %% ===================== GITHUB =====================
    subgraph GH["🐙 GitHub"]
        direction TB
        mainbranch["main branch<br/>receives the push"]
        trigger{{"Event: push to main<br/>on.push.branches: [main]"}}
        prflow["pr_main.yaml<br/>(Trivy + plan on Pull Request)"]
        devflow["deploy_dev.yaml<br/>(plan-only on dev branch)"]
        mainbranch --> trigger
    end

    %% ===================== WORKFLOW =====================
    subgraph WF["⚙️ GitHub Actions — deploy_main.yaml (Configuration job)"]
        direction TB
        checkout["1 · actions/checkout@v4<br/>clones the repository on the runner"]
        ssh["2 · Creates SSH credentials<br/>.ssh/terraform-key (+ .pub) via secrets"]
        oidc["3 · Configure AWS credentials<br/>OIDC · role-to-assume = secrets.ARN"]
        setuptf["4 · setup-terraform@v3<br/>terraform_version 1.12"]
        tinit["5 · terraform init"]
        tfmt["6 · terraform fmt -check -recursive"]
        tval["7 · terraform validate"]
        tplan["8 · terraform plan -out=tfplan"]
        tapply["9 · terraform apply tfplan"]

        checkout --> ssh --> oidc --> setuptf --> tinit
        tinit --> tfmt --> tval --> tplan --> tapply
    end

    %% ===================== BACKEND / STATE =====================
    subgraph BK["🗄️ Remote Backend (S3 · us-east-1)"]
        direction TB
        s3["S3 Bucket<br/>aws-panella-bucket2"]
        state["terraform.tfstate<br/>(shared state)"]
        lock["🔒 Native S3 Lock<br/>.tflock object<br/>(use_lockfile = true)"]
        s3 --- state
        s3 --- lock
    end

    %% ===================== AWS PROVIDER =====================
    subgraph AWS["☁️ AWS Provider (us-west-2)"]
        direction TB
        ami["data.aws_ami.linux<br/>Amazon Linux 2023 · x86_64"]

        subgraph VPC1["VPC1 — 192.168.0.0/24"]
            direction TB
            igw["Internet Gateway<br/>main-igw"]
            pubrt["Public Route Table<br/>0.0.0.0/0 → IGW"]
            privrt1["Private Route Table VPC1"]

            snA["subnetA · 192.168.0.0/26<br/>Public"]
            snB["subnetB · 192.168.0.64/26<br/>Private"]
            snC["subnetC · 192.168.0.128/26<br/>Public"]

            aclA["NACL ACL_subnetA<br/>tcp/22 from admin_cidr<br/>allow B · deny C"]
            aclB["NACL ACL_subnetB<br/>tcp/22 from A · allow VPC2 · deny C"]
            aclC["NACL ACL_subnetC<br/>allow admin_cidr"]

            sgBI["SG Bastion-Invasor<br/>tcp/22 from admin_cidr<br/>+ ephemeral from subnetB"]
            sgS1["SG Server_1<br/>tcp/22 from subnetA<br/>+ ephemeral from subnetA_VPC2"]

            bastion["EC2 Bastion<br/>subnetA · public"]
            invasor["EC2 Invasor<br/>subnetC · public"]
            server1["EC2 Server_1<br/>subnetB · private"]
        end

        subgraph VPC2["VPC2 — 172.18.0.0/24"]
            direction TB
            privrt2["Private Route Table VPC2"]
            snA2["subnetA_VPC2 · 172.18.0.0/26<br/>Private · no IGW"]
            acl2["NACL subnetA_VPC2<br/>tcp/22 from subnetB"]
            sgS2["SG Server_2<br/>tcp/22 from subnetB only"]
            server2["EC2 Server_2<br/>private"]
        end

        peering["🔗 VPC Peering Connection<br/>VPC1 ↔ VPC2 · auto_accept"]
        keypair["aws_key_pair<br/>SSH Key ← var.ssh_key (sensitive)"]
    end

    %% ===================== OUTPUTS =====================
    subgraph OUT["📤 Outputs"]
        direction TB
        outip["instance_ip<br/>(public IPs)"]
        outpriv["instance_private_ip<br/>(private IPs)"]
    end

    %% ===================== FLOW CONNECTIONS =====================
    push --> mainbranch
    trigger -->|"pull_request → main"| prflow
    trigger -->|"push → dev"| devflow
    trigger -->|"push → main"| checkout

    %% Auth and backend
    oidc -. "assume role STS" .-> AWS
    tinit -->|"configures s3 backend"| s3
    tinit -->|"acquires lock"| lock
    tplan -->|"reads state"| state
    tapply -->|"writes state + releases lock"| state
    tapply -.->|"releases 🔒"| lock

    %% Apply creates the infra
    tapply ==> ami
    tapply ==> VPC1
    tapply ==> VPC2
    tapply ==> peering
    tapply ==> keypair

    %% ---- VPC1 Interconnection ----
    igw --> pubrt
    pubrt --> snA
    pubrt --> snC
    privrt1 --> snB

    aclA --- snA
    aclB --- snB
    aclC --- snC

    snA --> bastion
    snC --> invasor
    snB --> server1

    sgBI --- bastion
    sgBI --- invasor
    sgS1 --- server1

    ami --> bastion
    ami --> invasor
    ami --> server1
    ami --> server2
    keypair --> bastion
    keypair --> invasor
    keypair --> server1
    keypair --> server2

    %% ---- VPC2 Interconnection ----
    privrt2 --> snA2
    acl2 --- snA2
    snA2 --> server2
    sgS2 --- server2

    %% ---- Peering (cross routes) ----
    privrt1 -->|"vpc1_to_vpc2<br/>→ 172.18.0.0/24"| peering
    privrt2 -->|"vpc2_to_vpc1<br/>→ 192.168.0.0/24"| peering

    %% ---- Traffic path (jump path) ----
    bastion -.->|"SSH jump"| server1
    server1 -.->|"peering · subnetB↔A_VPC2"| server2
    invasor -.->|"❌ blocked (deny rule 3)"| server1

    %% ---- Outputs ----
    bastion --> outip
    invasor --> outip
    server1 --> outpriv
    server2 --> outpriv

    %% ===================== STYLES =====================
    classDef dev fill:#e3f2fd,stroke:#1565c0,color:#0d47a1;
    classDef gh fill:#ede7f6,stroke:#5e35b1,color:#311b92;
    classDef wf fill:#fff3e0,stroke:#ef6c00,color:#e65100;
    classDef bk fill:#f1f8e9,stroke:#558b2f,color:#33691e;
    classDef net fill:#e0f7fa,stroke:#00838f,color:#006064;
    classDef ec2 fill:#fbe9e7,stroke:#d84315,color:#bf360c;
    classDef block fill:#ffebee,stroke:#c62828,color:#b71c1c;

    class code,commit,push dev;
    class mainbranch,trigger,prflow,devflow gh;
    class checkout,ssh,oidc,setuptf,tinit,tfmt,tval,tplan,tapply wf;
    class s3,state,lock,outip,outpriv bk;
    class bastion,invasor,server1,server2 ec2;
  ```