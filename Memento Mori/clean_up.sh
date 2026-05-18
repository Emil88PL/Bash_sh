#!/usr/bin/env bash
# Script: cleanup_script.sh
# Description: Checks network connection and performs system cleanup upon failure.
#              Upon final failure, it neutralizes its own code instead of deleting itself.

# --- Configuration ---
EXPECTED_SSID="Not Work network name"
# NOTE: For testing, setting this to a non-matching hash will always force cleanup.
# If you use a real password, you MUST use a proper hash generation process outside of this script.
PASSWORD_HASH="03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4"
MAX_ATTEMPTS=3

# --- Cleanup Lists (Customize these) ---
FILES_TO_DELETE=(
    "$HOME/Desktop/example.txt" # Your test file
    "/var/log/old_data.log"     # Example system log file
)

PROGRAMS_TO_UNINSTALL=(
    # macOS Example (using Homebrew):
    # "node-gui-app"

    # Example: Linux Debian/Ubuntu package
    "my-old-linux-package"
)

# --- Platform Detection & Utilities ---

# Function to get the current SSID (Adapted from your original code)
get_current_ssid() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        # We assume en0 is the primary Wi-Fi adapter
        networksetup -getairportnetwork en0 | sed 's/^Current Wi-Fi Network: //'
    else
        # Linux (Arch-friendly & robust)

        # 1. Try NetworkManager if it's installed and actively running
        if command -v nmcli >/dev/null 2>&1 && systemctl is-active --quiet NetworkManager; then
            nmcli -t -f TYPE,NAME connection show --active | grep '^802-11-wireless:' | cut -d: -f2-

        # 2. Fallback to querying the kernel via 'iw' (works for iwd, wpa_supplicant, etc.)
        elif command -v iw >/dev/null 2>&1; then
            for dev in $(iw dev | awk '/Interface/ {print $2}'); do
                ssid=$(iw dev "$dev" link | sed -n 's/^\s*SSID:\s*//p')
                if [[ -n "$ssid" ]]; then
                    echo "$ssid"
                    return 0
                fi
            done

        # 3. Last resort fallback to older wireless-tools
        elif command -v iwgetid >/dev/null 2>&1; then
            iwgetid -r
        fi
    fi
}

# Function to simulate secure input (Only works interactively)
read_password_safely() {
    # 1. Send text prompts to stderr (>&2) so they display on screen
    echo "WARNING: This script requires interaction to authenticate." >&2
    read -rsp "Please enter the password: " input
    echo >&2 # Moves cursor to the next line

    # 2. Clean the input
    input="${input//$'\r'/}"

    # 3. Hash the input
    INPUT_HASH=$(printf '%s' "$input" | sha256sum | awk '{print $1}')

    # 4. Send the debug line to stderr so you can see it right now!
    # echo "DEBUG: Generated hash is: ->$INPUT_HASH<-" >&2

    # 5. Output ONLY the final hash to stdout so your outer script captures it
    echo "$INPUT_HASH"
}

# --- Core Cleanup Functions ---

# 1. Deletes specified files and folders
cleanup_files() {
    echo -e "\n[CLEANUP] Starting file deletion process..."
    local deleted_count=0
    for file_path in "${FILES_TO_DELETE[@]}"; do
        if [ -f "$file_path" ] || [ -d "$file_path" ]; then
            echo " -> Deleting: $file_path"
            rm -rf "$file_path"
            if [ $? -eq 0 ]; then
                deleted_count=$((deleted_count + 1))
            fi
        else
            echo " -> Skipping: $file_path (Not found)"
        fi
    done
    echo "[CLEANUP] Finished. Successfully deleted $deleted_count items."
}

