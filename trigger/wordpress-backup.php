<?php
/**
 * WordPress Backup Trigger Script
 *
 * Script Name:   wordpress-backup.php
 * Version:       1.2.0-beta.1
 * Description:   Sets execute permissions on the backup script and runs it
 *                via PHP when SSH/chmod is unavailable.
 * Author:        elektrischerwalfisch
 * License:       MIT License
 *
 * HOW TO USE:
 * 1. Set TRIGGER_TOKEN in scripts/.env-wordpress-backup
 * 2. Configure the settings below (script path, execution mode)
 * 3. Configure compression in scripts/.env-wordpress-backup:
 *    COMPRESSION_METHOD can be none, gzip, zip, or bzip2
 * 4. Call via URL with token, e.g. ?token=YOUR_TOKEN (or header X-Backup-Token)
 *
 * SECURITY:
 * - See README section "Trigger Security".
 */

// ============================================================================
// CONFIGURATION
// ============================================================================

// Shell script path (relative to this PHP file's directory)
// Default: ../scripts/wordpress-backup.sh (standard structure)
// Change this if your script is in a different location
$shellScriptPath = __DIR__ . "/../scripts/wordpress-backup.sh";

// Env file with TRIGGER_TOKEN (and other backup settings). Default: next to the shell script.
$envFilePath = __DIR__ . "/../scripts/.env-wordpress-backup";

// Execution mode: 'sync' or 'background'
// - 'sync': Waits for script completion (default, works on all-inkl)
// - 'background': Runs script in background (recommended for IONOS to avoid timeouts)
// HTTP response detail depends on $debugMode (see below).
$executionMode = 'sync'; // Change to 'background' for IONOS

// SECURITY: In production/cron, $debugMode MUST stay false (minimal HTTP output).
// Use true only for initial setup or troubleshooting; details are in backup.log.
$debugMode = false;

// Minimal HTTP responses (used when $debugMode is false)
$minimalMessageStarted = "Process started\n";
$minimalMessageFinished = "Process finished\n";
$minimalMessageError = "Error\n";
$minimalMessageForbidden = "Forbidden\n";

// ============================================================================
// OUTPUT HELPERS
// ============================================================================

function triggerRespondSuccess(string $minimalMessage, bool $debugMode, ?string $verboseMessage = null): void
{
    echo ($debugMode && $verboseMessage !== null) ? $verboseMessage : $minimalMessage;
}

function triggerRespondError(int $httpCode, string $minimalMessage, bool $debugMode, ?string $verboseMessage = null): void
{
    http_response_code($httpCode);
    echo ($debugMode && $verboseMessage !== null) ? $verboseMessage : $minimalMessage;
    exit(1);
}

/**
 * Read KEY=VALUE pairs from a shell-style .env file (quotes optional).
 *
 * @return array<string, string>
 */
function triggerLoadEnvFile(string $path): array
{
    if (!is_file($path) || !is_readable($path)) {
        return [];
    }

    $lines = file($path, FILE_IGNORE_NEW_LINES);
    if ($lines === false) {
        return [];
    }

    $values = [];
    foreach ($lines as $line) {
        $line = trim($line);
        if ($line === '' || $line[0] === '#') {
            continue;
        }
        $eqPos = strpos($line, '=');
        if ($eqPos === false) {
            continue;
        }
        $key = trim(substr($line, 0, $eqPos));
        $value = trim(substr($line, $eqPos + 1));
        if ($key === '') {
            continue;
        }
        // Strip matching single or double quotes around the value
        if (strlen($value) >= 2) {
            $first = $value[0];
            $last = $value[strlen($value) - 1];
            if (($first === '"' && $last === '"') || ($first === "'" && $last === "'")) {
                $value = substr($value, 1, -1);
            }
        }
        $values[$key] = $value;
    }

    return $values;
}

// ============================================================================
// TOKEN AUTHENTICATION
// ============================================================================

$envValues = triggerLoadEnvFile($envFilePath);
if ($envValues === []) {
    triggerRespondError(
        403,
        $minimalMessageForbidden,
        $debugMode,
        "ERROR: Missing or unreadable scripts/.env-wordpress-backup — create it from env-wordpress-backup.example and set TRIGGER_TOKEN.\n"
    );
}

