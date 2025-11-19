# WordPress Backup Shell Script

## Overview
This script automates WordPress backup creation by:
1. Zipping the WordPress folder (files and uploads).
2. Creating a compressed MySQL database backup.
3. Managing backup retention with automatic cleanup.
4. Sending email alerts in case of errors.

Perfect for developers and sysadmins who want a simple, configurable, and efficient way to back up WordPress sites.

**Developed for**: Shared hosting environments  
**Tested on**: all-inkl.com, IONOS (other shared hosting providers may work but are untested)

---

## File Structure

```
wordpress-backup-shell-script/
├── README.md                    # This file
├── LICENSE                      # MIT License
├── .gitignore                   # Git ignore rules
├── scripts/                     # Shell script directory (not publicly accessible)
│   ├── wordpress-backup.sh     # Main backup script
│   └── env-wordpress-backup.example # Configuration template
└── trigger/                     # PHP trigger directory (publicly accessible via URL)
    └── wordpress-backup.php    # PHP trigger script
```

### Directory Purpose

- **`scripts/`**: Contains the main shell script and configuration files. This directory should **not** be publicly accessible via web URL to protect the backup script and sensitive configuration.
- **`trigger/`**: Contains PHP scripts that can be called via URL to execute the backup script. This directory is publicly accessible but should be protected via `.htaccess` to restrict access to authorized IP addresses (e.g., the cronjob server IP).

---

## Features
- **File Backup**: Automatically zips the WordPress folder.
- **Database Dump**: Creates a compressed MySQL database dump (`.sql.gz`).
- **Detailed Error Handling**: Comprehensive mysqldump error capture and validation.
- **File Size Validation**: Warns if backup files seem unusually small (indicates potential issues).
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

1. Clone the repository or download the files:
   ```bash
   git clone https://github.com/your-repo/wordpress-backup-shell-script.git
   cd wordpress-backup-shell-script
   ```

