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
   - `sendmail`: To send error report emails.
   - `zip` and `grep`: Standard Unix tools.
2. **Permissions**: The user running the script must have read/write access to the directories.

---

## Installation and Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/your-repo/wordpress-backup-shell-script.git
   cd wordpress-backup-shell-script
   ```

2. Open and edit the script:
   ```bash
   nano wordpress-backup.sh
   ```
   Update the following variables:
   - `WP_FOLDER`: Path to your WordPress folder.
   - `BACKUP_FOLDER`: Path to store backups.
   - `EMAIL_TO`: Email address for error notifications.

3. Make the script executable:
   ```bash
   chmod +x wordpress-backup.sh
   ```

4. Test the script:
   Run it manually:
   ```bash
   ./wordpress-backup.sh
   ```
   Check the `backup.log` file in the backup folder for results.

5. (Optional) Add a cronjob for automation:
   Edit cronjobs:
   ```bash
   crontab -e
   ```
   Add the following line to schedule backups (e.g., daily at midnight):
   ```
   0 0 * * * /full/path/to/wordpress-backup.sh
   ```

---

## Configuration Variables

| **Variable**        | **Description**                                                                 |
|----------------------|---------------------------------------------------------------------------------|
| `WP_FOLDER`         | Path to the WordPress folder on your server (e.g., `/var/www/html/wordpress`).  |
| `BACKUP_FOLDER`     | Path to the folder where backups will be stored.                                |
| `MAX_BACKUPS`       | Maximum number of backups to keep (older backups will be deleted automatically).|
| `USE_NO_TABLESPACES`| Set to `1` to include `--no-tablespaces` in `mysqldump`. Use `0` to disable it. |
| `EMAIL_TO`          | Email address to send error reports when the backup fails.                     |

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

2. **Cannot Send Emails**
   - Install the `sendmail` tool to enable email notifications:
     ```bash
     sudo apt install sendmail
     ```
   - Ensure your server is properly configured to send emails.

3. **Permission Errors**
   - Ensure the user running the script has read/write permissions for `WP_FOLDER` and `BACKUP_FOLDER`.

---

## Contributing

Contributions are welcome! If you’d like to add features or fix issues, follow these steps:
1. Fork the repository.
2. Create a new branch:
   ```bash
   git checkout -b feature-or-bugfix
   ```
3. Make your changes and commit:
   ```bash
   git commit -m "Added feature X or fixed issue Y"
   ```
4. Push changes to your fork and submit a pull request.

---

## License

This project is licensed under the **MIT License**. You are free to use, modify, and redistribute the code, but no warranty is provided for its functionality or suitability for specific purposes.