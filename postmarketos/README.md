# postmarketOS on Samsung Galaxy A04e

This directory contains the initial postmarketOS port material for the Samsung Galaxy A04e (SM-A042F).

## Hardware base

- SoC: MediaTek MT6765
- Architecture: ARM64 / aarch64
- Downstream kernel: Samsung Linux 4.19.191
- Kernel source: `TEMMC/android_kernel_a042f`
- Kernel defconfig: `a04e_defconfig`
- Display: 720x1600

## Packages

- `device/testing/device-samsung-a04e` — postmarketOS device metadata
- `device/testing/linux-samsung-a04e` — downstream Samsung kernel package

## Bring-up strategy

The first stage intentionally keeps the existing Samsung/MediaTek kernel hardware drivers and uses postmarketOS as the Linux userspace. Graphics are initially treated as non-DRM until the actual framebuffer/DRM path is verified on-device.

Halium/libhybris is reserved for hardware components that cannot be used directly from the Linux userspace; it is not assumed to work until the A04e Android HAL interfaces are tested.

## Flashing

`deviceinfo_flash_method` is deliberately set to `none` at this stage. The A04e PIT/Download Mode partition mapping must be verified from the actual device before any automated flashing method is enabled.

Do not enable automatic flashing until the exact BOOT partition and boot image format have been confirmed.

## First milestone

1. Build the downstream kernel through pmbootstrap.
2. Generate a postmarketOS initramfs.
3. Produce a boot image without touching the phone.
4. Boot/test the image through the Samsung boot path.
5. Bring up display and touchscreen.
6. Continue with Wi-Fi/Bluetooth, audio, modem, sensors and GPU.
