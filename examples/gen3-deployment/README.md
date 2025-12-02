# Gen3 Commons Deployment Runbook (Terraform + GitOps)

## 1) Prerequisites

### Software

Install and have these on your `PATH`:

* `terraform`
* `helm`
* `kubectl`
* `awscli`

### Accounts & Resources

You’ll need:

* **An AWS account**

  * Your terminal authenticated to that account with **admin** permissions.
* **A valid domain** to host the Gen3 deployment (e.g., `commons.example.org`).
* **An ACM certificate** for your Gen3 hostname (in the region you’ll deploy to).
* **An S3 bucket** to store Terraform state.
* **Two Git repositories** for CI/CD:

  * A **GitOps repo** (cluster/app definitions).
  * A **commons repo** (user.yaml management).
* **An IdP** (Identity Provider) for user login (e.g., Google, Azure AD, Okta).

---

## 2) Run Terraform

1. **Clone the repo** and `cd` into this module’s directory.
2. **Fill out the `locals`** in `main.tf` with your configuration.
3. **Initialize Terraform:**

   ```bash
   terraform init
   ```

   This downloads modules and initializes the working directory.
4. **Apply the plan:**

   ```bash
   terraform apply
   ```

   Review the plan; when ready, type `yes` to proceed. Terraform will create the required infrastructure.

> **Note:** Occasionally there’s a race condition that requires a **second** `terraform apply`. If resources appear partially created, run it again.

---

## 3) Set Up CI/CD & Final Configuration

After Terraform completes, a basic Gen3 instance should be up.

### 3.1 Verify Cluster Access

```bash
aws eks update-kubeconfig --region <REGION> --name <EKS_CLUSTER_NAME>
kubectl get pods -A
```

> Many services will be Pending/initializing until supplemental dependencies are deployed via GitOps.

### 3.2 Initialize the GitOps Repository

From the generated `gitops-repo` directory:

```bash
git init
git remote add origin <GIT_REPO_URL>
```

Update these files to point at **your** Git repo URL:

* `<VPC_NAME>/cluster-level-resources/app.yaml`
* `<VPC_NAME>/<COMMONS_HOSTNAME>/app.yaml`

Commit and push:

```bash
git add .
git commit -m "initial repo"
git push origin main
```

Apply the cluster-level resources (replace `<VPC_NAME>`):

```bash
kubectl apply -f <VPC_NAME>/cluster-level-resources/app.yaml
```

This kicks off deployment of supplemental software (e.g., Argo CD, supporting operators).

### 3.3 Configure an IdP in Fence Config(Optional)

Cognito is setup by default if you keep the deploy_cognito variable set to true. You may setup other IdPs, such as google, at this time though.

1. In **AWS Secrets Manager**, search for the secret named like `fence-config-<COMMONS_HOSTNAME>` (exact name will depend on your setup).
2. Retrieve and edit the secret’s value:

   * Add your IdP **client\_id**, **client\_secret**, and any required auth settings.
   * Update the **enabled IdPs** block if you’re not using Google by default.

### 3.4 Manage the Gen3 App with Argo CD

Apply the application definition for the commons (replace placeholders):

```bash
kubectl apply -f <VPC_NAME>/<COMMONS_HOSTNAME>/app.yaml
```

When workloads become healthy, your environment will be functional (except **Guppy**, which won’t be fully ready until data is submitted and ETL has run).

### 3.5 Create DNS for Your Commons

Get the ingress address:

```bash
kubectl get ingress -A
```

Create an **A/ALIAS** or **CNAME** record for `<COMMONS_HOSTNAME>` pointing to the **ADDRESS** shown above.

Once DNS propagates, you should be able to open the URL and sign in via your IdP.

---

## 4) User Management (user.yaml CI/CD)

Initially you’ll have limited access. Configure **user permissions** via the **user.yaml** workflow.

Further reading: [Fence user.yaml guide](https://github.com/uc-cdis/fence/blob/master/docs/additional_documentation/user.yaml_guide.md)

### 4.1 Initialize the Commons Repo

From the Terraform working directory, `cd` into the generated `commons-repo` directory:

```bash
git init
git remote add origin <GIT_REPO_URL>
```

Edit the `user.yaml` at:

```
users/<PATH_NAME>/user.yaml
```

Follow the guide above to define users, groups, and policies.

### 4.2 Get GitOps Credentials from Terraform

From the Terraform directory:

```bash
terraform output
terraform output gitops_user_secret_access_key
```

These outputs provide an **Access Key** and **Secret** for a `gitops-user`. This user allows your CI to push the `user.yaml` to an S3 bucket that Gen3 reads from—so your commons doesn’t need direct Git credentials.

### 4.3 Add Repo Secrets for GitHub Actions

In your **GitHub repo** (you must be an admin):

* Go to **Settings → Secrets and variables → Actions**.
* Add:

  * `AWS_ACCESS_KEY_ID`
  * `AWS_SECRET_ACCESS_KEY`
    using the values from `terraform output`.

Commit and push:

```bash
git add .
git commit -m "initial repo"
git push origin main
```

A GitHub Action (configured at `.github/workflows/user-yaml-push.yaml`) will run on pushes to the **main** branch and upload `user.yaml` to S3.

> If your default branch is not `main` (e.g., `master`), update the workflow to match.

### 4.4 Trigger Usersync (Optional)

A **CronJob** runs usersync every \~30 minutes. To force it immediately:

```bash
kubectl create job usersync --from=cronjob/usersync
```

To run it again, first delete the previous Job:

```bash
kubectl delete job usersync
```

(Kubernetes Jobs are one-shot; create a fresh Job for each manual run.)

After usersync completes, sign out/in or refresh tokens as needed and verify your new permissions.

---

## Next Steps

* Explore additional configuration and operations guides at **gen3.org**.
* Load data and run **ETL** to bring services like **Guppy** fully online.
* Keep your GitOps repos as the **source of truth**—edit YAMLs there and let Argo CD converge the cluster.

---

## Placeholder Reference

Replace all placeholders before running commands:

* `<REGION>` — AWS region (e.g., `us-east-1`)
* `<EKS_CLUSTER_NAME>` — Your EKS cluster name
* `<VPC_NAME>` — The VPC/stack identifier used in generated paths
* `<COMMONS_HOSTNAME>` — Your Gen3 hostname (e.g., `commons.example.org`)
* `<GIT_REPO_URL>` — Your Git remote URL
* `<PATH_NAME>` — Subdirectory under `users/` for your `user.yaml` layout

---

## Troubleshooting Tips

* If Terraform only partially provisions resources, **run `terraform apply` again**.
* If Argo CD apps don’t appear, re-check:

  * Git remotes & branch name
  * `app.yaml` repo URLs
  * `kubectl apply` paths (use your actual `<VPC_NAME>`)
* If login fails:

  * Re-check **fence-config** secret values and enabled IdP list.
  * Confirm DNS points to the **Ingress ADDRESS**.
* If usersync didn’t apply changes:

  * Confirm the **GitHub Action** succeeded (Actions tab).
  * Verify `user.yaml` uploaded to the expected **S3 bucket**.
  * Run the **manual usersync Job** as shown above.
