<?php
/**
 * WordPress Backup Trigger Script
 * 
 * This PHP script sets execute permissions on the backup script and runs it.
 * Use this if you don't have SSH access to set chmod +x on the shell script.
 * 
 * HOW TO USE:
 * 1. Upload this file to your webspace (e.g., /path/to/trigger/wordpress-backup.php)
 * 2. Edit the $shellScript path below to point to your backup script
 * 3. Call this URL from a cron job or browser
 * 
 * SECURITY: Keep this file outside your public web directory or restrict access!
 */

// Define shell script path (relative to this PHP file's directory)
// The script is in ../scripts/ relative to the trigger/ directory
// Use realpath() to get absolute canonical path (important for PHP exec())
$shellScriptPath = __DIR__ . "/../scripts/wordpress-backup.sh";
$shellScript = realpath($shellScriptPath);

// Check if script exists
if (!$shellScript || !file_exists($shellScript)) {
    http_response_code(500);
    echo "ERROR: Script file not found: $shellScriptPath";
    if ($shellScript) {
        echo " (resolved to: $shellScript)";
    }
    exit(1);
}

// Try to set execute permissions (won't work if PHP doesn't have write access)
// If this fails silently, it's usually fine - the script might already be executable
chmod($shellScript, 0755);

// Execute the shell script in a login shell environment (like SSH would)
// This ensures environment variables and PATH are loaded correctly
exec("bash -l -c '$shellScript' 2>&1", $output, $returnCode);

// Return results
if ($returnCode === 0) {
    echo "SUCCESS: Backup script completed successfully.\n\n";
    echo "Output:\n";
    echo implode("\n", $output);
} else {
    http_response_code(500);
    echo "ERROR: Backup script failed with exit code $returnCode.\n\n";
    echo "Output:\n";
    echo implode("\n", $output);
}



