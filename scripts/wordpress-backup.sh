#!/bin/bash

# Script Name: Wordpress Backup Shell Script
# Description: Automates the backup of Wordpress project files and database with logging and error reporting.
# Author: elektrischerwalfisch
# Author URL: https://www.elektrischerwalfisch.de/
#
# NOTE: If you don't have SSH access to set execute permissions (chmod +x),
# you can create a PHP trigger file (see trigger/presets/wordpress-backup.php)
# that will set permissions and execute this script via PHP's exec().

# Load configuration from external file
# This allows keeping project-specific paths and credentials out of version control
# Resolve script directory robustly (works even when $0 is relative or when run via PHP exec)
# Method: cd to directory of script and get absolute path
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.env-wordpress-backup"

# Load config file if it exists
if [ -f "$CONFIG_FILE" ]; then
  # Source the config file (this will set all variables)
  if ! source "$CONFIG_FILE"; then
    echo "ERROR: Failed to load configuration file: $CONFIG_FILE" >&2
    exit 1
  fi
else
  # Auto-generate config file with all variables if it doesn't exist
  cat > "$CONFIG_FILE" <<'EOF'
# WordPress Backup Configuration File
# This file contains project-specific settings and should NOT be committed to version control.
# Keep this file secure (chmod 600) and update the values below.

# WordPress and backup paths (use absolute paths!)
WP_FOLDER="/path/to/wordpress"
BACKUP_FOLDER="/path/to/wordpress-backups"
# LOG_FILE will be set automatically to $BACKUP_FOLDER/backup.log if not specified
# You can override it with an absolute path if needed
# LOG_FILE="/custom/path/to/backup.log"
MAX_BACKUPS=8                         # Maximum number of backups to keep
USE_NO_TABLESPACES=1                  # Set to 1 to use "--no-tablespaces", 0 to disable

# Email notification settings
SEND_EMAIL_ON_ERROR=1                 # Set to 1 to enable email notification on errors
EMAIL_SUBJECT_DEFAULT="WordPress Backup Error Report for www.mydomain.de"

# SMTP settings for shared hosting
SMTP_HOST="mail.yourdomain.tld"
SMTP_PORT="587"
SMTP_USER="backup@yourdomain.tld"
SMTP_PASS="your_password"

# Email addresses
EMAIL_FROM="backup@yourdomain.tld"
EMAIL_TO="info@yourdomain.tld"
EOF
  chmod 600 "$CONFIG_FILE" 2>/dev/null || true
  echo "WARNING: Configuration file $CONFIG_FILE was missing and has been created with placeholder values." >&2
  echo "Please edit $CONFIG_FILE and update all paths and credentials before running the backup." >&2
fi

# Set default values (used if config file doesn't define a variable)
WP_FOLDER="${WP_FOLDER:-/path/to/wordpress}"
BACKUP_FOLDER="${BACKUP_FOLDER:-/path/to/wordpress-backups}"
MAX_BACKUPS="${MAX_BACKUPS:-8}"
USE_NO_TABLESPACES="${USE_NO_TABLESPACES:-1}"
SEND_EMAIL_ON_ERROR="${SEND_EMAIL_ON_ERROR:-1}"
EMAIL_SUBJECT_DEFAULT="${EMAIL_SUBJECT_DEFAULT:-WordPress Backup Error Report}"

# Set LOG_FILE after BACKUP_FOLDER is loaded (expand variables if needed)
LOG_FILE="${LOG_FILE:-$BACKUP_FOLDER/backup.log}"

# Load email settings early (needed for error handling)
EMAIL_TO="${EMAIL_TO:-info@mydomain.de}"
EMAIL_SUBJECT_DEFAULT="${EMAIL_SUBJECT_DEFAULT:-WordPress Backup Error Report}"
EMAIL_SUBJECT="${EMAIL_SUBJECT:-$EMAIL_SUBJECT_DEFAULT}"
EMAIL_FROM="${EMAIL_FROM:-backup@mydomain.de}"

# SMTP settings (with defaults)
SMTP_HOST="${SMTP_HOST:-mail.yourdomain.tld}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USER="${SMTP_USER:-backup@mydomain.de}"
SMTP_PASS="${SMTP_PASS:-your_password}"

