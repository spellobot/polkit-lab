#!/bin/bash

# Ensure the script is executed with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Please run as root: sudo ./test.sh"
  exit 1
fi

LAB_DIR="$(pwd)/env"
MACHINE_NAME="polkit-lab"

echo "=== 1. Syncing files from repository to Sandbox ==="
cp ./scripts/agora-service.sh "$LAB_DIR/usr/local/bin/"
cp ./configs/agora.service "$LAB_DIR/etc/systemd/system/"
cp ./configs/10-agora-manager.rules "$LAB_DIR/etc/polkit-1/rules.d/00-agora-manager.rules"

chmod +x "$LAB_DIR/usr/local/bin/agora-service.sh"

echo "=== 2. Starting Sandbox Container in Background ==="
machinectl terminate $MACHINE_NAME 2>/dev/null
systemctl reset-failed $MACHINE_NAME.scope 2>/dev/null

systemd-nspawn --machine=$MACHINE_NAME --boot --directory="$LAB_DIR" >/dev/null 2>&1 &

echo "Waiting for container initialization..."
until systemd-run -M $MACHINE_NAME -P -q --collect /usr/bin/systemctl is-system-running 2>&1 | grep -qE "running|degraded"; do
  sleep 1
done

echo "=== 3. Reloading Daemons and Polkit inside Container ==="
systemd-run -M $MACHINE_NAME -P -q --collect /usr/bin/systemctl daemon-reload
systemd-run -M $MACHINE_NAME -P -q --collect /usr/bin/systemctl restart polkit.service
systemd-run -M $MACHINE_NAME -P -q --collect /usr/bin/systemctl restart agora.service

echo "=== 4. Executing Automated Test as 'operator' ==="
# systemd-run -M avoids PTY allocation logs and accurately bubbles up exit codes.
# --uid=operator runs the binary natively under the target UID.
systemd-run -M $MACHINE_NAME -P -q --collect --uid=operator /usr/bin/systemctl restart agora.service
TEST_RESULT=$?

echo "=== 5. Cleaning Up and Shutting Down Sandbox ==="
machinectl terminate $MACHINE_NAME 2>/dev/null

# Evaluate policy outcome based on the true command exit status
if [ $TEST_RESULT -eq 0 ]; then
  echo -e "\n🟢 SUCCESS: Polkit allowed 'operator' to restart the service without password!"
else
  echo -e "\n🔴 FAILURE: Polkit denied the action or an error occurred."
  exit 1
fi
