---
name: secret-handoff
description: Generates terminal commands for secure secret input without exposing values to Claude. Use when creating GCP secrets, updating API keys, piping credentials into commands, or any operation where a secret value must be typed by the user in a separate terminal.
---

# Secret Handoff

Generate exact terminal commands for the user to run in a separate terminal when secret values must be entered. Claude composes the command but never sees the secret value.

## Core Principle

**Claude knows secret NAMES, never secret VALUES.** This skill produces copy-paste-ready commands that the user executes outside the Claude session.

## Workflow

1. **Detect** what secret operation is needed from conversation context
2. **Compose** the exact command(s) — validated, ready to paste
3. **Present** in a fenced code block with clear instructions
4. **Wait** for user confirmation before continuing

## Command Templates

### GCP Secret Manager — Create New Secret

When the user needs to store a new secret:

```
INSTRUCTIONS — Run in a separate terminal:

# Step 1: Create the secret and enter the value when prompted
printf "Paste your secret value: " && read -s SECRET_VAL && echo
echo -n "$SECRET_VAL" | gcloud secrets create <SECRET_NAME> \
  --project=<PROJECT_ID> \
  --data-file=- \
  --replication-policy=automatic
unset SECRET_VAL

# Step 2: Verify it was created (safe — only shows metadata)
gcloud secrets describe <SECRET_NAME> --project=<PROJECT_ID>
```

### GCP Secret Manager — Update Existing Secret

When adding a new version to an existing secret:

```
INSTRUCTIONS — Run in a separate terminal:

printf "Paste your new secret value: " && read -s SECRET_VAL && echo
echo -n "$SECRET_VAL" | gcloud secrets versions add <SECRET_NAME> \
  --project=<PROJECT_ID> \
  --data-file=-
unset SECRET_VAL
```

### GCP Secret Manager — Grant Access

This one is safe for Claude to run directly (no secret values involved):

```bash
gcloud secrets add-iam-policy-binding <SECRET_NAME> \
  --project=<PROJECT_ID> \
  --member="user:<EMAIL>" \
  --role="roles/secretmanager.secretAccessor"
```

### Write Secret to a Temporary File

When a tool requires a file path instead of stdin:

```
INSTRUCTIONS — Run in a separate terminal:

printf "Paste your secret value: " && read -s SECRET_VAL && echo
echo -n "$SECRET_VAL" > /tmp/.secret_tmp && chmod 600 /tmp/.secret_tmp
unset SECRET_VAL
echo "Written to /tmp/.secret_tmp — tell Claude to proceed"

# IMPORTANT: After Claude is done using the file, run:
# rm -f /tmp/.secret_tmp
```

### Set Environment Variable (Current Shell)

When a secret needs to be available as an env var:

```
INSTRUCTIONS — Run in the terminal where you'll launch the process:

printf "Paste your secret value: " && read -s VAL && echo
export <ENV_VAR_NAME>="$VAL"
unset VAL
```

### Docker / Cloud Run — Mount Secret at Deploy Time

Safe for Claude to run (references secret by name, not value):

```bash
gcloud run jobs update <JOB_NAME> \
  --set-secrets="<ENV_VAR>=<SECRET_NAME>:latest" \
  --project=<PROJECT_ID> --region=<REGION>
```

## Presentation Format

Always present handoff commands using this structure:

---

**Run this in a separate terminal** (not in this Claude session):

```bash
<commands here>
```

After you've run it, let me know and I'll continue.

---

## Safety Rules

1. **NEVER** run `gcloud secrets versions access` to read a secret value into the Claude session
2. **NEVER** ask the user to paste a secret value into the chat
3. **NEVER** use `echo "actual-secret-value"` in any command — always use `read -s` for interactive input
4. **ALWAYS** `unset` variables containing secrets immediately after use
5. **ALWAYS** use `echo -n` (no trailing newline) when piping to `--data-file=-`
6. If the user accidentally pastes a secret in chat, warn them and suggest rotating it

## Examples

### Example 1: User needs to store an API key

User says: "I got my Deepgram API key, where do I put it?"

Response:
> **Run this in a separate terminal:**
> ```
> printf "Paste your Deepgram API key: " && read -s SECRET_VAL && echo
> echo -n "$SECRET_VAL" | gcloud secrets create meeting-deepgram-api-key \
>   --project=ai-experiments-469513 \
>   --data-file=- \
>   --replication-policy=automatic
> unset SECRET_VAL
> ```
> Let me know when done and I'll configure the service to use it.

### Example 2: User needs to rotate a key

User says: "I regenerated my OpenAI key"

Response:
> **Run this in a separate terminal:**
> ```
> printf "Paste your new OpenAI API key: " && read -s SECRET_VAL && echo
> echo -n "$SECRET_VAL" | gcloud secrets versions add meeting-openai-api-key \
>   --project=ai-experiments-469513 \
>   --data-file=-
> unset SECRET_VAL
> ```
> Let me know when done — I'll verify the new version exists.

### Example 3: User needs a secret in a local file for testing

User says: "I need to test with my API key locally"

Response:
> **Run this in a separate terminal:**
> ```
> printf "Paste your API key: " && read -s SECRET_VAL && echo
> echo -n "$SECRET_VAL" > /tmp/.api_key && chmod 600 /tmp/.api_key
> unset SECRET_VAL
> ```
> Let me know when done. When you're finished testing, run: `rm -f /tmp/.api_key`