# Initialize error tracking early (before validation)
TIMESTAMP=$(date +"%Y-%m-%d")
RUN_ERROR_FILE="/tmp/backup_errors_$$.log"
SENDMAIL_BIN="$(command -v sendmail || true)"

# Simple early error handler (works before LOG_FILE is available)
early_error_exit() {
  local error_msg="$1"
  local now_ts="$(date +'%Y-%m-%d %H:%M:%S')"
  
  # Output error
  echo "ERROR: $error_msg" >&2
  
  # Try to send email if enabled
  if [ "$SEND_EMAIL_ON_ERROR" -eq 1 ]; then
    EMAIL_BODY_FILE="/tmp/backup_error_email_early.txt"
    echo "To: $EMAIL_TO" > "$EMAIL_BODY_FILE"
    echo "From: $EMAIL_FROM" >> "$EMAIL_BODY_FILE"
    echo "Subject: $EMAIL_SUBJECT" >> "$EMAIL_BODY_FILE"
    echo "" >> "$EMAIL_BODY_FILE"
    echo "The backup of your WordPress-Website failed with the following error:" >> "$EMAIL_BODY_FILE"
    echo "" >> "$EMAIL_BODY_FILE"
    echo "Host: $(hostname)" >> "$EMAIL_BODY_FILE"
    echo "Timestamp: $now_ts" >> "$EMAIL_BODY_FILE"
    echo "" >> "$EMAIL_BODY_FILE"
    echo "Error: $error_msg" >> "$EMAIL_BODY_FILE"
    echo "" >> "$EMAIL_BODY_FILE"
    echo "Please investigate the issue for resolution." >> "$EMAIL_BODY_FILE"
    
    # Try SMTP via curl
    if command -v curl >/dev/null 2>&1 && [ -n "$SMTP_HOST" ] && [ -n "$SMTP_USER" ] && [ -n "$SMTP_PASS" ] && [ "$SMTP_HOST" != "mail.yourdomain.tld" ]; then
      local smtp_msg_file="/tmp/backup_error_smtp_early.txt"
      local body_content=$(grep -A 1000 "^$" "$EMAIL_BODY_FILE" | tail -n +2)
      printf "Subject: $EMAIL_SUBJECT\r\nFrom: $EMAIL_FROM\r\nTo: $EMAIL_TO\r\n\r\n$body_content\r\n" > "$smtp_msg_file"
      curl -s --url "smtp://$SMTP_HOST:$SMTP_PORT" --ssl-reqd \
        --mail-from "$EMAIL_FROM" \
        --mail-rcpt "$EMAIL_TO" \
        --user "$SMTP_USER:$SMTP_PASS" \
        --upload-file "$smtp_msg_file" >/dev/null 2>&1
      rm -f "$smtp_msg_file"
    elif [ -n "$SENDMAIL_BIN" ] && [ -x "$SENDMAIL_BIN" ]; then
      "$SENDMAIL_BIN" -t -i -f "$EMAIL_FROM" < "$EMAIL_BODY_FILE" >/dev/null 2>&1
    fi
    rm -f "$EMAIL_BODY_FILE"
  fi
  
  exit 1
}

# Validate that critical variables are set (not using placeholder values)
if [ "$WP_FOLDER" = "/path/to/wordpress" ] || [ -z "$WP_FOLDER" ]; then
  early_error_exit "WP_FOLDER is not configured. Please set it in: $CONFIG_FILE"
fi

if [ "$BACKUP_FOLDER" = "/path/to/wordpress-backups" ] || [ -z "$BACKUP_FOLDER" ]; then
  early_error_exit "BACKUP_FOLDER is not configured. Please set it in: $CONFIG_FILE"
fi

# Validate that paths are absolute (start with /)
if [ "${WP_FOLDER#/}" = "$WP_FOLDER" ]; then
  early_error_exit "WP_FOLDER must be an absolute path (starting with /), got: $WP_FOLDER"
fi

if [ "${BACKUP_FOLDER#/}" = "$BACKUP_FOLDER" ]; then
  early_error_exit "BACKUP_FOLDER must be an absolute path (starting with /), got: $BACKUP_FOLDER"
fi

# Validate critical paths exist
if [ ! -d "$WP_FOLDER" ]; then
  early_error_exit "WordPress folder does not exist: $WP_FOLDER"
fi

if [ ! -f "$WP_FOLDER/wp-config.php" ]; then
  early_error_exit "wp-config.php not found in: $WP_FOLDER"
