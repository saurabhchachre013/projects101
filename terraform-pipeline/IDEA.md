# Terraform-Pipeline

## What it does

A pipeline where every cloud resource is created and changed **only** through Terraform, and every Terraform change is deployed **only** through GitHub Actions. No console clicks, no local `terraform apply`.

## Why I'm building it

To make infrastructure changes seamless and repeatable — no manual creation, no human error. Every change is reviewed, planned, and applied the same way, every time, with a trail of who approved what.

## What it will use

- **Terraform** — all infrastructure as code
- **AWS** — the target cloud
- **Remote state** — S3 backend with bucket versioning enabled (state must survive the CI runner; versioning is part of the recovery plan)
- **OIDC auth** — GitHub Actions assumes an IAM role via OIDC federation. No long-lived AWS access keys stored in GitHub Secrets.
- **GitHub** — repo, Actions, branch protection, and Environments for the approval gate

## What v1 must do

- Create AWS resources only through GitHub Actions pipelines.
- **Workflow 1 — on pull request:** check formatting (`terraform fmt -check`), validate syntax (`terraform validate`), lint (`tflint`), scan for misconfigurations (Checkov or Trivy), then `terraform plan`. Post the results as a PR comment so the reviewer has everything they need to make a decision.
- **Workflow 2 — on merge to `main`:** apply the change, gated behind a GitHub Environment with required reviewers. Applies the exact plan artifact that was reviewed, not a fresh re-plan.
- The PR comment must summarise **risk**, not just dump raw plan text: counts of create / update / replace / destroy, and an explicit warning when anything is being destroyed or replaced.

## Revert plan

Terraform has no rollback. Recovery is designed, not assumed.

- **Roll forward, not back.** `git revert` the PR → the pipeline plans the reverse change → apply. The recovery path is the normal path.
- **State versioning.** S3 bucket versioning is on, so a corrupted or bad state file can be restored to a previous object version.
- **`prevent_destroy`** lifecycle blocks on stateful resources (databases, the state bucket itself).
- **Catch it before it ships.** The plan gate flags or blocks any change containing a destroy or a replacement, so destructive changes need a deliberate human decision instead of slipping through.

## What I'm NOT doing in v1

- No AI/LLM agent — that's v2 (see below)
- No Azure or GCP — AWS only
- No multi-environment setup (dev / stage / prod) — a single environment
- No custom Terraform modules — keep the resources simple, the pipeline is the point

## Time I think it'll take

5 days.

| Day | Work |
|---|---|
| 1 | Bootstrap: state bucket, OIDC role, repo and branch protection setup |
| 2 | Workflow 1 — fmt, validate, tflint, security scan, plan, PR comment |
| 3 | Workflow 2 — Environment approval gate, plan artifact apply, concurrency control |
| 4 | Risk summary in the PR comment (parse `terraform show -json`) |
| 5 | README, architecture diagram, demo recording, cleanup |

## Known design decisions

- **Bootstrap is manual, once.** The S3 state bucket can't be created by the pipeline that depends on it. A separate `bootstrap/` directory is applied by hand one time and documented in the README.
- **Approval happens on merge, not on PR review.** GitHub Environments give a real approval gate with an audit trail; the `pull_request_review` event does not.
- **Fork PRs do not run plan by default.** Running Terraform on untrusted code from a fork is an attack vector. `pull_request_target` is not used.
- **Concurrency group on apply** so two merges can never apply at the same time.

## Cost control

- AWS Budget alert set **before** any Terraform is written.
- Test with free-tier resources only (t3.micro, VPC, S3, IAM).
- Everything is destroyed after testing — no resources left running overnight by accident.

## Things I'm unsure about

- Exact format of the risk summary comment — will iterate once I see real plan output.
- Whether GitHub's PR comment size limit becomes a problem with large plans, and how to truncate gracefully.

## v2 — the AI agent (not in this release)

Give a command in plain English — "I want to create an S3 bucket" — and an agent asks what it needs to know, then writes the Terraform for it.

**The agent never applies anything. It opens a pull request.** Everything built in v1 — validate, lint, security scan, plan, risk summary, human approval — is the guardrail that catches it when it gets things wrong. The interesting problem isn't getting an LLM to write Terraform; it's building the review system strong enough to let one try.

Constraints already baked into v1 to make this possible:

- The agent gets its own GitHub identity that can open PRs and nothing else — no write access to `main`, no AWS credentials.
- The PR body records what was asked in English, what the agent decided, and what it assumed — so the reviewer can see the gap between intent and code.
- The risk classifier built in v1 for humans becomes the thing that catches the agent's mistakes in v2.