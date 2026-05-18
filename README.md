***

# 🛡️ Automated Network & System Cleanup Script

This script is designed to run automatically and verify network connectivity to a critical SSID. If the connection fails, it will prompt for authentication (if run manually) and, upon failure, perform a systematic cleanup by deleting specified files and uninstalling specified software, and then self-terminate.

---

## ⚠️ 🚨 CRITICAL SECURITY WARNING 🚨 ⚠️

**THIS IS A HIGHLY POWERFUL AND DESTRUCTIVE SCRIPT.**

1.  **REVIEW ALL COMMANDS:** Before executing or deploying this script, **you MUST manually audit and verify** every item listed in the `FILES_TO_DELETE` and `PROGRAMS_TO_UNINSTALL` arrays. Running incorrect paths or package names can lead to permanent data loss or system instability.
2.  **TESTING:** Test this script only in a sandboxed environment.
3.  **EXECUTION:** This script uses system-level commands (`rm`, `sudo`, `brew`, etc.). Running it requires careful understanding of the underlying operating system commands.

---

## 📚 Script Structure and Customization

The core logic is contained in `cleanup_script.sh`. Before setup, you must customize the following sections:

### 🛠️ 1. Configuration

| Variable | Purpose | Required Action |
| :--- | :--- | :--- |
| `EXPECTED_SSID` | The exact name of the network you must be connected to. | Change `"YourNetworkName"` to your actual SSID. |
| `PASSWORD_HASH` | The SHA256 hash of your network password. | **Crucial:** Generate the hash *before* setting it. (e.g., `echo -n "YourPassword" | sha256sum`) |
| `FILES_TO_DELETE` | An array containing absolute paths to files or folders to be permanently deleted. | Add your paths (e.g., `"/home/user/old_data.log"`). |
| `PROGRAMS_TO_UNINSTALL` | An array listing programs/packages to be removed. | Use the appropriate package manager syntax (e.g., `"my-old-package"`). |

### 🔎 2. The Script (`cleanup_script.sh`)

*(Paste the full script content here)*

```bash
#!/usr/bin/env bash
# Script: cleanup_script.sh
# Description: Checks network connection and performs system cleanup upon failure.

# --- Configuration ---
EXPECTED_SSID="YourNetworkName"
PASSWORD_HASH="replace_with_hash" 
MAX_ATTEMPTS=3

# --- Cleanup Lists (CUSTOMIZE THESE ARRAYS) ---
FILES_TO_DELETE=(
    "$HOME/Desktop/example.txt" # Example test file
    "/var/log/old_data.log"     # Example system log file
)

PROGRAMS_TO_UNINSTALL=(
    # Example: macOS Homebrew uninstall
    # "node-gui-app" 
    
    # Example: Linux Debian/Ubuntu package
    "my-old-linux-package" 
)

# (Include the rest of the script logic here...)
```

---

## 🧪 How to Set Up and Test

### Step 1: Preparation (Make the Script Executable)

Open your terminal and run:
```bash
chmod +x ./cleanup_script.sh
```

### Step 2: Manual Test (Interactive Run)

Run the script directly from the terminal. This is the only way to properly test the password prompt feature.

```bash
./cleanup_script.sh
```
*   **Expected Behavior:** The script should output the connection check, then prompt you for the password. If you enter the wrong password three times, it should trigger the cleanup routines and print the self-deletion command.

### Step 3: Scheduling the Script (Automation)

**⚠️ Critical Note:** When running via `cron` or `launchd`, the environment is non-interactive. The script **WILL NOT** be able to prompt for the password. If the connection check fails in a scheduled environment, the cleanup routine will run automatically.

#### 🍎 For macOS Users (Using launchd)

We use `launchd` as it is the modern, preferred scheduler.

1.  **Create the Plist:** Create a file named `com.user.cleanup.plist` in your `~/Library/LaunchAgents/` directory.
2.  **Paste Content:** Paste the following XML structure, ensuring you update the path to your script:

    ```xml
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.dtd">
    <plist version="1.0">
    <dict>
        <key>Label</key>
        <string>com.user.cleanup</string>
        <key>ProgramArguments</key>
        <array>
            /bin/bash
            /path/to/cleanup_script.sh 
        </array>
        <key>StartCalendarInterval</key>
        <dict>
            <hour>11</hour>
            <minute>11</minute>
        </dict>
        <key>RunAtLoad</key>
        <true/>
    </dict>
    </plist>
    ```

3.  **Load the Job:** Load the job into the system:
    ```bash
    launchctl load ~/Library/LaunchAgents/com.user.cleanup.plist
    ```

#### 🐧 For Linux Users (Using Cron)

1.  **Edit Crontab:** Open your user's cron table:
    ```bash
    crontab -e
    ```
2.  **Add the Entry:** Add the following line to run the script every day at 11:11. We redirect all output (`>> /tmp/cleanup_log.log 2>&1`) so you can check if it ran successfully.
    ```cron
    11 11 * * * /bin/bash /path/to/cleanup_script.sh >> /tmp/cleanup_log.log 2>&1
    ```

---

## 💾 Summary of Challenges and Assumptions

Understanding these limitations is crucial for reliable operation:

| Area | Challenge/Assumption | Impact |
| :--- | :--- | :--- |
| **Scheduling Environment** | `cron` and `launchd` run in a non-interactive, headless terminal. | **The Password Prompt Feature Will Fail.** If the connection check fails, the cleanup logic will execute automatically without asking for a password. |
| **Authentication** | The script relies on hash matching. | The password must be hashed correctly **before** being set in the script. If the hash is wrong, cleanup runs. |
| **Privilege Escalation** | Installing/Uninstalling software requires elevated permissions (e.g., `sudo`). | The script must be run, or the scheduled task must run, with permissions that allow the cleanup functions (e.g., running `sudo apt-get remove` within the script). |
| **Self-Termination** | The script uses a final command (`rm -f`) to clean up itself. | **This command is inherently risky.** It is recommended to manually copy the self-deletion command provided by the script rather than letting it run automatically. |
| **Cross-Platform Code** | The platform detection handles macOS and Linux separately. | Any future operating system changes or unique system commands must be manually updated within the `get_current_ssid` function. |