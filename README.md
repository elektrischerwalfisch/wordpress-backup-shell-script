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
   - email settings (`SMTP_*`, `EMAIL_FROM`, `EMAIL_TO`) if notifications are required
4. Run one test backup and check log output.
   - With SSH: run `scripts/wordpress-backup.sh`.
   - Without SSH: execute `trigger/wordpress-backup.php` via URL.
   - In both cases, verify the result in `backup.log`.
5. Review [Trigger Security](#trigger-security-current-limitations-and-todo) before exposing the trigger via URL.
6. Automate via cron (shell cron if SSH is available, otherwise URL cron via trigger).

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
│   │   └── .env-wordpress-backup
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

Security note:

- `.env-wordpress-backup` contains credentials. Keep permissions at `600`.

---

## PHP Trigger

`trigger/wordpress-backup.php` is useful when SSH execution is not available.

Config options in the file:

- `$shellScriptPath`: default `../scripts/wordpress-backup.sh`
- `$executionMode`:
  - `sync`: waits for completion (works well on all-inkl)
  - `background`: starts detached process (recommended on IONOS for large backups)
- `$debugMode`:
  - `false` (default): minimal HTTP output
  - `true`: verbose HTTP output for troubleshooting

By default, the trigger returns minimal HTTP messages only. Full diagnostics are written to `BACKUP_FOLDER/backup.log`.

---

## Trigger Security (Current Limitations and TODO)

Static `.htaccess` IP allowlists for shared-hosting cronjobs are unreliable because cronjob source IPs can change.

Current policy:

- keep trigger exposure minimal
- keep `$debugMode = false` in production (minimal HTTP responses only)
- use `backup.log` for diagnostics, not the HTTP response body
- monitor access via logs
- do not treat static IP allowlists as primary protection

TODO:

- implement a stable trigger authentication mechanism that does not rely on fixed source IPs
- document the final approach in this README

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

---

## License

MIT License.
