# Xiaomi imilab A1 Camera - Telnet Enable Guide

This guide shows how to enable telnet access on the Xiaomi imilab A1 camera (cmsxj19e) when the original SD card exploit fails due to RSA signature verification issues.

## Prerequisites

- Xiaomi imilab A1 camera (cmsxj19e) (any firmware version since the flash chip contents will be modified during the process)
- USB-to-UART adapter (PL2303, CH340, or FT232)
- SD card (FAT32 formatted)
- Linux system with required tools

## Required Tools

```bash
# Install required packages
sudo apt-get install squashfs-tools flashrom
```

## Method Overview

This method modifies the camera's rootfs to permanently enable telnet access by:
1. Extracting the current rootfs from flash
2. Adding telnet binary and startup script
3. Repacking and flashing the modified rootfs

## Step-by-Step Instructions

### Step 1. Downgrade the firmware (if you are on the latest firmware)

For some reason, IMILAB decided to permanently disable serial access in U-Boot in the latest 4.x firmware (the latest firmware is 4.1.6_0211).

To downgrade the firmware, first download the 3.x firmware from the following link (it is in a issue of this repo):

https://github.com/cstrassburg/cmsxj19e-hacks/files/9386855/dump.with_log.zip

Make sure to **disassemble the camera** to access the flash chip before proceeding for the following steps.

Then, extract the firmware image and use the following command to downgrade the firmware to get a version of U-Boot that allows serial access:
```bash
# Connect the SPI flash using a CH341A programmer and make sure it's set to SPI programmer mode
# Open the terminal and run the following command:
# Backup the original firmware
flashrom -p ch341a_spi -c "MX25L1606E" -r /path/to/original_firmware.bin -v
# Flash the 3.x firmware
flashrom -p ch341a_spi -c "MX25L1606E" -w /path/to/flash_dump_16MiB.bin -v
```

### Step 2: Access U-Boot Console

1. **Disassemble the camera** (if you haven't already) to access the serial pins near the flash chip
2. **Connect USB-to-UART adapter**:
   - GND → GND
   - TX → RX (camera)
   - RX → TX (camera)
3. **Open terminal software** (PuTTY, minicom, screen) at 115200 baud
4. **Interrupt boot process**:
   - Power off camera
   - Hold ENTER key
   - Power on camera
   - You should see: `SigmaStar #`

### Step 3: Extract Current RootFS

```bash
# Extract ROOTFS from downloaded flash dump
dd if=flash_dump_16MiB.dump of=ROOTFS.bin bs=1 count=7733248 skip=2424832

# Extract the squashfs
unsquashfs ROOTFS.bin
```

### Step 4: Modify the RootFS

1. **Copy telnet binary**:
```bash
cp sdcard/bin/telnetd-static squashfs-root/bin/telnetd
chmod +x squashfs-root/bin/telnetd
```

2. **Create telnet startup script**:
```bash
cat > squashfs-root/etc/init.d/S99telnet << 'EOF'
#!/bin/sh

# Start telnet daemon
echo "Starting telnet daemon..."
/bin/telnetd &

exit 0
EOF

chmod +x squashfs-root/etc/init.d/S99telnet
```

### Step 5: Repack RootFS

```bash
# Create new rootfs image
mksquashfs squashfs-root/ NEW_ROOTFS.bin -noappend -comp xz

# Extend to correct size (7733248 bytes)
dd if=/dev/zero of=./NEW_ROOTFS.bin bs=1 count=$(( 7733248 - $(stat -c%s ./NEW_ROOTFS.bin) )) seek=$(stat -c%s ./NEW_ROOTFS.bin)
```

### Step 6: Flash Modified RootFS

1. **Copy NEW_ROOTFS.bin to SD card**
2. **Insert SD card into camera**
3. **In U-Boot console**:
```bash
SigmaStar # fatload mmc 0 0x030000000 NEW_ROOTFS.bin
SigmaStar # sf probe
SigmaStar # sf erase 0x250000 0x760000
SigmaStar # sf write 0x030000000 0x250000 0x760000
SigmaStar # reset
```

### Step 7: Test Telnet Access

After the camera boots, connect via telnet:
```bash
telnet <camera_ip> 23
```

Login credentials:
- Username: `root`
- Password: (none, just press Enter)

## Verification

Once connected, you should see:
```bash
mijia_camera login: root
# ls
# uname -a
Linux mijia_camera 4.9.84 #3 PREEMPT Wed Sep 23 20:39:16 CST 2020 armv7l GNU/Linux
# 
```

## Troubleshooting

### RSA Signature Error
If you get "RSA operation error" with the original SD card exploit, this method bypasses that entirely by modifying the rootfs directly.

### Boot Issues
If the camera doesn't boot after flashing:
1. Go back to U-Boot console
2. Flash the original rootfs back
3. Check the modifications and try again

### Telnet Not Starting
You should see logs from the telnet daemon in the serial terminal logs (like `Starting telnet daemon...`), if not something went wrong during patching.

## Security Notes

- This method enables telnet without password protection
- The root user has no password set
- Consider adding a password or using SSH for production use
- This modification is permanent until you flash a different rootfs