$expectedToken = trim((string) ($envValues['TRIGGER_TOKEN'] ?? ''));
$providedToken = trim((string) ($_GET['token'] ?? $_POST['token'] ?? $_SERVER['HTTP_X_BACKUP_TOKEN'] ?? ''));

if ($expectedToken === '') {
    triggerRespondError(
        403,
        $minimalMessageForbidden,
        $debugMode,
        "ERROR: Forbidden — TRIGGER_TOKEN is empty in scripts/.env-wordpress-backup.\n"
    );
}

if ($providedToken === '') {
    triggerRespondError(
        403,
        $minimalMessageForbidden,
        $debugMode,
        "ERROR: Forbidden — missing token (use ?token=… or header X-Backup-Token).\n"
    );
}

if (!hash_equals($expectedToken, $providedToken)) {
    triggerRespondError(
        403,
        $minimalMessageForbidden,
        $debugMode,
        "ERROR: Forbidden — token mismatch.\n"
    );
}

// ============================================================================
// SCRIPT VALIDATION
// ============================================================================

// Use realpath() to get absolute canonical path (important for PHP exec())
$shellScript = realpath($shellScriptPath);

// Check if script exists
if (!$shellScript || !file_exists($shellScript)) {
    $verboseMessage = "ERROR: Script file not found: $shellScriptPath";
    if ($shellScript) {
        $verboseMessage .= " (resolved to: $shellScript)";
    }
    triggerRespondError(500, $minimalMessageError, $debugMode, $verboseMessage);
}

// Try to set execute permissions (won't work if PHP doesn't have write access)
// If this fails silently, it's usually fine - the script might already be executable
chmod($shellScript, 0755);

// Common troubleshooting hints for trigger errors.
$errorHint = "Hint: Check scripts/.env-wordpress-backup (COMPRESSION_METHOD) and verify required tools are installed.\n";
$logHint = "See BACKUP_FOLDER/backup.log for detailed diagnostics.\n";

// ============================================================================
// EXECUTE SCRIPT
// ============================================================================

if ($executionMode === 'background') {
    // Background execution (recommended for IONOS to avoid timeout issues)
    // Using setsid + nohup to completely detach from PHP process
    $scriptDir = dirname($shellScript);
    $command = "cd " . escapeshellarg($scriptDir) . " && setsid nohup bash -l -c " . escapeshellarg($shellScript . " 2>&1") . " > /dev/null 2>&1 < /dev/null & echo \$!";
    exec($command, $output, $returnCode);

    if (!empty($output) && is_numeric(trim($output[0]))) {
        $pid = trim($output[0]);
        $verboseMessage = "SUCCESS: Backup script started in background (PID: $pid).\n\n"
            . "The backup is now running. Check BACKUP_FOLDER/backup.log for progress.\n";
        triggerRespondSuccess($minimalMessageStarted, $debugMode, $verboseMessage);
    } else {
        $verboseMessage = "ERROR: Could not start backup in background.\n"
            . "Please check if setsid is available on your system.\n"
            . "If background execution is not available, change \$executionMode to 'sync' in the configuration.\n"
            . $errorHint
            . $logHint;
        triggerRespondError(500, $minimalMessageError, $debugMode, $verboseMessage);
    }
} else {
    // Synchronous execution (default, works on all-inkl)
    // Execute the shell script in a login shell environment (like SSH would)
    // This ensures environment variables and PATH are loaded correctly
    exec("bash -l -c " . escapeshellarg($shellScript) . " 2>&1", $output, $returnCode);

    // Return results
    if ($returnCode === 0) {
        $verboseMessage = "SUCCESS: Backup script completed successfully.\n\n"
            . "Output:\n"
            . implode("\n", $output);
        triggerRespondSuccess($minimalMessageFinished, $debugMode, $verboseMessage);
    } else {
        $verboseMessage = "ERROR: Backup script failed with exit code $returnCode.\n\n"
            . $errorHint
            . $logHint . "\n"
            . "Output:\n"
            . implode("\n", $output);
        triggerRespondError(500, $minimalMessageError, $debugMode, $verboseMessage);
    }
}