# 2. Uninstalls specified programs
cleanup_programs() {
    echo -e "\n[CLEANUP] Starting program uninstallation process..."
    local installed_count=0

    # Determine OS and package manager
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo " Detected OS: macOS (Using Homebrew recommendations)."
        for program in "${PROGRAMS_TO_UNINSTALL[@]}"; do
            # Add macOS-specific package manager calls here (e.g., brew uninstall)
            # Example: brew uninstall "$program"
            echo " -> (MOCK) Uninstalling $program..."
            # Add actual command here if needed
            installed_count=$((installed_count + 1))
        done
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo " Detected OS: Linux (Attempting apt-get removal with sudo)."
        
        # Use a case structure for robust cross-distribution support
        for program in "${PROGRAMS_TO_UNINSTALL[@]}"; do
            echo " -> Attempting removal of $program (Requires sudo)..."
            # WARNING: This requires running the script with elevated permissions 
            # or having 'sudo' configured for non-password entry.
            if command -v apt-get &> /dev/null; then
                sudo apt-get remove -y "$program"
                if [ $? -eq 0 ]; then
                    installed_count=$((installed_count + 1))
                fi
            # Add other distro checks here (dnf, yum, pacman)
            fi
        done
    else
        echo " [CLEANUP] WARNING: Unsupported OS type for uninstallation."
    fi

    echo "[CLEANUP] Finished. Processed $installed_count programs."
}

# 3. Neutralization Mechanism (Replaces Self-Deletion)
neutralize_script() {
    echo -e "\n==================================================================="
    echo "!!! CRITICAL ACTION: SCRIPT IS NEUTRALIZING ITS OWN CODE BASE !!!"
    echo "====================================================="

    # Writes the harmless message to the current file path ($0)
    echo "this is empty as should be" > "$0"

    echo "[STATUS] SUCCESS: The script has been neutralized. Running code will now result in a harmless output."
    echo "[STATUS] ACTION: The file $0 is now overwritten."
}

## 3. Self-Deletion Mechanism
#delete_self() {
#    echo -e "\n====================================================="
#    echo "!!! CRITICAL ACTION: THIS SCRIPT IS NOW DELETING ITSELF !!!"
#    echo "====================================================="
#
#    # Safety mechanism: We echo the command instead of running it immediately
#    echo "To completely remove this script, run the following command manually:"
#    echo "rm -f $(readlink -f \"$0\")"
#
#    # If you MUST delete it automatically (Use with extreme caution!)
#    # trap "rm -f \"$0\"" EXIT
#    # exit 0


# --- Main Logic Execution ---

# Get initial SSID
CURRENT_SSID="$(get_current_ssid)"

echo "--- Network Check Initializing ---"
echo "Expected SSID: $EXPECTED_SSID"
echo "Current SSID: $CURRENT_SSID"

# Check 1: Is it connected to the correct network?
if [[ "$CURRENT_SSID" == "$EXPECTED_SSID" ]]; then
    echo -e "\n[STATUS] SUCCESS: Connected to the expected network. No action taken."
    exit 0
fi

echo -e "\n[STATUS] WARNING: Connection failure detected. Authentication attempt required."

# Check 2: Authentication Loop
attempt_success=false
for attempt in $(seq 1 $MAX_ATTEMPTS); do
    echo -e "\n--- Attempt $attempt of $MAX_ATTEMPTS ---"

    # Prompt for password (this returns the hash of what the user typed)
    user_input=$(read_password_safely)

    # DIRECT COMPARISON (No double-hashing!)
    if [[ "$user_input" == "$PASSWORD_HASH" ]]; then
        echo -e "\n[STATUS] SUCCESS: Authentication successful."
        attempt_success=true
        break # Exit loop on success
    fi

    echo -e "[STATUS] Failure: Incorrect password entered."
done

# Check 3: Final Action
if $attempt_success; then
    exit 0
else
    echo -e "\n====================================================="
    echo "!!! CRITICAL FAILURE: Maximum attempts reached or user cancelled. Initiating cleanup. !!!"
    echo "====================================================="

    # Perform cleanup routines
    cleanup_files
    cleanup_programs

#    Delete self - keep for future
#    delete_self

    # Neutralize the script instead of deleting it
#    neutralize_script
    echo "done"
fi
