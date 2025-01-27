## Precompiled u-boot

This provided a precompiled U-boot from master branch aprox. v2025.01 release. Trying to get the custom defconfig pushed to U-boot, to then add it as a nixpkg, so this gets updated regularly.

## Flashing device (eMMC)

To flash the device you will need rkdeveloptool: https://github.com/rockchip-linux/rkdeveloptool

With power off and the USB-C on the OrangePi 5b connected to your Linux/Mac/PC, hold the [maskrom button](https://3dpandme.com/wp-content/uploads/2023/04/image-36.png) and connect power to the device.

Verify that the device appears in maskrom mode:

```shell
$ rkdeveloptool ld
DevNo=1	Vid=0x2207,Pid=0x350b,LocationID=301	Maskrom
```

Build the RK3588 loader:

```shell
git clone https://github.com/rockchip-linux/rkbin --depth 1
(cd rkbin; ./tools/boot_merger RKBOOT/RK3588MINIALL.ini)
```

Push the loader to the device:

```shell
$ rkdeveloptool db rkbin/rk3588_spl_loader_v1.18.113.bin
$ rkdeveloptool ul rkbin/rk3588_spl_loader_v1.18.113.bin
```

Flash the image to the device:

```shell
$ rkdeveloptool wl 0 result/sd-image/nixos-image-sd-card-25.05.20250124.825479c-aarch64-linux.img
```

Reboot device:

```shell
$ rkdeveloptool rd
```
