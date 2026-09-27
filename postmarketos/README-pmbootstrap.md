# A04e postmarketOS build

This port is built with pmbootstrap and pmaports rather than a plain Alpine APKBUILD environment. The Samsung Android 4.19.191 kernel is retained as the initial hardware compatibility layer. DEVTMPFS and DEVTMPFS_MOUNT are required for early userspace. Halium/libhybris integration is planned for Android-derived hardware such as graphics, audio, modem and camera where native Linux drivers are unavailable.