fi

# Define logging function (used throughout the script)
log_message() {
  local message="$1"
  local now_ts="$(date +'%Y-%m-%d %H:%M:%S')"
  
  # If running interactively (terminal), also output to terminal
  if [ -t 1 ]; then
    echo "$now_ts - $message"
  fi
  
  # Ensure log directory exists before writing
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || {
    echo "ERROR: Cannot create log directory: $(dirname "$LOG_FILE")" >&2
    return 1
  }
  
  # Write to main log file
  echo "$now_ts - $message" >> "$LOG_FILE" 2>/dev/null || {
    echo "ERROR: Cannot write to log file: $LOG_FILE" >&2
  }
  
  # If this is an ERROR line, also record it in the per-run error file
  if [[ "$message" == ERROR:* ]] && [ -n "$RUN_ERROR_FILE" ]; then
    echo "$now_ts - $message" >> "$RUN_ERROR_FILE"
  fi
}

# Function to send an email in case of error
send_email_if_error() {
  if [ "$SEND_EMAIL_ON_ERROR" -eq 1 ]; then
    EMAIL_BODY_FILE="/tmp/backup_error_email.txt"

    # Write the required email content (for sendmail/SMTP)
    echo "To: $EMAIL_TO" > "$EMAIL_BODY_FILE"
    echo "From: $EMAIL_FROM" >> "$EMAIL_BODY_FILE"
    echo "Subject: $EMAIL_SUBJECT" >> "$EMAIL_BODY_FILE"
    echo "" >> "$EMAIL_BODY_FILE"  # Empty line separates headers from the body
    echo "The backup of your WordPress-Website failed with the following error(s):" >> "$EMAIL_BODY_FILE"
    echo "" >> "$EMAIL_BODY_FILE"

    # Add short context (without sensitive paths)
    echo "Host: $(hostname)" >> "$EMAIL_BODY_FILE"
    echo "Timestamp: $TIMESTAMP" >> "$EMAIL_BODY_FILE"
    echo "" >> "$EMAIL_BODY_FILE"
    echo "Errors in this run:" >> "$EMAIL_BODY_FILE"
    echo "" >> "$EMAIL_BODY_FILE"

    # Append only this run's ERROR messages if available; otherwise, fall back to last 20 ERRORs from log
    if [ -n "$RUN_ERROR_FILE" ] && [ -s "$RUN_ERROR_FILE" ]; then
      cat "$RUN_ERROR_FILE" >> "$EMAIL_BODY_FILE"
    else
      grep "ERROR:" "$LOG_FILE" 2>/dev/null | tail -n 20 >> "$EMAIL_BODY_FILE"
    fi
    echo "" >> "$EMAIL_BODY_FILE"
    echo "Please investigate the issue for resolution." >> "$EMAIL_BODY_FILE"

    # Try SMTP via curl first (works on all-inkl), then sendmail
    if command -v curl >/dev/null 2>&1 && [ -n "$SMTP_HOST" ] && [ -n "$SMTP_USER" ] && [ -n "$SMTP_PASS" ] && [ "$SMTP_HOST" != "mail.yourdomain.tld" ]; then
      log_message "Attempting to send error email via SMTP (curl)..."
      # Create message file for curl (strip headers from body for SMTP)
      local smtp_msg_file="/tmp/backup_error_smtp.txt"
      local body_content=$(grep -A 1000 "^$" "$EMAIL_BODY_FILE" | tail -n +2)
      printf "Subject: $EMAIL_SUBJECT\r\nFrom: $EMAIL_FROM\r\nTo: $EMAIL_TO\r\n\r\n$body_content\r\n" > "$smtp_msg_file"
      
      curl -s --url "smtp://$SMTP_HOST:$SMTP_PORT" --ssl-reqd \
        --mail-from "$EMAIL_FROM" \
        --mail-rcpt "$EMAIL_TO" \
        --user "$SMTP_USER:$SMTP_PASS" \
        --upload-file "$smtp_msg_file" >/dev/null 2>&1
      SEND_STATUS=$?
      rm -f "$smtp_msg_file"
      
      if [ $SEND_STATUS -ne 0 ]; then
        log_message "ERROR: SMTP (curl) failed with status $SEND_STATUS"
      else
        log_message "Sent error email via SMTP (curl)."
      fi
    elif [ -n "$SENDMAIL_BIN" ] && [ -x "$SENDMAIL_BIN" ]; then
      log_message "SMTP not configured; attempting to send error email via sendmail..."
      "$SENDMAIL_BIN" -t -i -f "$EMAIL_FROM" < "$EMAIL_BODY_FILE"
      SEND_STATUS=$?
      if [ $SEND_STATUS -ne 0 ]; then
        log_message "ERROR: sendmail failed with status $SEND_STATUS"
      else
        log_message "Sent error email via sendmail."
      fi
    else
      log_message "ERROR: No available method to send error email (SMTP not configured and sendmail missing)."
    fi

    # Clean up temporary email body file
    rm -f "$EMAIL_BODY_FILE"
  fi
}

