#!/bin/bash

# =============================================================================
# SIMULATOR SCREENSHOT TOOL
# =============================================================================
#
# PURPOSE:
#   Captures screenshots from iOS Simulator or Android Emulator.
#   Designed for automation and AI agent integration.
#
# USAGE:
#   ./screenshot.sh <platform> [output_path] [options]
#
# ARGUMENTS:
#   platform      Required. Target platform: "ios" or "android"
#   output_path   Optional. Path for screenshot file (default: screenshot_YYYYMMDD_HHMMSS.png)
#
# OPTIONS:
#   --id, -i <device_id>   Specify device by ID:
#                          - iOS: Device name (e.g., "iPhone 15 Pro") or UDID
#                          - Android: Serial number (e.g., "emulator-5554")
#   --list, -l             List all available devices for the platform
#   --json, -j             Output results in JSON format (recommended for AI agents)
#   --help, -h             Show help message
#
# EXAMPLES:
#   # List available iOS simulators
#   ./screenshot.sh ios --list
#
#   # List available Android emulators
#   ./screenshot.sh android --list
#
#   # Capture from default booted iOS simulator
#   ./screenshot.sh ios ./screenshot.png
#
#   # Capture from specific iOS simulator by name
#   ./screenshot.sh ios ./screenshot.png --id "iPhone 15 Pro"
#
#   # Capture from specific iOS simulator by UDID
#   ./screenshot.sh ios ./screenshot.png --id "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
#
#   # Capture from specific Android emulator
#   ./screenshot.sh android ./screenshot.png --id emulator-5554
#
#   # Get JSON output (recommended for AI agents)
#   ./screenshot.sh ios ./screenshot.png --json
#   ./screenshot.sh ios --list --json
#
# JSON OUTPUT FORMAT:
#   Success:
#   {
#     "status": "success",
#     "message": "Screenshot captured successfully",
#     "platform": "ios",
#     "path": "/absolute/path/to/screenshot.png",
#     "device_id": "iPhone 15 Pro",
#     "timestamp": "2026-01-28T14:30:00Z"
#   }
#
#   Error:
#   {
#     "status": "error",
#     "message": "No iOS Simulator is currently running",
#     "platform": "ios",
#     "timestamp": "2026-01-28T14:30:00Z"
#   }
#
#   List devices:
#   {
#     "status": "success",
#     "message": "Listed iOS devices",
#     "platform": "ios",
#     "devices": [
#       {"name": "iPhone 15 Pro", "udid": "XXXX-XXXX", "state": "Booted"},
#       {"name": "iPhone 15", "udid": "YYYY-YYYY", "state": "Shutdown"}
#     ],
#     "timestamp": "2026-01-28T14:30:00Z"
#   }
#
# EXIT CODES:
#   0 - Success
#   1 - Error (device not found, no simulator running, invalid arguments, etc.)
#
# REQUIREMENTS:
#   iOS:     Xcode with Command Line Tools, jq (for JSON device listing)
#   Android: Android SDK with adb in PATH, jq (for JSON device listing)
#
# AI AGENT INSTRUCTIONS:
#   1. Always use --json flag to parse output reliably
#   2. If no --id is provided, the tool uses the currently booted/running device
#   3. Use --list first to discover available devices if device ID is unknown
#   4. Check "status" field in JSON response: "success" or "error"
#   5. The "path" field contains the absolute path to the saved screenshot
#   6. For iOS, you can use friendly names like "iPhone 15 Pro" instead of UDIDs
#
# =============================================================================

set -e

PLATFORM="${1}"
OUTPUT_PATH=""
DEVICE_ID=""
LIST_DEVICES=false
JSON_OUTPUT=false

# Pre-scan for --json flag (needed before parsing other args)
for arg in "$@"; do
    if [[ "$arg" == "--json" || "$arg" == "-j" ]]; then
        JSON_OUTPUT=true
        break
    fi
done

# Helper function for logging (respects JSON mode)
log() {
    if ! $JSON_OUTPUT; then
        echo "$1"
    fi
}

# Helper function for error logging (respects JSON mode)
log_error() {
    if ! $JSON_OUTPUT; then
        echo "$1" >&2
    fi
}

# JSON output helper
output_json() {
    local status="$1"
    local message="$2"
    local path="${3:-}"
    local devices="${4:-}"
    
    echo "{"
    echo "  \"status\": \"$status\","
    echo "  \"message\": \"$message\","
    echo "  \"platform\": \"$PLATFORM\","
    if [ -n "$path" ]; then
        echo "  \"path\": \"$path\","
    fi
    if [ -n "$DEVICE_ID" ]; then
        echo "  \"device_id\": \"$DEVICE_ID\","
    fi
    if [ -n "$devices" ]; then
        echo "  \"devices\": $devices,"
    fi
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
    echo "}"
}

