#!/bin/bash

# Ensure the script is executed with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Please run as root: sudo ./setup.sh"
  exit 1
fi

LAB_DIR="$(pwd)/env"
MACHINE_NAME="polkit-lab"

echo "=== 1. Creating and Initializing Sandbox Directory ==="
if [ -d "$LAB_DIR" ]; then
  echo "⚠️  Warning: $LAB_DIR already exists. Cleaning up old state..."
  machinectl terminate $MACHINE_NAME 2>/dev/null
  systemctl reset-failed $MACHINE_NAME.scope 2>/dev/null

  umount -l "$LAB_DIR/proc" 2>/dev/null
  umount -l "$LAB_DIR/sys" 2>/dev/null
  umount -l "$LAB_DIR/dev" 2>/dev/null

  rm -rf "$LAB_DIR"
fi
mkdir -p "$LAB_DIR"

echo "=== 2. Detecting Host OS and Installing Dependencies ==="
if [ -f /etc/arch-release ]; then
  echo "Distro detected: Arch Linux"
  pacman -S arch-install-scripts systemd-container --needed --noconfirm
  BOOTSTRAP_CMD="pacstrap -K $LAB_DIR base systemd polkit nano --noconfirm"

elif [ -f /etc/debian_version ]; then
  echo "Distro detected: Ubuntu / Debian"
  apt-get update
  apt-get install -y debootstrap systemd-container polkitd nano
  SUITE=$(lsb_release -cs 2>/dev/null || echo "stable")
  BOOTSTRAP_CMD="debootstrap --include=polkitd,systemd,nano $SUITE $LAB_DIR"

elif [ -f /etc/fedora-release ] || [ -f /etc/redhat-release ]; then
  echo "Distro detected: Fedora / RHEL"
  dnf install -y systemd-container polkit nano dnf-plugins-core
  mkdir -p "$LAB_DIR/var/lib/dnf"
  BOOTSTRAP_CMD="dnf --installroot=$LAB_DIR --releasever=$(rpm -E %fedora) groupinstall -y 'Minimal Install' && dnf --installroot=$LAB_DIR install -y polkit nano"
else
  echo "❌ Error: Unsupported host distribution."
  exit 1
fi

echo "=== 3. Bootstraping Minimal Linux Rootfs ==="
eval $BOOTSTRAP_CMD

# Fix for Debian/Ubuntu/Fedora environments to ensure modern systemd layout
mkdir -p "$LAB_DIR/etc/polkit-1/rules.d"
mkdir -p "$LAB_DIR/usr/local/bin"
mkdir -p "$LAB_DIR/etc/systemd/system"

echo "=== 4. Configuring Users and Groups Inside Sandbox ==="
if ! chroot "$LAB_DIR" getent group agora-operators >/dev/null 2>&1; then
  chroot "$LAB_DIR" groupadd agora-operators
fi

if chroot "$LAB_DIR" getent passwd operator >/dev/null 2>&1; then
  echo "User 'operator' already exists. Ensuring correct group and shell..."
  chroot "$LAB_DIR" usermod -g agora-operators -s /bin/bash operator
else
  chroot "$LAB_DIR" useradd -m -g agora-operators -s /bin/bash operator
fi

echo "=== 5. Setting Passwords (Non-interactive fallback) ==="
# Define passwords padrão de forma direta para evitar desfasamento do tty do chroot
echo "root:root" | chroot "$LAB_DIR" chpasswd
echo "operator:123" | chroot "$LAB_DIR" chpasswd

echo -e "\n🟢 Setup complete! Your isolated environment is ready."
echo "To boot the container, run:"
echo "sudo systemd-nspawn --machine=$MACHINE_NAME -bD ./env"
