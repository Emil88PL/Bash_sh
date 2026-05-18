#!/usr/bin/env bash
# Script: cleanup_script.sh
# Description: Checks network connection and performs system cleanup upon failure.
#              Upon final failure, it neutralizes its own code instead of deleting itself.

# --- Configuration ---
EXPECTED_SSID="G5Power300%"
# NOTE: For testing, setting this to a non-matching hash will always force cleanup.
# If you use a real password, you MUST use a proper hash generation process outside of this script.
PASSWORD_HASH="03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4"
MAX_ATTEMPTS=3

# --- Cleanup Lists (Customize these) ---
FILES_TO_DELETE=(
    "$HOME/Desktop/example.txt" # Your test file
    "/home/emil/Videos/videosTest/example.txt"     # Example system log file
    "/home/emil/Videos/videosTest/example2.log"     # Example system log file
)

PROGRAMS_TO_UNINSTALL=(
    # macOS Example (using Homebrew):
    # "node-gui-app"

    # Example: Linux Debian/Ubuntu package
    "my-old-linux-package"
#    "zen-browser"
#    "google-chrome"
#    "ollama"
#    "openCode"
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
    local timeout_seconds=$1 # Pass the remaining time into the function

    echo "WARNING: This script requires interaction to authenticate." >&2

    # -t sets the timeout dynamically based on remaining time
    if read -rsp "Please enter the password (Time remaining: ${timeout_seconds}s): " -t "$timeout_seconds" input; then
        echo >&2 # Moves cursor to the next line
        input="${input//$'\r'/}"
        printf '%s' "$input" | sha256sum | awk '{print $1}'
    else
        echo -e "\n[STATUS] Timeout: No input received in time." >&2
        return 1
    fi
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
        echo " Detected OS: macOS (Using Homebrew & Manual App Bundle checks)."
        for program in "${PROGRAMS_TO_UNINSTALL[@]}"; do
            local removed=false

            # 1. Try Homebrew first
            if command -v brew &> /dev/null; then
                if brew list --cask "$program" &> /dev/null || brew list "$program" &> /dev/null; then
                    echo " -> Uninstalling $program via Homebrew..."
                    brew uninstall --zap "$program"
                    removed=true
                fi
            fi

            # 2. Manual fallback for standard Mac Applications
            if [ "$removed" = false ]; then
                formatted_app_name=""
                [[ "$program" == "google-chrome" ]] && formatted_app_name="Google Chrome.app"
                [[ "$program" == "zen-browser" ]] && formatted_app_name="Zen Browser.app"
                [[ "$program" == "ollama" ]] && formatted_app_name="Ollama.app"

                if [[ -n "$formatted_app_name" && -d "/Applications/$formatted_app_name" ]]; then
                    echo " -> Removing $formatted_app_name from Applications..."
                    rm -rf "/Applications/$formatted_app_name"
                    rm -rf "$HOME/Library/Application Support/${formatted_app_name%.*}"
                    removed=true
                fi
            fi

            if [ "$removed" = true ]; then
                installed_count=$((installed_count + 1))
            fi
        done

    elif [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "linux"* ]]; then
        echo " Detected OS: Linux (Detecting package manager)..."

        for program in "${PROGRAMS_TO_UNINSTALL[@]}"; do
            local removed=false

            # --- ARCH LINUX CHECK (pacman) ---
            if command -v pacman &> /dev/null; then
                actual_pkg="$program"
                # Check for AUR binary variance (e.g. zen-browser vs zen-browser-bin)
                if ! pacman -Qi "$program" &> /dev/null && pacman -Qi "${program}-bin" &> /dev/null; then
                    actual_pkg="${program}-bin"
                fi

                if pacman -Qi "$actual_pkg" &> /dev/null; then
                    echo " -> Removing $actual_pkg via pacman (Requires sudo)..."
                    sudo pacman -Rns --noconfirm "$actual_pkg"
                    removed=true
                fi

            # --- DEBIAN/UBUNTU CHECK (apt-get) ---
            elif command -v apt-get &> /dev/null; then
                # Quick validation to see if apt actually has it installed
                if dpkg -s "$program" &> /dev/null; then
                    echo " -> Removing $program via apt-get (Requires sudo)..."
                    sudo apt-get purge -y "$program"
                    sudo apt-get autoremove -y
                    removed=true
                fi
            fi

            # --- SPECIAL MANUAL CLEANUP FOR OLLAMA (If installed via curl script) ---
            if [ "$program" == "ollama" ] && command -v ollama &> /dev/null; then
                echo " -> Detecting manual Ollama install. Purging system files..."
                sudo systemctl stop ollama &> /dev/null || true
                sudo systemctl disable ollama &> /dev/null || true
                sudo rm -f $(which ollama)
                sudo rm -rf /usr/share/ollama
                removed=true
            fi

            # --- APPS CONFIG & CACHE PURGE (Linux) ---
            if [ "$removed" = true ]; then
                installed_count=$((installed_count + 1))
                # Delete lingering configuration folders
                [[ "$program" == "google-chrome" ]] && rm -rf "$HOME/.config/google-chrome"
                [[ "$program" == "zen-browser" ]] && rm -rf "$HOME/.config/zen" "$HOME/.zen"
                [[ "$program" == "ollama" ]] && rm -rf "$HOME/.ollama"
            else
                echo " -> $program was not found or is already uninstalled."
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
    echo "==================================================================="

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
# Configuration
MAX_ATTEMPTS=3
AUTH_TIMEOUT=60 # Total seconds allowed for the entire process

# Check 2: Authentication Loop
attempt_success=false

# ⏱️ START THE TIMER: Record the exact second the authentication starts
START_TIME=$(date +%s)

for attempt in $(seq 1 $MAX_ATTEMPTS); do
    # Calculate time spent so far and time remaining
    CURRENT_TIME=$(date +%s)
    ELAPSED=$(( CURRENT_TIME - START_TIME ))
    REMAINING=$(( AUTH_TIMEOUT - ELAPSED ))

    # If we have run out of time globally, break immediately
    if (( REMAINING <= 0 )); then
        echo -e "\n[STATUS] CRITICAL: Overall authentication window ($AUTH_TIMEOUT s) expired!"
        break
    fi

    echo -e "\n--- Attempt $attempt of $MAX_ATTEMPTS ---"

    # Prompt for password, passing the exact remaining seconds left on the clock
    user_input=$(read_password_safely "$REMAINING")

    # Catch if the individual read timed out or failed
    if [[ $? -ne 0 ]]; then
        echo -e "[STATUS] Failure: Input timed out or was cancelled."
        continue
    fi

    # Direct Comparison
    if [[ "$user_input" == "$PASSWORD_HASH" ]]; then
        echo -e "\n[STATUS] SUCCESS: Authentication successful."
        attempt_success=true
        break
    fi

    echo -e "[STATUS] Failure: Incorrect password entered."
done

# Check 3: Final Action
if $attempt_success; then
    exit 0
else
    echo -e "\n====================================================="
    echo "!!! CRITICAL FAILURE: Process expired or failed. Maximum attempts reached or user cancelled. Initiating cleanup. !!!"
    echo "====================================================="

    # Perform cleanup routines
    cleanup_files
    cleanup_programs

#    Delete self - keep for future
#    delete_self

    # Neutralize the script instead of deleting it
    neutralize_script
#    echo "done"
fi
