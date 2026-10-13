# Infra and config strategy

Prove the change through plans and dry runs; never apply to a shared environment. Write outputs under `{run}/infra/`.

Use the tool's own preview for each change and save the full output as `{run}/infra/{claim}-{nn}-{slug}.txt`:

- Terraform: `terraform init -backend=false` when no state access, `terraform validate`, and `terraform plan` when credentials allow it.
- Kubernetes and Helm: `helm template` / `helm diff`, `kubectl apply --dry-run=server` when cluster access allows it, otherwise `--dry-run=client` plus schema validation.
- Docker: `docker build`, then run the image locally and check it starts and answers.
- CI pipelines: the platform's linter, and a local runner when one exists.

The caption states what the output proves: "Plan changes only the two buckets named in the ticket; no destroys." Read every plan for resources it would destroy or replace and list them in `risks`, even when expected.

An apply against a real environment is never part of verification. When a claim can only be proven by applying, it is UNVERIFIED with that reason.
