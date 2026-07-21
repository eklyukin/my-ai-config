# GitHub Release Manager

`gh_release_manager.py` - Automate release creation, asset management, and comparison.

## Overview

Comprehensive release management including creation with auto-generated notes, asset uploads with checksums, downloads, and release comparison.

## Commands

| Command | Description |
|---------|-------------|
| `list` | List releases |
| `view` | View release details |
| `create` | Create a new release |
| `upload` | Upload assets to a release |
| `download` | Download release assets |
| `delete` | Delete a release |
| `compare` | Compare two releases |
| `edit` | Edit a release |

## Installation

Requires:
- Python 3.7+
- GitHub CLI (`gh`) authenticated

```bash
chmod +x gh_release_manager.py
```

## Usage

### List Releases

```bash
# List recent releases
python3 gh_release_manager.py list

# Limit results
python3 gh_release_manager.py list --limit 5

# JSON output
python3 gh_release_manager.py list --json --pretty
```

### View Release

```bash
# View release details
python3 gh_release_manager.py view v1.0.0

# Different repository
python3 gh_release_manager.py view v1.0.0 -R owner/repo
```

### Create Release

```bash
# Create with auto-generated notes (recommended)
python3 gh_release_manager.py create v1.0.0 --generate-notes

# Create with title
python3 gh_release_manager.py create v1.0.0 --title "Release v1.0.0" --generate-notes

# Create draft
python3 gh_release_manager.py create v1.0.0 --draft --generate-notes

# Create prerelease
python3 gh_release_manager.py create v1.0.0-beta.1 --prerelease --generate-notes

# Create with custom notes
python3 gh_release_manager.py create v1.0.0 --notes "## Changes\n- Feature A"

# Target specific branch/commit
python3 gh_release_manager.py create v1.0.0 --target main --generate-notes
```

### Upload Assets

```bash
# Upload files with checksums (default)
python3 gh_release_manager.py upload v1.0.0 dist/*.zip

# Multiple files
python3 gh_release_manager.py upload v1.0.0 file1.zip file2.tar.gz

# Without checksums
python3 gh_release_manager.py upload v1.0.0 dist/*.zip --no-checksums
```

**Checksum file**: When uploading, a `checksums-v1.0.0.txt` file is automatically generated and uploaded containing SHA256 hashes of all assets.

### Download Assets

```bash
# Download all assets
python3 gh_release_manager.py download v1.0.0

# Download to specific directory
python3 gh_release_manager.py download v1.0.0 -D ./output

# Filter by pattern
python3 gh_release_manager.py download v1.0.0 -p "*.tar.gz"
```

### Delete Release

```bash
# Delete release (keeps git tag)
python3 gh_release_manager.py delete v1.0.0

# Delete release and git tag
python3 gh_release_manager.py delete v1.0.0 --cleanup-tag
```

### Compare Releases

```bash
# Compare two releases
python3 gh_release_manager.py compare v0.9.0 --compare-to v1.0.0

# JSON output
python3 gh_release_manager.py compare v0.9.0 --compare-to v1.0.0 --json --pretty
```

### Edit Release

```bash
# Change title
python3 gh_release_manager.py edit v1.0.0 --title "New Title"

# Add/update notes
python3 gh_release_manager.py edit v1.0.0 --notes "Updated notes"

# Convert draft to public
python3 gh_release_manager.py edit v1.0.0 --draft=false
```

## Options

| Option | Description |
|--------|-------------|
| `--repo, -R` | Repository in format 'owner/name' |
| `--title, -t` | Release title |
| `--notes, -n` | Release notes |
| `--generate-notes` | Auto-generate from commits |
| `--draft` | Create as draft |
| `--prerelease` | Mark as prerelease |
| `--target` | Target branch or SHA |
| `--output-dir, -D` | Download directory |
| `--pattern, -p` | Asset filter pattern |
| `--limit` | Max releases to list |
| `--no-checksums` | Skip checksum generation |
| `--cleanup-tag` | Delete git tag with release |
| `--compare-to` | Second tag for comparison |
| `--json` | JSON output |
| `--pretty` | Pretty-print JSON |

## Output Examples

### Create Release

```
Created release: https://github.com/owner/repo/releases/tag/v1.0.0
```

### Upload Assets

```
Uploaded 3 files to v1.0.0
  + app-linux.tar.gz
  + app-macos.zip
  + app-windows.zip
```

### Compare Releases

```
Comparing v0.9.0 -> v1.0.0

Assets added: 2
  + checksums.txt
  + app-arm64.tar.gz

Assets removed: 0

Compare URL: https://github.com/owner/repo/compare/v0.9.0...v1.0.0
```

### JSON Output

```json
{
  "tag": "v1.0.0",
  "uploaded": [
    {
      "file": "app.zip",
      "path": "dist/app.zip",
      "checksum": "abc123..."
    }
  ],
  "failed": [],
  "checksums": {
    "app.zip": "abc123..."
  }
}
```

## Use Cases

### Release Workflow

```bash
# 1. Create release
python3 gh_release_manager.py create v1.0.0 --generate-notes

# 2. Upload artifacts
python3 gh_release_manager.py upload v1.0.0 dist/*

# 3. Verify
python3 gh_release_manager.py view v1.0.0
```

### CI/CD Integration

```bash
# In pipeline
VERSION=$(git describe --tags)
python3 gh_release_manager.py create $VERSION --generate-notes
python3 gh_release_manager.py upload $VERSION build/*.zip --json
```

### Changelog Generation

```bash
# Compare to find changes
python3 gh_release_manager.py compare v0.9.0 --compare-to v1.0.0 --json
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (release not found, upload failed, etc.) |
