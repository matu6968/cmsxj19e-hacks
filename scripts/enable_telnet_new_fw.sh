#!/bin/bash

# Xiaomi imilab A1 Camera - Telnet Enable Script for firmware 3.5.8_0166 or greater
# This script automates the process of enabling telnet access

set -e

echo "=== Xiaomi imilab A1 Camera - Telnet Enable Script ==="
echo ""

# Check if ROOTFS.bin exists
if [ ! -f "ROOTFS.bin" ]; then
    echo "ERROR: ROOTFS.bin not found!"
    echo "Please extract the rootfs from your camera first."
    echo "You can either:"
    echo "1. Use a flash dump: dd if=flash_dump_16MiB.dump of=ROOTFS.bin bs=1 count=7733248 skip=2424832"
    echo "2. Extract from camera via U-Boot: sf read 0x22000000 0x250000 0x760000"
    exit 1
fi

# Check if telnet binary exists
if [ ! -f "sdcard/bin/telnetd-static" ]; then
    echo "ERROR: telnetd-static not found in sdcard/bin/"
    echo "Please ensure you have the exploit files from this repository."
    exit 1
fi

echo "Step 1: Extracting rootfs..."
if [ -d "squashfs-root" ]; then
    echo "Removing existing squashfs-root directory..."
    rm -rf squashfs-root
fi

# temporairly disable set's exit on error 
# if for example unsquashfs complains about being unable to create the console file because it isn't running as root
set +e
unsquashfs ROOTFS.bin
echo "✓ Rootfs extracted successfully"

# re-enable set's exit on error
set -e

echo ""
echo "Step 2: Adding telnet binary..."
cp sdcard/bin/telnetd-static squashfs-root/bin/telnetd
chmod +x squashfs-root/bin/telnetd
echo "✓ Telnet binary added"

echo ""
echo "Step 3: Creating telnet startup script..."
cat > squashfs-root/etc/init.d/S99telnet << 'EOF'
#!/bin/sh

# Start telnet daemon
echo "Starting telnet daemon..."
/bin/telnetd &

exit 0
EOF

chmod +x squashfs-root/etc/init.d/S99telnet
echo "✓ Telnet startup script created"

echo ""
echo "Step 4: Repacking rootfs..."
mksquashfs squashfs-root/ NEW_ROOTFS.bin -noappend -comp xz

# Extend to correct size
CURRENT_SIZE=$(stat -c%s ./NEW_ROOTFS.bin)
TARGET_SIZE=7733248
PADDING_SIZE=$((TARGET_SIZE - CURRENT_SIZE))

if [ $PADDING_SIZE -gt 0 ]; then
    echo "Extending file to correct size..."
    dd if=/dev/zero of=./NEW_ROOTFS.bin bs=1 count=$PADDING_SIZE seek=$CURRENT_SIZE
fi

echo "✓ Rootfs repacked successfully"
echo "File size: $(stat -c%s ./NEW_ROOTFS.bin) bytes"

echo ""
echo "=== SUCCESS! ==="
echo ""
echo "Next steps:"
echo "1. Copy NEW_ROOTFS.bin to your SD card"
echo "2. Insert SD card into camera"
echo "3. Boot into U-Boot console (hold ENTER during boot)"
echo "4. Run these commands in U-Boot:"
echo ""
echo "   fatload mmc 0 0x030000000 NEW_ROOTFS.bin"
echo "   sf probe"
echo "   sf erase 0x250000 0x760000"
echo "   sf write 0x030000000 0x250000 0x760000"
echo "   reset"
echo ""
echo "5. After reboot, connect via telnet:"
echo "   telnet <camera_ip> 23"
echo "   Login: root (no password)"
echo ""
echo "For detailed instructions, see TELNET_ENABLE_GUIDE.md" 