# Parse arguments
shift || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --id|-i)
            DEVICE_ID="$2"
            shift 2
            ;;
        --list|-l)
            LIST_DEVICES=true
            shift
            ;;
        --json|-j)
            JSON_OUTPUT=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [ios|android] [output_path] [options]"
            echo ""
            echo "Arguments:"
            echo "  platform      Target platform: 'ios' or 'android' (default: ios)"
            echo "  output_path   Path for the screenshot (default: screenshot_TIMESTAMP.png)"
            echo ""
            echo "Options:"
            echo "  --id, -i      Device ID (UDID for iOS, serial for Android)"
            echo "  --list, -l    List available devices/simulators"
            echo "  --json, -j    Output result in JSON format"
            echo "  --help, -h    Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 ios ~/Desktop/screen.png"
            echo "  $0 ios screenshot.png --id 'iPhone 15 Pro'"
            echo "  $0 ios screenshot.png --id XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
            echo "  $0 android ./screens/android.png --id emulator-5554"
            echo "  $0 ios --list"
            echo "  $0 android --list"
            exit 0
            ;;
        *)
            if [ -z "$OUTPUT_PATH" ]; then
                OUTPUT_PATH="$1"
            fi
            shift
            ;;
    esac
done

# Set default output path if not provided
if [ -z "$OUTPUT_PATH" ]; then
    OUTPUT_PATH="screenshot_$(date +%Y%m%d_%H%M%S).png"
fi

# List iOS simulators
list_ios_devices() { 
    if $JSON_OUTPUT; then
        DEVICES=$(xcrun simctl list devices -j | jq -c '[.devices | to_entries[] | .value[] | select(.isAvailable == true) | {name: .name, udid: .udid, state: .state}]')
        output_json "success" "Listed iOS devices" "" "$DEVICES"
    else
        echo "📱 Available iOS Simulators:"
        echo ""
        echo "BOOTED DEVICES:"
        xcrun simctl list devices | grep "Booted" || echo "  (none)"
        echo ""
        echo "ALL AVAILABLE DEVICES:"
        xcrun simctl list devices available
        echo ""
        echo "💡 Use device name or UDID with --id flag"
        echo "ℹ️ Device need to be booted to capture screenshot"
    fi
}

# List Android emulators
list_android_devices() {
    if ! command -v adb &> /dev/null; then
        log_error "❌ Error: adb not found"
        if $JSON_OUTPUT; then
            output_json "error" "adb not found"
        fi
        exit 1
    fi
    
    if $JSON_OUTPUT; then
        # Get running devices from adb
        RUNNING_DEVICES=$(adb devices | tail -n +2 | grep -v "^$" | awk '{print $1}')
        
        # Get all available AVDs (created emulators)
        if command -v emulator &> /dev/null; then
            DEVICES=$(emulator -list-avds 2>/dev/null | while read -r avd; do
                if [ -n "$avd" ]; then
                    # Check if this AVD is currently running
                    state="Shutdown"
                    for running in $RUNNING_DEVICES; do
                        # Get AVD name from running emulator
                        running_avd=$(adb -s "$running" emu avd name 2>/dev/null | head -1 | tr -d '\r')
                        if [ "$running_avd" == "$avd" ]; then
                            state="Running"
                            break
                        fi
                    done
                    echo "{\"name\": \"$avd\", \"state\": \"$state\"}"
                fi
            done | jq -s '.')
        else
            # Fallback to just running devices if emulator command not found
            DEVICES=$(adb devices | tail -n +2 | grep -v "^$" | awk '{print "{\"id\": \"" $1 "\", \"state\": \"" $2 "\"}"}' | jq -s '.')
        fi
        
        # Also include running device serials for --id usage
        RUNNING=$(adb devices | tail -n +2 | grep -v "^$" | awk '{print "{\"serial\": \"" $1 "\", \"state\": \"" $2 "\"}"}' | jq -s '.')
        
        # Combine into final output
        COMBINED=$(jq -n --argjson avds "$DEVICES" --argjson running "$RUNNING" '{avds: $avds, running_devices: $running}')
        output_json "success" "Listed Android devices" "" "$COMBINED"
    else
        echo "🤖 Available Android Emulators:"
        echo ""
        echo "CREATED AVDs:"
        if command -v emulator &> /dev/null; then
            emulator -list-avds 2>/dev/null || echo "  (none)"
        else
            echo "  (emulator command not found)"
        fi
        echo ""
        echo "RUNNING DEVICES:"
        adb devices -l | tail -n +2 | grep -v "^$" || echo "  (none)"
        echo ""
        echo "💡 Use AVD name or serial (e.g., emulator-5554) with --id flag"
        echo "ℹ️ Device needs to be running to capture screenshot"
    fi
}


