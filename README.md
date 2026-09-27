# AWS DevOps Simulation

A self-directed simulation of junior AWS DevOps day-to-day work: automated CI/CD, infrastructure as code, and observability, built and iterated on the same way a real engineer would encounter it — starting from manually-clicked infrastructure and progressively hardening it.

This repo isn't a tutorial follow-along. Each stage started as a "ticket" with acceptance criteria, and the infrastructure evolved through real debugging — including several mistakes that got caught and fixed along the way, documented below because the debugging process is the actual point.

## What this demonstrates

- Designing and debugging a CI/CD pipeline that deploys over AWS Systems Manager (no SSH, no long-lived inbound access)
- Writing least-privilege IAM policies from first principles, including scoping by resource tag rather than hardcoded resource IDs
- Migrating hand-created ("ClickOps") infrastructure into Terraform via `terraform import`, without downtime
- Refactoring working infrastructure into a reusable Terraform module, backed by `terraform state mv` to preserve existing state
- Setting up CloudWatch alarms, SNS notifications, and a monitoring dashboard across two environments

## Architecture

```
GitHub Actions (CI/CD)
   │
   ├── test stage → runs on every push
   │
   └── deploy stage (only if tests pass)
         │
         ├── authenticate via scoped IAM user (SSM permissions only)
         ├── look up target EC2 instance by tag (Environment=dev|staging)
         └── deploy via AWS Systems Manager Send-Command
                │
                ▼
      EC2 instance (Amazon Linux 2023)
         ├── Node.js / Express app, managed by pm2
         ├── IAM instance role: AmazonSSMManagedInstanceCore + CloudWatchAgentServerPolicy
         └── monitored by CloudWatch (status checks, CPU) → SNS → email alerts
```

Two parallel environments (`dev`, `staging`) are provisioned from a single Terraform module, each with its own EC2 instance, security group, IAM role, SNS topic, and alarms.

## Stack

- **App:** Node.js, Express, Jest
- **CI/CD:** GitHub Actions
- **Compute:** EC2 (Amazon Linux 2023), managed via AWS Systems Manager
- **IaC:** Terraform (modularized, imported from existing infrastructure)
- **Observability:** CloudWatch (alarms, dashboard), SNS

## Key engineering decisions

**SSM over SSH for deployment.** No inbound port 22, no SSH key material to leak or rotate. Authorization is enforced entirely through IAM policy rather than possession of a key file — the same trust model used for every other AWS API call in this project. The security group has never had a port 22 rule.

**IAM policies scoped by resource tag, not hardcoded ID.** The CI IAM policy grants `ssm:SendCommand` conditioned on `ssm:resourceTag/Environment`, not a specific instance ARN. This means the policy doesn't need editing when an instance is replaced — which happened more than once during this project — and is the same reason the deploy workflow looks up its target dynamically by tag rather than hardcoding an instance ID.

**Deploy script is idempotent, not a bare `git clone`.** The deploy step checks whether the app directory exists before deciding to clone or pull. This was a deliberate choice over always cloning: it means a freshly-replaced instance can bootstrap itself on the very next deploy, with no manual intervention.

**Infrastructure was imported, not rebuilt.** Rather than tearing down the manually-created EC2 instance and starting clean in Terraform, it was imported with `terraform import` and reconciled against a `terraform plan` diff until it reached zero drift — closer to how most real Terraform adoption actually happens, since infrastructure is rarely greenfield.

**Modules over copy-paste for the staging environment.** Adding a second environment by duplicating and hand-editing six resource blocks would have created a specific, realistic failure mode: a missed rename in an `aws_iam_role_policy_attachment` block would silently leave one environment missing a permission, with no error at apply time — only a gap that surfaces later, once someone notices metrics or logs aren't showing up. A parameterized module makes that category of mistake structurally impossible, since the reference is written once and reused, not retyped per environment.

## Debugging log (the interesting part)

A few real issues hit and resolved during this project:

- **Silent SSM command failures in CI.** `aws ssm send-command` returns immediately without waiting for the remote script to finish — an early version of the pipeline reported success even when the deploy script failed on the instance. Fixed by adding `aws ssm wait command-executed` plus an explicit status check against `get-command-invocation`.
- **A shell `-e` flag masking the real error.** Once the waiter above was added, its own failure (by design, when the underlying command fails) triggered `set -e` and killed the step before the diagnostic output could print. Fixed by explicitly ignoring the waiter's own exit code and relying on a separate status check for pass/fail.
- **Cascading errors from a missing binary.** `git` wasn't installed via the instance's user-data script, which caused a chain of three seemingly unrelated errors (`git: command not found` → `cd: no such file or directory` → `pm2: script not found`) — all downstream of the same root cause, since a failed `cd` doesn't stop a shell script, it just leaves execution in the wrong directory for everything after it.
- **A Terraform plan that would have caused an outage.** During the import into Terraform, a security-group `description` mismatch produced a `-/+` (destroy and recreate) plan rather than an in-place update, because AWS treats that field as immutable. Applying it as-is would have deleted the running security group out from under the live instance. Caught by reading the plan diff before applying, not after.
- **A latent IAM policy bug, exposed (not caused) by a new feature.** Adding a matrix strategy to deploy both `dev` and `staging` from one workflow surfaced a pre-existing bug: the CI IAM policy's `ssm:SendCommand` condition was still hardcoded to `ssm:resourceTag/Environment = "dev"` from Ticket 1, before staging ever existed, and had never been revisited. Staging deploys failed with `AccessDeniedException` while dev succeeded — the asymmetry was the clue. Root-caused by reading the actual policy document rather than guessing, then fixed by widening the condition to a list of environment names (`["dev", "staging"]`, itself driven by a single Terraform `local` value shared with the rest of the config) and, since this policy had been the one remaining piece of hand-clicked IAM in the project, importing it into Terraform in the same pass so the same drift can't silently recur for a third environment.

## Running this yourself

Requires an AWS account (free tier is sufficient), Terraform, and the AWS CLI configured with credentials.

```bash
cd infra
terraform init
terraform plan
terraform apply
```

The GitHub Actions workflow (`.github/workflows/deploy.yml`) deploys automatically on push to `main`, provided `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are set as repository secrets for a suitably-scoped IAM user.