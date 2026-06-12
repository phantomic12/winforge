# WinForge — Automated Windows ISO Build Pipeline

Polls [UUP-dump](https://uupdump.net), rebuilds Windows 10/11 ISOs for a matrix of editions whenever Microsoft ships cumulative updates. Injects Intel RST/VMD NVMe drivers, enables Microsoft XPS Document Writer, drops in an autounattend.xml for hands-off install, and uploads finished ISOs to a fleet of Google Drive accounts via rclone.

## Architecture

Single-repo. All workflows, scripts, and config live here. Secrets are stored
as GitHub Actions Secrets on this repo.

The build workflow:
1. **Frees disk space** (`easimon/maximize-build-space@master`) — concatenates `/` and `/mnt` via LVM to give ~60GB usable (UUP→WIM conversion can hit 8GB+ intermediate files; GitHub's default 14GB temp disk + ~29GB root is not enough).
2. **Renders `{{PLACEHOLDER}}` tokens** in the autounattend template from secrets (was the private repo's job pre-flatten).
3. **Downloads UUPs** → runs the UUP-dump converter → produces a stock ISO.
4. **Injects Intel RST drivers** into the WIM (gracefully skips if Intel's CDN WAF-blocks the request).
5. **Repacks the ISO** with the rendered autounattend baked in.
6. **Uploads to Google Drive** via rclone using one of a pool of accounts.

## Required Secrets

Set these at **Settings → Secrets and variables → Actions**:

| Secret | Required? | Used for |
|---|---|---|
| `RCLONE_CONF` | yes | rclone config (Google Drive account pool) |
| `ACCOUNTS_YAML` | yes | `config/accounts.yaml` content (account pool metadata) |
| `LOCAL_ADMIN_NAME` | yes* | `{{LOCAL_ADMIN_NAME}}` in autounattend |
| `LOCAL_ADMIN_PASS` | yes* | `{{LOCAL_ADMIN_PASS}}` in autounattend (PlainText) |
| `COMPUTER_NAME` | optional | `{{COMPUTER_NAME}}` in autounattend |
| `PRODUCT_KEY` | optional | `{{PRODUCT_KEY}}` in autounattend |
| `INTEL_RST_TOKEN` | optional | Bearer token for Intel's download CDN (WAF protection) |

*Required if your autounattend template uses those placeholders. If you only
use `oobe-skip.xml` (no placeholders), the build skips rendering and uses
the template as-is.

## Quick Start

```
pip install -e ".[dev]"
pytest -q
```

See `.github/workflows/` for CI entry points. `build.yml` is the entry point
for end-to-end ISO builds; `check-updates.yml` runs daily to detect new
UUP-dump builds; `ci.yml` is PR-time linting.