# Resolve iOS device ID (supports name or UDID)
resolve_ios_device() {
    local input="$1"
    
    # If it looks like a UDID, use it directly
    if [[ "$input" =~ ^[A-F0-9-]{36}$ ]]; then
        echo "$input"
        return
    fi
    
    # Try to find by name (get first booted match, or first available)
    local udid
    udid=$(xcrun simctl list devices -j | jq -r --arg name "$input" '
        .devices | to_entries[] | .value[] | 
        select(.name == $name and .isAvailable == true) |
        select(.state == "Booted") | .udid' | head -1)
    
    if [ -z "$udid" ]; then
        # Try to find any available device with that name
        udid=$(xcrun simctl list devices -j | jq -r --arg name "$input" '
            .devices | to_entries[] | .value[] | 
            select(.name == $name and .isAvailable == true) | .udid' | head -1)
    fi
    
    if [ -z "$udid" ]; then
        echo ""
        return 1
    fi
    
    echo "$udid"
}

# Take iOS screenshot
take_ios_screenshot() {
    local target="booted"
    
    if [ -n "$DEVICE_ID" ]; then
        resolved_id=$(resolve_ios_device "$DEVICE_ID")
        if [ -z "$resolved_id" ]; then
            log_error "❌ Error: Device '$DEVICE_ID' not found"
            if $JSON_OUTPUT; then
                output_json "error" "Device not found: $DEVICE_ID"
            fi
            exit 1
        fi
        target="$resolved_id"
        log "📱 Using iOS Simulator: $DEVICE_ID ($resolved_id)"
    else
        log "📱 Capturing from booted iOS Simulator..."
    fi
    
    # Check if target is booted (if using 'booted')
    if [ "$target" == "booted" ]; then
        if ! xcrun simctl list devices | grep -q "Booted"; then
            log_error "❌ Error: No iOS Simulator is currently running"
            if $JSON_OUTPUT; then
                output_json "error" "No iOS Simulator is currently running"
            fi
            exit 1
        fi
    fi
    
    # Ensure output directory exists
    OUTPUT_DIR=$(dirname "$OUTPUT_PATH")
    if [ "$OUTPUT_DIR" != "." ] && [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
    fi
    
    xcrun simctl io "$target" screenshot "$OUTPUT_PATH"
    
    if [ $? -eq 0 ]; then
        FULL_PATH=$(realpath "$OUTPUT_PATH")
        log "✅ iOS screenshot saved to: $FULL_PATH"
        if $JSON_OUTPUT; then
            output_json "success" "Screenshot captured successfully" "$FULL_PATH"
        fi
    else
        log_error "❌ Failed to capture iOS screenshot"
        if $JSON_OUTPUT; then
            output_json "error" "Failed to capture screenshot"
        fi
        exit 1
    fi
}

# Take Android screenshot
take_android_screenshot() {
    if ! command -v adb &> /dev/null; then
        log_error "❌ Error: adb not found. Please install Android SDK platform-tools"
        if $JSON_OUTPUT; then
            output_json "error" "adb not found"
        fi
        exit 1
    fi
    
    local adb_target=""
    
    if [ -n "$DEVICE_ID" ]; then
        # Verify device exists
        if ! adb devices | grep -q "$DEVICE_ID"; then
            log_error "❌ Error: Device '$DEVICE_ID' not found"
            if $JSON_OUTPUT; then
                output_json "error" "Device not found: $DEVICE_ID"
            fi
            exit 1
        fi
        adb_target="-s $DEVICE_ID"
        log "🤖 Using Android Emulator: $DEVICE_ID"
    else
        log "🤖 Capturing from default Android Emulator..."
        # Check if any device is connected
        DEVICE_COUNT=$(adb devices | grep -c "device$" || true)
        if [ "$DEVICE_COUNT" -eq 0 ]; then
            log_error "❌ Error: No Android Emulator is currently running"
            if $JSON_OUTPUT; then
                output_json "error" "No Android Emulator is currently running"
            fi
            exit 1
        fi
    fi
    
    # Ensure output directory exists
    OUTPUT_DIR=$(dirname "$OUTPUT_PATH")
    if [ "$OUTPUT_DIR" != "." ] && [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
    fi
    
    # Capture screenshot
    TEMP_PATH="/sdcard/screenshot_temp.png"
    adb $adb_target shell screencap -p "$TEMP_PATH"
    adb $adb_target pull "$TEMP_PATH" "$OUTPUT_PATH"
    adb $adb_target shell rm "$TEMP_PATH"
    
    if [ $? -eq 0 ]; then
        FULL_PATH=$(realpath "$OUTPUT_PATH")
        log "✅ Android screenshot saved to: $FULL_PATH"
        if $JSON_OUTPUT; then
            output_json "success" "Screenshot captured successfully" "$FULL_PATH"
        fi
    else
        log_error "❌ Failed to capture Android screenshot"
        if $JSON_OUTPUT; then
            output_json "error" "Failed to capture screenshot"
        fi
        exit 1
    fi
}

# Main execution
case "$PLATFORM" in
    ios|iOS|IOS)
        PLATFORM="ios"
        if $LIST_DEVICES; then
            list_ios_devices
        else
            take_ios_screenshot
        fi
        ;;
    android|Android|ANDROID)
        PLATFORM="android"
        if $LIST_DEVICES; then
            list_android_devices
        else
            take_android_screenshot
        fi
        ;;
    *)
        log_error "❌ Error: Invalid platform '$PLATFORM'"
        log_error "Usage: $0 [ios|android] [output_path] [--id <device_id>]"
        if $JSON_OUTPUT; then
            output_json "error" "Invalid platform: $PLATFORM"
        fi
        exit 1
        ;;
esac
