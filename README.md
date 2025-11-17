# WordPress Backup Shell Script

## Overview
This script automates WordPress backup creation by:
1. Zipping the WordPress folder (files and uploads).
2. Creating a compressed MySQL database backup.
3. Managing backup retention with automatic cleanup.
4. Sending email alerts in case of errors.

Perfect for developers and sysadmins who want a simple, configurable, and efficient way to back up WordPress sites.

---

## Features
- **File Backup**: Automatically zips the WordPress folder.
- **Database Dump**: Creates a compressed MySQL database dump (`.sql.gz`).
- **Retention Policy**: Keeps a fixed number of backups (`MAX_BACKUPS`), deleting old backups automatically.
- **Logging**: Logs all processes (successes and errors) to a log file.
- **Email Notifications**: Sends error reports in case of failures.

---

## Requirements
1. **Tools Needed**:
   - `mysqldump`: To create MySQL database dumps.
   - `zip` and `grep`: Standard Unix tools.
   - `curl`: For SMTP email notifications (recommended for shared hosting).
   - `sendmail`: Optional fallback for email notifications.
2. **Permissions**: The user running the script must have read/write access to the directories.

---

## Installation and Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/your-repo/wordpress-backup-shell-script.git
   cd wordpress-backup-shell-script
   ```

2. Configure the backup settings:
   The script uses an external configuration file `.env-wordpress-backup` in the `scripts/` directory.
   
   On first run, the script will automatically create this file with placeholder values. Edit it:
   ```bash
   nano scripts/.env-wordpress-backup
   ```
   
   Update the following variables:
   - `WP_FOLDER`: Path to your WordPress folder (use absolute paths!).
   - `BACKUP_FOLDER`: Path to store backups (use absolute paths!).
   - `MAX_BACKUPS`: Maximum number of backups to keep (default: 8).
   - `USE_NO_TABLESPACES`: Set to `1` for shared hosting (default: 1).
   - `SEND_EMAIL_ON_ERROR`: Set to `1` to enable email notifications (default: 1).
   - `EMAIL_SUBJECT_DEFAULT`: Subject line for error emails.
   - `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`: SMTP settings for email notifications.
   - `EMAIL_FROM`, `EMAIL_TO`: Email addresses for notifications.

3. Make the script executable:
   ```bash
   chmod +x scripts/wordpress-backup.sh
   ```
   
   **Note**: If you don't have SSH access, you can use the PHP trigger file (see `trigger/wordpress-backup.php`) to set permissions and execute the script.

4. Test the script:
   Run it manually:
   ```bash
   ./scripts/wordpress-backup.sh
   ```
   Check the `backup.log` file in the backup folder for results.

5. (Optional) Add a cronjob for automation:
   Edit cronjobs:
   ```bash
   crontab -e
   ```
   Add the following line to schedule backups (e.g., daily at midnight):
   ```
   0 0 * * * /full/path/to/scripts/wordpress-backup.sh
   ```
   
   **Alternative**: Use the PHP trigger file via URL-based cronjobs in your hosting panel.

---

## Configuration Variables

All configuration is done via the `.env-wordpress-backup` file in the `scripts/` directory. The script will automatically create this file with placeholder values on first run if it doesn't exist.

| **Variable**        | **Description**                                                                 |
|----------------------|---------------------------------------------------------------------------------|
| `WP_FOLDER`         | Path to the WordPress folder on your server (e.g., `/var/www/html/wordpress`). Use absolute paths! |
| `BACKUP_FOLDER`     | Path to the folder where backups will be stored. Use absolute paths! |
| `LOG_FILE`          | Optional: Path to the log file. Defaults to `$BACKUP_FOLDER/backup.log` if not specified. |
| `MAX_BACKUPS`       | Maximum number of backups to keep (older backups will be deleted automatically). Default: 8 |
| `USE_NO_TABLESPACES`| Set to `1` to include `--no-tablespaces` in `mysqldump`. Use `0` to disable it. Default: 1 (recommended for shared hosting) |
| `SEND_EMAIL_ON_ERROR`| Set to `1` to enable email notifications on errors. Default: 1 |
| `EMAIL_SUBJECT_DEFAULT`| Subject line for error notification emails. |
| `SMTP_HOST`         | SMTP server hostname (e.g., `mail.yourdomain.tld`). |
| `SMTP_PORT`         | SMTP server port (typically `587` for STARTTLS or `465` for implicit TLS). |
| `SMTP_USER`         | SMTP username for authentication. |
| `SMTP_PASS`         | SMTP password for authentication. |
| `EMAIL_FROM`        | Email address to send notifications from. |
| `EMAIL_TO`          | Email address to send error reports to when the backup fails. |

**Security Note**: The `.env-wordpress-backup` file contains sensitive credentials and is automatically excluded from version control via `.gitignore`. Keep the file permissions set to `600` (read/write for owner only).

---

## Script Workflow

### Step-by-Step Actions
1. Create a timestamped backup folder inside `BACKUP_FOLDER`.
2. Zip the WordPress files into `files.zip`.
3. Create a compressed MySQL dump (`database.sql.gz`):
   - Automatically extract credentials from `wp-config.php`.
4. Maintain up to `MAX_BACKUPS` by deleting the oldest backups.
5. Log all actions and errors into `backup.log`.
6. If the backup fails:
   - Log the specific error(s).
   - Send an email with a summary of the issues.

---

## Example Log Output

A successful backup will generate log entries like this:
```plaintext
2025-08-29 15:30:01 - Starting backup for 2025-08-29...
2025-08-29 15:30:15 - WordPress files successfully backed up: /path/to/backups/2025-08-29/files.zip (Size: 50M)
2025-08-29 15:30:25 - Database successfully backed up: /path/to/backups/2025-08-29/database.sql.gz (Size: 2M)
2025-08-29 15:30:30 - Deleted oldest backup: 2025-08-20 to maintain a maximum of 8 backups.
2025-08-29 15:30:35 - Backup completed successfully for 2025-08-29.
```

If errors occur, the corresponding log entries will include:
```plaintext
2025-08-29 15:30:15 - ERROR: Database backup FAILED! Check credentials and database configuration.
```

Additionally, in case of errors, an email will be sent to the configured email address.

Here’s an example email:

**Subject**:  
`WordPress Backup Failed`

**Body**:
```plaintext
The backup of your WordPress-Website failed with the following error(s):

