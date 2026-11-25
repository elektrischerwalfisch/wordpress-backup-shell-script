# WordPress Backup Shell Script

Automated WordPress file + database backups for shared hosting with configurable compression, retention cleanup, error notifications, and optional PHP trigger execution; can be automated with a cronjob.

Developed for shared hosting, tested on all-inkl and IONOS.

> **Key characteristic**
> This tool runs fully server-side and independently from WordPress internals.
> It does not require a WordPress plugin, theme integration, or admin access.
> It also works on shared hosting without SSH by using the PHP trigger.

---

## Quickstart

1. Clone the repository (or upload the project files) and open the project folder.
2. Create `scripts/.env-wordpress-backup` from `scripts/env-wordpress-backup.example`.
   - Ensure file permissions allow writing the file during setup, then set it to 600 for secure read/write access by the owner only.
3. Edit `scripts/.env-wordpress-backup` and set at least:
   - `WP_FOLDER`
   - `BACKUP_FOLDER`
   - `COMPRESSION_METHOD`
   - `TRIGGER_TOKEN` if you use the PHP trigger (long random secret)
   - email settings (`SMTP_*`, `EMAIL_FROM`, `EMAIL_TO`) if notifications are required
4. Run one test backup and check log output.
   - With SSH: run `scripts/wordpress-backup.sh`.
   - Without SSH: call the trigger URL with your token (see [Trigger Security](#trigger-security)).
   - In both cases, verify the result in `backup.log`.
5. Automate via cron (shell cron if SSH is available, otherwise URL cron via trigger with token).

---

## Project Structure

This tool is **not part of the WordPress installation**. Deploy it in a **separate directory** on the server and point `WP_FOLDER` at your WordPress root.

### Recommended server layout (example)

```text
/home/user/www                           (account home, example)
├── wordpress-website/                   ← WP_FOLDER (WordPress installation)
│   ├── wp-config.php
│   ├── wp-content/
│   └── ...
├── wordpress-backup-shell-script/       ← this repository (separate location)
│   ├── scripts/
│   │   ├── wordpress-backup.sh
│   │   └── .env-wordpress-backup        ← includes TRIGGER_TOKEN (gitignored)
│   └── trigger/
│       └── wordpress-backup.php
└── wordpress-backups/                   ← BACKUP_FOLDER
```

Use a separate cron URL or subdomain for `trigger/` (not the WordPress site URL).

---

## Compression

Supported via `COMPRESSION_METHOD`:

- `none`: `files.tar` + `database.sql`
- `gzip`: `files.tar.gz` + `database.sql.gz`
- `zip`: `files.zip` + `database.sql.zip`
- `bzip2`: `files.tar.bz2` + `database.sql.bz2`

Notes:

- For `zip` DB backups, the internal SQL filename keeps a timestamp.
- Missing/invalid method or missing tool stops the script with an error.

---

## Core Configuration

Main variables in `scripts/.env-wordpress-backup`:

- `WP_FOLDER`: absolute path to WordPress install
- `BACKUP_FOLDER`: absolute path where backups are stored
- `MAX_BACKUPS`: number of backup folders to keep
- `COMPRESSION_METHOD`: `none`, `gzip`, `zip`, `bzip2`
- `USE_NICE_FOR_TAR`: apply `nice` for tar-based methods
- `USE_NO_TABLESPACES`: include `--no-tablespaces` for shared-hosting compatibility
- `EXCLUDES`: space-separated paths to exclude from file archive
- `SEND_EMAIL_ON_ERROR`: `1` or `0`
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`
- `EMAIL_FROM`, `EMAIL_TO`, `EMAIL_SUBJECT_DEFAULT`
- `TRIGGER_TOKEN`: shared secret for the PHP trigger (required for URL/cron calls)

Security note:

- `.env-wordpress-backup` contains credentials and `TRIGGER_TOKEN`. Keep permissions at `600`.
- Never expose `scripts/` via web URL.

---

## PHP Trigger

`trigger/wordpress-backup.php` is useful when SSH execution is not available.

Setup:

1. Set `TRIGGER_TOKEN` in `scripts/.env-wordpress-backup` (prefer `A–Z a–z 0–9 - _`)
2. Call the URL with that token (query or header)

Config options in `wordpress-backup.php`:

- `$shellScriptPath`: default `../scripts/wordpress-backup.sh`
- `$envFilePath`: default `../scripts/.env-wordpress-backup` (must contain `TRIGGER_TOKEN`)
- `$executionMode`:
  - `sync`: waits for completion (works well on all-inkl)
  - `background`: starts detached process (recommended on IONOS for large backups)
- `$debugMode`:
  - `false` (default): minimal HTTP output
  - `true`: verbose HTTP output for troubleshooting

By default, the trigger returns minimal HTTP messages only. Full diagnostics are written to `BACKUP_FOLDER/backup.log`.

---

## Trigger Security

Primary protection is a **shared-secret token** in `.env-wordpress-backup` (does not depend on cron source IPs).

### Token setup

1. Set `TRIGGER_TOKEN` in `scripts/.env-wordpress-backup` (same file as other secrets; gitignored)
2. Cron / caller must send the same value:
   - Query: `https://backup.example/trigger/wordpress-backup.php?token=YOUR_TOKEN`
   - Or header: `X-Backup-Token: YOUR_TOKEN`

### Rotation

Generate a new random `TRIGGER_TOKEN`, update `.env-wordpress-backup`, then update the cron URL/header. Old URLs stop working immediately.

### Policy

- keep trigger exposure minimal (separate cron URL/subdomain)
- keep `$debugMode = false` in production (minimal HTTP responses only)
- use `backup.log` for backup diagnostics, not the HTTP response body
- failed auth returns HTTP **403** and body `Forbidden` when debug is off
- do **not** treat static `.htaccess` IP allowlists as primary protection (cron IPs on shared hosting can change); optional IP rules are supplementary at best

---

## Minimal Troubleshooting

- **No DB backup generated**
  - Check DB values parsed from `wp-config.php`
  - Check `backup.log` + `mysqldump` error output
- **Compression errors**
  - Validate `COMPRESSION_METHOD`
  - Ensure required tools are available (`tar`, `gzip`, `zip`, `bzip2`)
- **Mail not sent**
  - Verify `SMTP_*` values
  - Confirm `curl` or `sendmail` availability
- **Permission errors**
  - Ensure read/write access to `WP_FOLDER` and `BACKUP_FOLDER`
  - Keep `.env-wordpress-backup` at permissions `600`
  - Never expose `scripts/` via web URL
- **Backups too large**
  - Use `EXCLUDES` for cache/temporary folders
- **Timeouts on shared hosting**
  - Set `$executionMode = 'background'` in the PHP trigger
  - Consider `COMPRESSION_METHOD=none` and `USE_NICE_FOR_TAR=1`
- **Trigger returns only `Error` with no details**
  - Check `BACKUP_FOLDER/backup.log` for the full error log
  - If you need more detail in the HTTP response (e.g. without log access), set `$debugMode = true` in `trigger/wordpress-backup.php` temporarily
  - Set `$debugMode` back to `false` when done (required for production/cron)
- **Trigger returns `Forbidden` (HTTP 403)**
  - Ensure `scripts/.env-wordpress-backup` exists and is readable by PHP
  - Ensure `TRIGGER_TOKEN` is non-empty and matches `?token=` or `X-Backup-Token`
  - With `$debugMode = true`, the HTTP body names the auth failure reason

---

## License

MIT License.
