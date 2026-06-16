i
#!/usr/bin/env bash

if python3 --version 2>&1 | grep -q "^Python"; then
    echo "python3 is available on your environment"
else
    echo "Warning! python3 is missing"
fi

read -p "Enter a string, it will be used as an extension 'attendance_tracker_{input}': " usr_input

if [ -z "$usr_input" ]; then
    echo "Error: No input provided. Exiting."
    exit 1
fi

if [ -d "attendance_tracker_${usr_input}" ]; then
    echo "Error: Directory already exists. Choose a different name."
    exit 1
fi

mkdir -p "attendance_tracker_${usr_input}"
mkdir -p "./attendance_tracker_${usr_input}/Helpers"
mkdir -p "./attendance_tracker_${usr_input}/reports"

target_fd="./attendance_tracker_${usr_input}"
helpers_fd="./attendance_tracker_${usr_input}/Helpers"
reports_fd="./attendance_tracker_${usr_input}/reports"

cancel_bundle () {
    echo ""
    echo "Initializing clean interruption"
    archive_name="attendance_tracker_${usr_input}_archive.tar.gz"
    tar -czf $archive_name "attendance_tracker_${usr_input}"
    echo "Created archive folder ${archive_name}"
    rm -r $target_fd
    echo "Deleted incomplete directory"
    exit 1
}

trap cancel_bundle SIGINT

cat > "${target_fd}/attendance_checker.py" << 'PYEOF'
import csv
import json
import os
from datetime import datetime

def run_attendance_check():
    with open('Helpers/config.json', 'r') as f:
        config = json.load(f)

    if os.path.exists('reports/reports.log'):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        os.rename('reports/reports.log', f'reports/reports_{timestamp}.log.archive')

    with open('Helpers/assets.csv', mode='r') as f, open('reports/reports.log', 'w') as log:
        reader = csv.DictReader(f)
        total_sessions = config['total_sessions']
        log.write(f"--- Attendance Report Run: {datetime.now()} ---\n")
        for row in reader:
            name = row['Names']
            email = row['Email']
            attended = int(row['Attendance Count'])
            attendance_pct = (attended / total_sessions) * 100
            message = ""
            if attendance_pct < config['thresholds']['failure']:
                message = f"URGENT: {name}, your attendance is {attendance_pct:.1f}%. You will fail this class."
            elif attendance_pct < config['thresholds']['warning']:
                message = f"WARNING: {name}, your attendance is {attendance_pct:.1f}%. Please be careful."
            if message:
                if config['run_mode'] == "live":
                    log.write(f"[{datetime.now()}] ALERT SENT TO {email}: {message}\n")
                    print(f"Logged alert for {name}")
                else:
                    print(f"[DRY RUN] Email to {email}: {message}")

if __name__ == "__main__":
    run_attendance_check()
PYEOF

cat > "${helpers_fd}/assets.csv" << 'CSVEOF'
Email,Names,Attendance Count,Absence Count
alice@example.com,Alice Johnson,14,1
bob@example.com,Bob Smith,7,8
charlie@example.com,Charlie Davis,4,11
diana@example.com,Diana Prince,15,0
CSVEOF

cat > "${helpers_fd}/config.json" << 'JSONEOF'
{
    "thresholds": {
        "warning": 75,
        "failure": 50
    },
    "run_mode": "live",
    "total_sessions": 15
}
JSONEOF

cat > "${reports_fd}/reports.log" << 'LOGEOF'
--- Attendance Report Run: 2026-02-06 18:10:01.468726 ---
[2026-02-06 18:10:01.469363] ALERT SENT TO bob@example.com: URGENT: Bob Smith, your attendance is 46.7%. You will fail this class.
[2026-02-06 18:10:01.469424] ALERT SENT TO charlie@example.com: URGENT: Charlie Davis, your attendance is 26.7%. You will fail this class.
LOGEOF

config_fl="${helpers_fd}/config.json"

check_user_input() {
    input_value="$1"
    if [[ "$input_value" =~ ^[0-9]+$ ]] && (( input_value >= 1 && input_value <= 100 )); then
        return 0
    else
        return 1
    fi
}

read -p "Do you want to update the attendance thresholds [Default: Warning (75%) and Failure (50%)] ? (y/n): " usr_decision

while true; do
    if [ "$usr_decision" = "y" ]; then
        read -p "Do you want to update the Warning or Failure thresholds? (w/f): " update_choice
        if [ "$update_choice" = "w" ]; then
            while true; do
                read -p "Enter new Warning threshold (1-100): " new_w_threshold
                if check_user_input $new_w_threshold; then
                    echo "Updating warning threshold to ${new_w_threshold}"
                    sed -i "s/\"warning\": [0-9]*/\"warning\": ${new_w_threshold}/" "$config_fl"
                    break
                else
                    echo "Please enter a valid whole number [1-100]"
                fi
            done
            break
        elif [ "$update_choice" = "f" ]; then
            while true; do
                read -p "Enter new Failure threshold (1-100): " new_f_threshold
                if check_user_input $new_f_threshold; then
                    echo "Updating failure threshold to ${new_f_threshold}"
                    sed -i "s/\"failure\": [0-9]*/\"failure\": ${new_f_threshold}/" "$config_fl"
                    break
                else
                    echo "Please enter a valid whole number [1-100]"
                fi
            done
            break
        else
            echo "Choose between Warning (w) or Failure (f) threshold"
        fi
    else
        break
    fi
done

echo ""
echo "Running environment health check..."

py_version=$(python3 --version 2>&1)
if echo "$py_version" | grep -q "^Python"; then
    echo "  [OK] $py_version is available"
else
    echo "  [WARNING] python3 is missing or unavailable"
fi

echo ""
echo "Verifying project structure..."

all_ok=true
for filepath in \
    "${target_fd}/attendance_checker.py" \
    "${helpers_fd}/assets.csv" \
    "${helpers_fd}/config.json" \
    "${reports_fd}/reports.log"
do
    if [ -f "$filepath" ]; then
        echo "  [OK] $filepath"
    else
        echo "  [MISSING] $filepath"
        all_ok=false
    fi
done

if $all_ok; then
    echo "  All files are present."
else
    echo "  [WARNING] Some files are missing."
fi

echo ""

echo " [DONE] Workspace created!"
echo ""
