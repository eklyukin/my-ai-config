# GCP Secret Manager Integration Guide

## Overview

The Neo4j skill can fetch credentials from Google Cloud Secret Manager instead of environment variables, providing:

- **Centralized Secret Management**: All secrets stored in GCP, managed by admins
- **Audit Logging**: Cloud Audit Logs track all secret access attempts
- **Automatic Updates**: Secret rotations happen centrally, no local config changes needed
- **Fine-Grained Access Control**: IAM policies control who can access which secrets

## Architecture

### Secret Structure

| Secret Type | Name Pattern | Access Level | Maps To |
|-------------|--------------|--------------|---------|
| Database URI (shared) | `xenia-npc-neo4j-uri-prod` | All employees | `NEO4J_URI` |
| Username (personal) | `xenia-npc-user-<username>-neo4j-username-prod` | Owner only | `NEO4J_USERNAME` |
| Password (personal) | `xenia-npc-user-<username>-neo4j-password-prod` | Owner only | `NEO4J_PASSWORD` |

**Username Sanitization:**
- Extract username before @ sign (if email): `user@xsolla.com` → `user`
- Replace dots with hyphens: `user` → `username`

**Full Example:**
- Email: `user@xsolla.com`
- Sanitized: `username`
- Password secret: `xenia-npc-user-username-neo4j-password-prod`
- Service account: `xenia-npc-username@ai-experiments-469513.iam.gserviceaccount.com`

## Authentication Methods

### Service Account Impersonation (Recommended for Corporate Users)

**How it works:**
1. Your corporate user account authenticates via `gcloud auth login`
2. The skill impersonates your personal service account to access secrets
3. The service account has `secretAccessor` role on your personal secrets

**Prerequisites:**
- **NPC Virtual Machine provisioned** (creates `xenia-npc-<username>@project.iam.gserviceaccount.com`)
  - **If you don't have an NPC VM**: Contact **Xenia team** to request provisioning
  - NPC VM provisioning creates your service account and personal Neo4j secrets
- User has `roles/iam.serviceAccountTokenCreator` on service account
- Service account has `roles/secretmanager.secretAccessor` on secrets

**Setup:**
```bash
# 1. Authenticate with your corporate account
gcloud auth login

# 2. Verify impersonation works
gcloud auth print-access-token \
    --impersonate-service-account="xenia-npc-$(whoami | cut -d'@' -f1 | tr '.' '-')@ai-experiments-469513.iam.gserviceaccount.com"

# 3. Test secret access
gcloud secrets versions access latest \
    --secret="xenia-npc-user-$(whoami | cut -d'@' -f1 | tr '.' '-')-neo4j-password-prod" \
    --project="ai-experiments-469513" \
    --impersonate-service-account="xenia-npc-$(whoami | cut -d'@' -f1 | tr '.' '-')@ai-experiments-469513.iam.gserviceaccount.com"
```

**Configuration:**
```bash
# In config/neo4j.conf or environment
USE_GCP_SECRETS="auto"
GCP_PROJECT_ID="ai-experiments-469513"
# GCP_SERVICE_ACCOUNT auto-detected from whoami
```

### Application Default Credentials (For Local Development)

**When to use:** Local development on personal projects without service accounts.

**Setup:**
```bash
# Authenticate with ADC
gcloud auth application-default login

# Grant yourself access to secrets (admin required)
gcloud secrets add-iam-policy-binding xenia-npc-neo4j-uri-prod \
    --member="user:your-email@example.com" \
    --role="roles/secretmanager.secretAccessor" \
    --project="ai-experiments-469513"
```

**Configuration:**
```bash
USE_GCP_SECRETS="auto"
GCP_PROJECT_ID="ai-experiments-469513"
# Leave GCP_SERVICE_ACCOUNT empty for ADC
```

## Quick Start

### 1. Install Prerequisites

```bash
# Install gcloud CLI (macOS)
brew install --cask google-cloud-sdk

# Install gcloud-cli skill
ln -s /path/to/claude-skills/google/gcloud-cli ~/.claude/skills/gcloud-cli
```

### 2. Authenticate

```bash
# Corporate users: authenticate with Google account
gcloud auth login

# Select your account and follow browser authentication flow
```

### 3. Configure Neo4j Skill

```bash
# Enable GCP secrets (default: auto)
export USE_GCP_SECRETS="auto"

# Set project ID (default: ai-experiments-469513)
export GCP_PROJECT_ID="ai-experiments-469513"

# Service account is auto-detected from whoami
```

### 4. Test Integration

```bash
# Enable debug mode to see credential sources
export DEBUG="true"

# Run Neo4j skill (should fetch credentials from GCP)
neo4j schema --sample-size=10

# Check debug output for:
# [INFO] Fetching Neo4j credentials from GCP Secret Manager...
# [DEBUG] Loaded NEO4J_URI from GCP
# [DEBUG] Loaded NEO4J_USERNAME from GCP
# [DEBUG] Loaded NEO4J_PASSWORD from GCP (XX chars)
```

