# WordPress Backup Shell Script

Automated WordPress file + database backups for shared hosting with configurable compression, retention cleanup, and optional PHP trigger execution.

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
5. Automate via cron (shell cron if SSH is available, otherwise URL cron via trigger).

---

## Project Structure

```text
wordpress-backup-shell-script/
├── README.md
├── scripts/
│   ├── wordpress-backup.sh
│   └── env-wordpress-backup.example
└── trigger/
    └── wordpress-backup.php
```

- `scripts/` must not be publicly reachable via web.
- `trigger/` may be web-reachable for URL-based cron.

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
  - `sync`: waits for completion, returns output
  - `background`: starts detached process, returns PID

---

## Trigger Security (Current Limitations and TODO)

Static `.htaccess` IP allowlists for shared-hosting cronjobs are unreliable because cronjob source IPs can change.

Current policy:

- keep trigger exposure minimal
- monitor access via logs
- do not treat static IP allowlists as primary protection

TODO:

- implement a stable trigger authentication mechanism that does not rely on fixed source IPs
- document the final approach in this README

Issue draft:

- `docs/github-issue-trigger-authentication.md`

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
- **Backups too large**
  - Use `EXCLUDES` for cache/temporary folders

---

## License

MIT License.