2. Configure the backup settings:
   The script uses an external configuration file `.env-wordpress-backup` in the `scripts/` directory.
   
   **Option A**: Copy the example file and edit it:
   ```bash
   cp scripts/env-wordpress-backup.example scripts/.env-wordpress-backup
   nano scripts/.env-wordpress-backup
   ```
   
   **Option B**: On first run, the script will automatically create this file with placeholder values. Edit it:
   ```bash
   nano scripts/.env-wordpress-backup
   ```
   
   **Important variables to configure:**
   - `WP_FOLDER`: Path to your WordPress folder (use absolute paths!)
   - `BACKUP_FOLDER`: Path to store backups (use absolute paths!)
   - `USE_NO_TABLESPACES`: Set to `1` for shared hosting (default: 1)
   - Email settings: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `EMAIL_FROM`, `EMAIL_TO`
   
   For a complete list of all configuration variables, see the [Configuration Variables](#configuration-variables) section below.

3. Make the script executable:
   ```bash
   chmod +x scripts/wordpress-backup.sh
   ```

4. Test the script:
   
   **Option A: Direct execution via Terminal (if SSH access is available)**
   ```bash
   ./scripts/wordpress-backup.sh
   ```
   Check the `backup.log` file in the backup folder for results.
   
   **Option B: Execution via PHP trigger (if no SSH access)**
   - The shell script can be executed via the PHP trigger script (`trigger/wordpress-backup.php`)
   - The PHP script will automatically set execute permissions and run the backup script
   - **Important**: Only expose the `trigger/` directory via URL, never the `scripts/` directory
   - Example URL: `https://yourdomain.com/cronjobs/wordpress-backup-shell-script/trigger/wordpress-backup.php`
   - Access the URL via browser or configure it as a URL-based cronjob in your hosting panel
   - **Configuration**: Edit `trigger/wordpress-backup.php` to configure:
     - Script path (default: `../scripts/wordpress-backup.sh`)
     - Execution mode: `'sync'` (default, for all-inkl) or `'background'` (for IONOS to avoid timeouts)

5. Secure the PHP trigger (recommended):
   
   To protect the PHP trigger script from unauthorized access, add a `.htaccess` file in the `trigger/` directory that restricts access to specific IP addresses (e.g., the IP of your cronjob server):
   
   **Option A**: Copy the example file and edit it (if available):
   ```bash
   cp trigger/.htaccess.example trigger/.htaccess
   nano trigger/.htaccess
   ```
   
   **Option B**: Create the file manually with the following content:
   ```apache
   # Block all access by default
   Order Deny,Allow
   Deny from all
   
   # Allow access only for specific IPs (replace with your actual cronjob server IP)
   # Example: Allow from 85.13.130.203
   Allow from YOUR_CRONJOB_SERVER_IP
   ```
   
   **Note**: For Apache 2.4+, use `Require` syntax instead:
   ```apache
   # Require ip YOUR_CRONJOB_SERVER_IP
   # Example: Require ip 85.13.130.203
   Require ip YOUR_CRONJOB_SERVER_IP
   ```
   
   **Important**: Replace `YOUR_CRONJOB_SERVER_IP` with the actual IP address of your cronjob server. You can find this IP in your hosting panel's cronjob settings or by checking the server logs.

6. (Optional) Add a cronjob for automation:
   
   **Option A: Shell-based cronjob (if SSH access is available)**
   ```bash
   crontab -e
   ```
   Add the following line to schedule backups (e.g., daily at midnight):
   ```
   0 0 * * * /full/path/to/scripts/wordpress-backup.sh
   ```
   
   **Option B: URL-based cronjob (via hosting panel)**
   - Configure a URL-based cronjob in your hosting panel
   - **Important**: Use only the `trigger/` directory URL, never the `scripts/` directory
   - Example: `https://yourdomain.com/cronjobs/wordpress-backup-shell-script/trigger/wordpress-backup.php`
   - The `.htaccess` file will protect the trigger from unauthorized access

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

## PHP Trigger Script Configuration

The PHP trigger script (`trigger/wordpress-backup.php`) can be configured to work in different environments. Edit the configuration section at the top of the file:

### Configuration Options

| **Option** | **Description** | **Default** |
|------------|-----------------|-------------|
| `$shellScriptPath` | Path to the shell script (relative to PHP file). Change if your script is in a different location. | `../scripts/wordpress-backup.sh` |
| `$executionMode` | Execution mode: `'sync'` (waits for completion, default) or `'background'` (runs in background). | `'sync'` |

### Execution Modes

- **`'sync'`** (Synchronous, Default): 
  - Waits for script completion
  - Returns full output
  - Works well on all-inkl.com
  - May timeout on IONOS for large backups

- **`'background'`** (Background):
  - Runs script in background (detached from PHP process)
  - Returns PID immediately
  - Recommended for IONOS to avoid timeout issues
  - Check `BACKUP_FOLDER/backup.log` for progress
  - Falls back to sync mode if background execution fails

The PHP trigger script will:
- Automatically set execute permissions on the shell script
- Execute the backup script in a login shell environment
- Return the output and exit code (sync mode) or PID (background mode)
- Display success or error messages

---

## Script Workflow

### Step-by-Step Actions
1. Create a timestamped backup folder inside `BACKUP_FOLDER`.
2. Zip the WordPress files into `files.zip`:
   - Validates that the archive was created successfully.
   - Checks file size and warns if backup seems unusually small (< 100MB).
3. Create a compressed MySQL dump (`database.sql.gz`):
   - Automatically extract credentials from `wp-config.php`.
   - Includes detailed error handling with separate error log capture.
   - Validates backup file creation and size.
   - Warns if backup size seems unusually small (< 1KB).
   - Captures and logs detailed mysqldump error output on failure.
   - Checks for partial backup files and logs their content if small.
4. Maintain up to `MAX_BACKUPS` by deleting the oldest backups.
5. Log all actions and errors into `backup.log`.
6. If the backup fails:
   - Log the specific error(s) with detailed mysqldump error output.
   - Capture and display mysqldump exit codes.
   - Check for partial backup files and log their content if small.
   - Send an email with a summary of the issues.

---

## Example Log Output

A successful backup will generate log entries like this:
```plaintext
2025-08-29 15:30:01 - Starting backup for 2025-08-29...
2025-08-29 15:30:01 - WordPress folder: /path/to/wordpress
2025-08-29 15:30:01 - Backup target folder: /path/to/backups/2025-08-29
2025-08-29 15:30:15 - WordPress files successfully backed up: /path/to/backups/2025-08-29/files.zip (Size: 50M)
2025-08-29 15:30:20 - Creating database backup using mysqldump...
2025-08-29 15:30:25 - Database successfully backed up: /path/to/backups/2025-08-29/database.sql.gz (Size: 2M)
2025-08-29 15:30:30 - Deleted oldest backup: 2025-08-20 to maintain a maximum of 8 backups.
2025-08-29 15:30:35 - Backup completed successfully for 2025-08-29.
```

If errors occur, the corresponding log entries will include detailed information:
```plaintext
2025-08-29 15:30:20 - Creating database backup using mysqldump...
2025-08-29 15:30:25 - ERROR: WordPress database backup FAILED! (mysqldump exit code: 1)
2025-08-29 15:30:25 - mysqldump error output:
2025-08-29 15:30:25 -   Access denied for user 'dbuser'@'localhost' (using password: YES)
2025-08-29 15:30:25 - Partial backup file content (first 20 lines):
2025-08-29 15:30:25 -   -- MySQL dump failed
```

The script also checks for suspiciously small backups and logs warnings:
```plaintext
2025-08-29 15:30:15 - WARNING: Archive size seems unusually small: 512B (512 bytes)
2025-08-29 15:30:15 - This might indicate an incomplete backup. Please verify manually.
2025-08-29 15:30:25 - WARNING: Database backup size seems unusually small: 1.2K (1224 bytes)
2025-08-29 15:30:25 - This might indicate an incomplete backup. Please verify manually.
```

Additionally, in case of errors, an email will be sent to the configured email address.

Here's an example email:

**Subject**:  
`WordPress Backup Error Report for www.mydomain.de`

**Body**:
```plaintext
The backup of your WordPress-Website failed with the following error(s):

Host: server.example.com
Timestamp: 2025-08-29

Errors in this run:

2025-08-29 15:30:25 - ERROR: WordPress database backup FAILED! (mysqldump exit code: 1)
2025-08-29 15:30:25 - mysqldump error output:
2025-08-29 15:30:25 -   Access denied for user 'dbuser'@'localhost' (using password: YES)

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
   - **Security**: Never expose the `scripts/` directory via web URL. Only the `trigger/` directory should be accessible via URL, and it should be protected with `.htaccess` to restrict access to authorized IP addresses.

4. **Backup File Too Large**
   - WordPress backups can become very large, especially with many media files.
   - Consider excluding certain directories if you have SSH access and can modify the script.
   - For very large sites, consider using incremental backups or cloud storage solutions.

5. **Warnings About Small Backup Size**
   - If you see warnings about unusually small backup files, verify that:
     - The WordPress folder contains the expected files
     - The database is not empty
     - The backup process completed successfully
   - Small backups might indicate:
     - An incomplete backup
     - A new/empty WordPress installation
     - A problem with the backup process

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