## Troubleshooting

### Error: "Permission Denied"

**Cause:** Service account lacks access to secret or you cannot impersonate the service account.

**Solutions:**

1. **Grant secret access** (requires admin):
```bash
# Grant your service account access to secrets
USERNAME="username"  # Your sanitized username
SERVICE_ACCOUNT="xenia-npc-${USERNAME}@ai-experiments-469513.iam.gserviceaccount.com"

for secret in \
    "xenia-npc-neo4j-uri-prod" \
    "xenia-npc-user-${USERNAME}-neo4j-username-prod" \
    "xenia-npc-user-${USERNAME}-neo4j-password-prod"; do
    gcloud secrets add-iam-policy-binding "$secret" \
        --member="serviceAccount:${SERVICE_ACCOUNT}" \
        --role="roles/secretmanager.secretAccessor" \
        --project="ai-experiments-469513"
done
```

2. **Grant impersonation permission** (requires admin):
```bash
# Allow your user to impersonate the service account
gcloud iam service-accounts add-iam-policy-binding \
    "xenia-npc-${USERNAME}@ai-experiments-469513.iam.gserviceaccount.com" \
    --member="user:user@xsolla.com" \
    --role="roles/iam.serviceAccountTokenCreator" \
    --project="ai-experiments-469513"
```

3. **Verify your access**:
```bash
# Test impersonation
gcloud auth print-access-token \
    --impersonate-service-account="${SERVICE_ACCOUNT}"

# If this works, test secret access
gcloud secrets versions access latest \
    --secret="xenia-npc-user-${USERNAME}-neo4j-password-prod" \
    --project="ai-experiments-469513" \
    --impersonate-service-account="${SERVICE_ACCOUNT}"
```

### Error: "Secret Not Found"

**Cause:** Secret doesn't exist or wrong project/name.

**Solutions:**

1. **List available secrets**:
```bash
# List all secrets in project
gcloud secrets list --project="ai-experiments-469513"

# Filter for Neo4j secrets
gcloud secrets list --project="ai-experiments-469513" --filter="name:xenia-npc-neo4j"

# Filter for your personal secrets
USERNAME="$(whoami | cut -d'@' -f1 | tr '.' '-')"
gcloud secrets list --project="ai-experiments-469513" --filter="name:xenia-npc-user-${USERNAME}"
```

2. **Verify secret naming**:
```bash
# Check your expected secret names
USERNAME="$(whoami | cut -d'@' -f1 | tr '.' '-')"
echo "Database: xenia-npc-neo4j-uri-prod"
echo "Username: xenia-npc-user-${USERNAME}-neo4j-username-prod"
echo "Password: xenia-npc-user-${USERNAME}-neo4j-password-prod"
```

