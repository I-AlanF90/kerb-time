#!/bin/bash
#
# kerb-time.sh
# Kerberos Clock Skew Helper
#
# Queries a target's NTP offset and runs commands through faketime
# without modifying the host system clock.
#
# Usage:
#   ./kerb-time.sh <DC_IP>
#   ./kerb-time.sh <DC_IP> -c "<command>"
#
# Examples:
#   ./kerb-time.sh 10.10.239.152
#
#   ./kerb-time.sh 10.10.239.152 -c \
#     "netexec ldap 10.10.239.152 -u 'Alanf90' -p 'password234' --kerberoast kerb.out "

set -u

TIMEOUT=5
USER_COMMAND=""

usage() {
    echo "Usage:"
    echo "  $0 <DC_IP>"
    echo "  $0 <DC_IP> -c \"<command>\""
    echo
    echo "Options:"
    echo "  -c    Command to execute with the calculated time offset"
    echo "  -h    Show this help message"
    exit 1
}

# -------------------------
# Arguments
# -------------------------

if [ $# -lt 1 ]; then
    usage
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

DC_IP="$1"
shift

while getopts ":c:h" opt; do
    case "$opt" in
        c)
            USER_COMMAND="$OPTARG"
            ;;
        h)
            usage
            ;;
        :)
            echo "[!] Option -$OPTARG requires an argument."
            exit 1
            ;;
        \?)
            echo "[!] Unknown option: -$OPTARG"
            usage
            ;;
    esac
done

# -------------------------
# Dependencies
# -------------------------

for cmd in ntpdate faketime timeout awk date; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[!] Missing dependency: $cmd"
        exit 1
    fi
done

# -------------------------
# Query DC
# -------------------------

echo "[*] Querying DC NTP time: $DC_IP"

NTP_OUTPUT=$(timeout "$TIMEOUT" ntpdate -q "$DC_IP" 2>&1)
RC=$?

if [ "$RC" -eq 124 ]; then
    echo "[!] Timed out after ${TIMEOUT}s contacting $DC_IP"
    echo "[!] Check your VPN, pivot, and route."
    exit 1
fi

if [ "$RC" -ne 0 ]; then
    echo "[!] ntpdate failed:"
    echo "$NTP_OUTPUT"
    exit 1
fi

echo
echo "[*] NTP response:"
echo "    $NTP_OUTPUT"

# -------------------------
# Extract offset
# -------------------------

OFFSET=$(echo "$NTP_OUTPUT" | awk '{
    for (i=1; i<=NF; i++) {
        if ($i ~ /^[+-][0-9]+(\.[0-9]+)?$/) {
            print $i
            exit
        }
    }
}')

if [ -z "$OFFSET" ]; then
    echo
    echo "[!] Could not extract clock offset."
    exit 1
fi

ABS_OFFSET="${OFFSET#-}"
ABS_OFFSET="${ABS_OFFSET#+}"

OFFSET_INT="${ABS_OFFSET%%.*}"

HOURS=$((OFFSET_INT / 3600))
MINUTES=$(((OFFSET_INT % 3600) / 60))
SECONDS=$((OFFSET_INT % 60))

if [[ "$OFFSET" == -* ]]; then
    SIGN="-"
else
    SIGN="+"
fi

# -------------------------
# Display results
# -------------------------

echo
echo "[+] DC clock skew:"
printf "    %s%02dh %02dm %02ds\n" \
    "$SIGN" "$HOURS" "$MINUTES" "$SECONDS"

echo
echo "[+] Exact offset:"
echo "    ${OFFSET}s"

echo
echo "[*] Local system time:"
echo "    $(date)"

echo
echo "[*] Kerberos-adjusted time:"
echo "    $(faketime -f "${OFFSET}s" date)"

# -------------------------
# Get command
# -------------------------

if [ -z "$USER_COMMAND" ]; then
    echo
    read -r -p "Command to run: " USER_COMMAND
fi

if [ -z "$USER_COMMAND" ]; then
    echo "[!] No command entered."
    exit 1
fi

# -------------------------
# Execute
# -------------------------

echo
echo "[*] Running with DC-adjusted time:"
echo "    $USER_COMMAND"
echo
echo "[*] Local system clock will NOT be modified."
echo

faketime -f "${OFFSET}s" bash -c "$USER_COMMAND"
