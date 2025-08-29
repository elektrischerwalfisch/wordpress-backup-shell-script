#!/bin/bash

# Define WordPress and backup configuration
WP_FOLDER="path/to/wordpress"         # Path to your WordPress folder
BACKUP_FOLDER="path/to/backups"       # Path to the backups folder
LOG_FILE="$BACKUP_FOLDER/backup.log"  # Path to the log file
MAX_BACKUPS=8                         # Maximum number of backups to keep
USE_NO_TABLESPACES=0                  # Set to 1 to use "--no-tablespaces", 0 to disable (needed at some webhosters)

# Email settings
SEND_EMAIL_ON_ERROR=0                # Set to 1 to enable email notification on errors
EMAIL_TO="youremail@example.com"     # Email address to send error reports
EMAIL_SUBJECT="WordPress Backup Error Report"
EMAIL_BODY_FILE="/tmp/backup_error_email.txt"

# Auto-detect database credentials from wp-config.php using AWK
DB_NAME=$(awk -F"'" '/DB_NAME/{print $4}' $WP_FOLDER/wp-config.php)
DB_USER=$(awk -F"'" '/DB_USER/{print $4}' $WP_FOLDER/wp-config.php)
DB_PASS=$(awk -F"'" '/DB_PASSWORD/{print $4}' $WP_FOLDER/wp-config.php)
DB_HOST=$(awk -F"'" '/DB_HOST/{print $4}' $WP_FOLDER/wp-config.php)

# Logging function
log_message() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to send an email in case of error
send_email_if_error() {
  if [ "$SEND_EMAIL_ON_ERROR" -eq 1 ]; then
    echo -e "Subject: $EMAIL_SUBJECT\n\n$(cat "$LOG_FILE")" > "$EMAIL_BODY_FILE"
    /usr/sbin/sendmail "$EMAIL_TO" < "$EMAIL_BODY_FILE"
    rm -f "$EMAIL_BODY_FILE" # Clean up temporary email file
  fi
}

# Create timestamp and target backup folder
TIMESTAMP=$(date +"%Y-%m-%d")
BACKUP_TARGET="$BACKUP_FOLDER/$TIMESTAMP"
mkdir -p "$BACKUP_TARGET" || { 
  log_message "ERROR: Failed to create backup folder: $BACKUP_TARGET"; 
  send_email_if_error; 
  exit 1; 
}

# Start logging
log_message "Starting backup for $TIMESTAMP..."
log_message "WordPress folder: $WP_FOLDER"
log_message "Backup target folder: $BACKUP_TARGET"

# Step 1: Create a zipped backup of the WordPress folder
ZIP_FILE="$BACKUP_TARGET/files.zip"
if zip -r "$ZIP_FILE" "$WP_FOLDER" > /dev/null 2>&1; then
  ZIP_SIZE=$(du -h "$ZIP_FILE" | cut -f1)
  log_message "WordPress files successfully backed up: $ZIP_FILE (Size: $ZIP_SIZE)"
else
  log_message "ERROR: WordPress files backup FAILED!"
  send_email_if_error
  exit 1
fi

# Step 2: Compress and dump the database
DB_BACKUP_FILE="$BACKUP_TARGET/database.sql.gz"

if [ "$USE_NO_TABLESPACES" -eq 1 ]; then
  TABLESPACE_OPTION="--no-tablespaces"
else
  TABLESPACE_OPTION=""
fi

if mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" $TABLESPACE_OPTION "$DB_NAME" | gzip > "$DB_BACKUP_FILE"; then
  DB_SIZE=$(du -h "$DB_BACKUP_FILE" | cut -f1)
  log_message "Database successfully backed up: $DB_BACKUP_FILE (Size: $DB_SIZE)"
else
  log_message "ERROR: Database backup FAILED! Check credentials and database configuration."
  send_email_if_error
  exit 1
fi

# Step 3: Ensure a maximum of MAX_BACKUPS in the backup folder
BACKUPS_COUNT=$(ls -t "$BACKUP_FOLDER" | wc -l)
if [ "$BACKUPS_COUNT" -gt "$MAX_BACKUPS" ]; then
  OLDEST_BACKUP=$(ls -t "$BACKUP_FOLDER" | tail -1)
  if rm -rf "$BACKUP_FOLDER/$OLDEST_BACKUP"; then
    log_message "Deleted oldest backup: $OLDEST_BACKUP to maintain a maximum of $MAX_BACKUPS backups."
  else
    log_message "ERROR: Failed to delete oldest backup: $OLDEST_BACKUP"
    send_email_if_error
    exit 1
  fi
fi

# Finish logging
log_message "Backup completed successfully for $TIMESTAMP."