3. **Contact Xenia team** to:
   - Request NPC VM provisioning (if you don't have a service account yet)
   - Create or update your personal Neo4j secrets
   - Grant appropriate access permissions

### Error: "gcloud: command not found"

**Cause:** gcloud CLI not installed.

**Solutions:**

**macOS:**
```bash
brew install --cask google-cloud-sdk
```

**Ubuntu/Debian:**
```bash
# Add Cloud SDK distribution URI as a package source
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
    sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

# Import Google Cloud public key
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

# Update and install
sudo apt-get update && sudo apt-get install google-cloud-sdk
```

**Alternative:** Use environment variables instead:
```bash
export USE_GCP_SECRETS="false"
export NEO4J_URI="bolt://localhost:7687"
export NEO4J_USERNAME="neo4j"
export NEO4J_PASSWORD="password"
```

### Error: "Not Authenticated"

**Cause:** Not logged in to gcloud.

**Solutions:**

1. **Interactive login**:
```bash
gcloud auth login
# Follow browser authentication flow
```

2. **Application Default Credentials**:
```bash
gcloud auth application-default login
```

3. **Service account key** (for CI/CD):
```bash
gcloud auth activate-service-account \
    --key-file=/path/to/service-account-key.json
```

### GCP Secrets Not Being Used

**Cause:** Environment variables take precedence over GCP.

**Solutions:**

1. **Check USE_GCP_SECRETS setting**:
```bash
echo "USE_GCP_SECRETS=$USE_GCP_SECRETS"  # Should be "auto" or "true"
```

2. **Unset environment variables** to force GCP usage:
```bash
unset NEO4J_URI NEO4J_USERNAME NEO4J_PASSWORD
```

3. **Set USE_GCP_SECRETS=true** to prefer GCP over env vars:
```bash
export USE_GCP_SECRETS="true"
```

4. **Enable debug mode** to see credential sources:
```bash
export DEBUG="true"
neo4j schema --sample-size=10
# Check output for "[DEBUG] Loaded NEO4J_* from GCP" messages
```

## IAM Permissions Reference

### Required Roles

| Role | Purpose | Scope |
|------|---------|-------|
| `roles/secretmanager.secretAccessor` | Read secret values | Service account → Secret |
| `roles/iam.serviceAccountTokenCreator` | Impersonate service account | User → Service account |

### Grant Commands (Admin Only)

**Grant secret access to service account:**
```bash
gcloud secrets add-iam-policy-binding SECRET_NAME \
    --member="serviceAccount:SA@PROJECT.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor" \
    --project="ai-experiments-469513"
```

**Grant impersonation permission to user:**
```bash
gcloud iam service-accounts add-iam-policy-binding \
    SA@PROJECT.iam.gserviceaccount.com \
    --member="user:your-email@example.com" \
    --role="roles/iam.serviceAccountTokenCreator" \
    --project="ai-experiments-469513"
```

## Security Best Practices

1. **Never commit secrets to git** - Use Secret Manager or environment variables
2. **Use service account impersonation** - Avoid downloading key files locally
3. **Rotate secrets regularly** - Add new versions, disable old ones after rotation
4. **Audit access** - Review Cloud Audit Logs for secret access
5. **Least privilege** - Grant only `secretAccessor`, not `admin`
6. **Environment-specific secrets** - Use `-prod`, `-dev`, `-test` suffixes
7. **Enable Secret Manager API**:
```bash
gcloud services enable secretmanager.googleapis.com --project="ai-experiments-469513"
```

## Credential Precedence

The skill uses this precedence order (highest to lowest):

1. **Environment Variables** - Always take precedence
2. **GCP Secret Manager** - Used if `USE_GCP_SECRETS=auto` and env vars not set
3. **Config File** - User config (`~/.claude/skills/neo4j/config/neo4j.conf`)
4. **Template Config** - Skill default (`<skill>/config/neo4j.conf.template`)

**Examples:**

```bash
# Scenario 1: Env vars override GCP
export NEO4J_URI="bolt://env-override:7687"
export USE_GCP_SECRETS="auto"
# Result: Uses env var URI, fetches username/password from GCP

# Scenario 2: Pure GCP (recommended)
export USE_GCP_SECRETS="auto"
unset NEO4J_URI NEO4J_USERNAME NEO4J_PASSWORD
# Result: Fetches all credentials from GCP

# Scenario 3: Disable GCP
export USE_GCP_SECRETS="false"
export NEO4J_URI="bolt://localhost:7687"
export NEO4J_USERNAME="neo4j"
export NEO4J_PASSWORD="password"
# Result: Uses only environment variables
```

## Frequently Asked Questions

### Q: Do I need to install the gcloud-cli skill?

**A:** Yes, the Neo4j skill sources scripts from the gcloud-cli skill. Install with:
```bash
ln -s /path/to/claude-skills/google/gcloud-cli ~/.claude/skills/gcloud-cli
```

### Q: What happens if GCP is unavailable?

**A:** The skill gracefully falls back to environment variables. No failures occur if GCP is unreachable.

### Q: Can I use GCP for some credentials and env vars for others?

**A:** Yes! With `USE_GCP_SECRETS="auto"`, the skill uses GCP only for credentials not set in environment variables.

### Q: How do I know if GCP integration is working?

**A:** Enable debug mode: `DEBUG=true neo4j schema`. Look for `[DEBUG] Loaded NEO4J_* from GCP` messages.

### Q: Who manages the secrets?

**A:** Secrets are managed centrally by admins. Contact your admin to create or update secrets.

### Q: Can I create my own secrets for testing?

**A:** Yes, if you have the `secretmanager.secretCreator` role in the project. Follow the naming convention.

### Q: What's the performance impact of GCP fetching?

**A:** Secrets are fetched once per Neo4j skill invocation (typically <1 second). Credentials are cached for the session.

### Q: How do I get an NPC VM and personal secrets?

**A:** Contact the **Xenia team** to request NPC VM provisioning for your account. This process:
- Creates your personal service account: `xenia-npc-<username>@ai-experiments-469513.iam.gserviceaccount.com`
- Provisions your personal Neo4j secrets (username and password)
- Grants appropriate IAM permissions
- Typically takes 1-2 business days

**Who to contact:** Reach out to the Xenia team via your internal communication channels.

### Q: I don't have personal Neo4j credentials, what should I do?

**A:** You have two options:
1. **Preferred**: Contact **Xenia team** to provision NPC VM and create your personal secrets
2. **Temporary**: Use environment variables:
   ```bash
   export USE_GCP_SECRETS="false"
   export NEO4J_URI="bolt://host:7687"
   export NEO4J_USERNAME="neo4j"
   export NEO4J_PASSWORD="password"
   ```

## Additional Resources

- [GCP Secret Manager Documentation](https://cloud.google.com/secret-manager/docs)
- [Service Account Impersonation Guide](https://cloud.google.com/iam/docs/impersonating-service-accounts)
- [gcloud CLI Authentication](https://cloud.google.com/sdk/gcloud/reference/auth)
- [IAM Roles Reference](https://cloud.google.com/iam/docs/understanding-roles)