# Auto-detect database credentials from wp-config.php using AWK
WP_CONFIG_FILE="$WP_FOLDER/wp-config.php"
if [ ! -f "$WP_CONFIG_FILE" ]; then
  log_message "ERROR: wp-config.php not found at: $WP_CONFIG_FILE"
  send_email_if_error
  exit 1
fi

DB_NAME=$(awk -F"'" '/DB_NAME/{print $4}' "$WP_CONFIG_FILE")
DB_USER=$(awk -F"'" '/DB_USER/{print $4}' "$WP_CONFIG_FILE")
DB_PASS=$(awk -F"'" '/DB_PASSWORD/{print $4}' "$WP_CONFIG_FILE")
DB_HOST=$(awk -F"'" '/DB_HOST/{print $4}' "$WP_CONFIG_FILE")

# Validate that credentials were extracted
if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ] || [ -z "$DB_HOST" ]; then
  log_message "ERROR: Failed to extract database credentials from wp-config.php"
  log_message "  DB_NAME: ${DB_NAME:-[empty]}"
  log_message "  DB_USER: ${DB_USER:-[empty]}"
  log_message "  DB_PASS: ${DB_PASS:+[set]}"
  log_message "  DB_HOST: ${DB_HOST:-[empty]}"
  send_email_if_error
  exit 1
fi

# Create target backup folder
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
  # Verify the archive was created and is not empty
  if [ ! -f "$ZIP_FILE" ]; then
    log_message "ERROR: Archive file was not created: $ZIP_FILE"
    send_email_if_error
    exit 1
  fi
  
  # Get file size using stat (more reliable in shared hosting)
  ZIP_SIZE_BYTES=$(stat -c %s "$ZIP_FILE" 2>/dev/null || echo "0")
  ZIP_SIZE=$(echo "$ZIP_SIZE_BYTES" | awk '{if($1>1024*1024*1024) printf "%.1fG", $1/1024/1024/1024; else if($1>1024*1024) printf "%.1fM", $1/1024/1024; else if($1>1024) printf "%.1fK", $1/1024; else printf "%dB", $1}' || echo "unknown")
  
  # Check if archive seems too small (less than 100MB might indicate incomplete backup)
  if [ "$ZIP_SIZE_BYTES" -lt 104857600 ] && [ "$ZIP_SIZE_BYTES" -gt 0 ]; then
    log_message "WARNING: Archive size seems unusually small: $ZIP_SIZE ($ZIP_SIZE_BYTES bytes)"
    log_message "This might indicate an incomplete backup. Please verify manually."
  fi
  
  log_message "WordPress files successfully backed up: $ZIP_FILE (Size: $ZIP_SIZE)"
else
  log_message "ERROR: WordPress files backup FAILED!"
  send_email_if_error
  exit 1
fi

# Step 2: Create a database backup using mysqldump
log_message "Creating database backup using mysqldump..."

DB_BACKUP_FILE="$BACKUP_TARGET/database.sql.gz"

# Build tablespace option based on configuration
if [ "$USE_NO_TABLESPACES" -eq 1 ]; then
  TABLESPACE_OPTION="--no-tablespaces"
else
  TABLESPACE_OPTION=""
fi

# Create database backup using mysqldump
# Capture stderr separately to capture any error messages
MYSQLDUMP_ERR_FILE="$BACKUP_TARGET/mysqldump_error.log"