2025-08-29 15:30:15 - ERROR: Database backup FAILED! Check credentials and database configuration.

Please investigate the issue for resolution.
```

---

## Troubleshooting

### Common Issues & Fixes

1. **Empty or Incorrect Database Credentials**
   - Ensure the file `wp-config.php` has proper permissions and is in the folder specified by `WP_FOLDER`.
   - Ensure that the `wp-config.php` file strictly follows the standard WordPress format for defining database credentials. The script relies on extracting these credentials from the file. The relevant lines in `wp-config.php` **must** look exactly like this, without additional spaces, tabs, or comments on the same line:
```php
define('DB_NAME', 'your_database_name');
define('DB_USER', 'your_database_user');
define('DB_PASSWORD', 'your_database_password');
define('DB_HOST', 'localhost'); // Or your specific database host
```
2. **Cannot Send Emails**
   - **Primary method (recommended)**: Configure SMTP settings in `.env-wordpress-backup`:
     - Set `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, and `SMTP_PASS`
     - This method works on all shared hosting providers (all-inkl.com, IONOS, etc.)
     - Uses `curl` for SMTP communication (supports STARTTLS on port 587)
   - **Fallback method**: If SMTP is not configured, the script will try to use `sendmail`:
     ```bash
     sudo apt install sendmail
     ```
   - Ensure your server is properly configured to send emails.

3. **Permission Errors**
   - Ensure the user running the script has read/write permissions for `WP_FOLDER` and `BACKUP_FOLDER`.
   - If you don't have SSH access, use the PHP trigger file (`trigger/wordpress-backup.php`) which will set execute permissions automatically.
   - The config file `.env-wordpress-backup` should have permissions `600` (read/write for owner only).

### **When to Use USE_NO_TABLESPACES**

The `USE_NO_TABLESPACES` variable controls whether the `--no-tablespaces` flag is included in the `mysqldump` command. This option is necessary in the following scenarios:
1. You are backing up a **MySQL user** without the `PROCESS` privilege.
   - The `PROCESS` privilege is required for dumping tablespaces, but shared hosting environments often restrict database users to prevent accessing such information.
   - Enabling `USE_NO_TABLESPACES` ensures that `mysqldump` skips tablespace data, which is unnecessary for typical WordPress backups.

2. Your MySQL server does not use tablespaces.
   - Most WordPress installations don't rely on MySQL tablespaces, which means this flag is safe to use.

**Leave `USE_NO_TABLESPACES=1` enabled by default** unless you know your database user has the `PROCESS` privilege and tablespaces are actively used.


---

## License

This project is licensed under the **MIT License**. You are free to use, modify, and redistribute the code, but no warranty is provided for its functionality or suitability for specific purposes.