# Compressed backup (WordPress always uses gzip)
mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" $TABLESPACE_OPTION "$DB_NAME" 2> "$MYSQLDUMP_ERR_FILE" | gzip > "$DB_BACKUP_FILE"
MYSQLDUMP_EXIT_CODE=${PIPESTATUS[0]}

if [ $MYSQLDUMP_EXIT_CODE -eq 0 ]; then
  # Verify the backup file was created and is not empty
  if [ ! -f "$DB_BACKUP_FILE" ]; then
    log_message "ERROR: Database backup file was not created: $DB_BACKUP_FILE"
    send_email_if_error
    exit 1
  fi
  
  # Get file size
  DB_SIZE_BYTES=$(stat -c %s "$DB_BACKUP_FILE" 2>/dev/null || echo "0")
  DB_SIZE=$(echo "$DB_SIZE_BYTES" | awk '{if($1>1024*1024*1024) printf "%.1fG", $1/1024/1024/1024; else if($1>1024*1024) printf "%.1fM", $1/1024/1024; else if($1>1024) printf "%.1fK", $1/1024; else printf "%dB", $1}' || echo "unknown")
  
  # Check if backup seems too small (less than 1KB might indicate an error)
  if [ "$DB_SIZE_BYTES" -lt 1024 ] && [ "$DB_SIZE_BYTES" -gt 0 ]; then
    log_message "WARNING: Database backup size seems unusually small: $DB_SIZE ($DB_SIZE_BYTES bytes)"
    log_message "This might indicate an incomplete backup. Please verify manually."
  fi
  
  log_message "Database successfully backed up: $DB_BACKUP_FILE (Size: $DB_SIZE)"
  
  # Clean up error file if backup was successful
  rm -f "$MYSQLDUMP_ERR_FILE" 2>/dev/null || true
else
  log_message "ERROR: WordPress database backup FAILED! (mysqldump exit code: $MYSQLDUMP_EXIT_CODE)"
  # Log error output if available
  if [ -f "$MYSQLDUMP_ERR_FILE" ] && [ -s "$MYSQLDUMP_ERR_FILE" ]; then
    log_message "mysqldump error output:"
    while IFS= read -r line; do
      log_message "  $line"
    done < "$MYSQLDUMP_ERR_FILE"
  fi
  # Also check if partial file was created and log its content if small
  if [ -f "$DB_BACKUP_FILE" ]; then
    DB_SIZE_BYTES=$(stat -c %s "$DB_BACKUP_FILE" 2>/dev/null || echo "0")
    if [ "$DB_SIZE_BYTES" -lt 10240 ]; then
      log_message "Partial backup file content (first 20 lines):"
      head -n 20 "$DB_BACKUP_FILE" 2>/dev/null | while IFS= read -r line; do
        log_message "  $line"
      done || true
    fi
  fi
  # Clean up error file
  rm -f "$MYSQLDUMP_ERR_FILE" 2>/dev/null || true
  send_email_if_error
  exit 1
fi

# Step 3: Ensure a maximum of MAX_BACKUPS in the backup folder
# Use shell globbing instead of ls (more reliable in shared hosting, especially via PHP exec())
BACKUPS_COUNT=0
OLDEST_BACKUP=""
OLDEST_DATE=""

# Count backups and find oldest using shell globbing
for backup in "$BACKUP_FOLDER"/*; do
  if [ -d "$backup" ]; then
    ((BACKUPS_COUNT++))
    # Get modification time (seconds since epoch)
    BACKUP_DATE=$(stat -c %Y "$backup" 2>/dev/null || echo "0")
    if [ -z "$OLDEST_DATE" ] || [ "$BACKUP_DATE" -lt "$OLDEST_DATE" ]; then
      OLDEST_DATE="$BACKUP_DATE"
      OLDEST_BACKUP="$(basename "$backup")"
    fi
  fi
done

if [ "$BACKUPS_COUNT" -gt "$MAX_BACKUPS" ]; then
  if [ -n "$OLDEST_BACKUP" ] && rm -rf "$BACKUP_FOLDER/$OLDEST_BACKUP"; then
    log_message "Deleted oldest backup: $OLDEST_BACKUP to maintain a maximum of $MAX_BACKUPS backups."
  else
    log_message "ERROR: Failed to delete oldest backup: $OLDEST_BACKUP"
    send_email_if_error
    exit 1
  fi
fi

# Finish logging
log_message "Backup completed successfully for $TIMESTAMP."