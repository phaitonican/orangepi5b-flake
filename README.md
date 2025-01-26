
## Flashing device (eMMC)

To flash the device you will need rkdeveloptool: https://github.com/rockchip-linux/rkdeveloptool

With power off and the USB-C on the CM3588 NAS connected to your Mac/PC, hold the [mask button](https://www.friendlyelec.com/image/catalog/description/CM3588_en_05.jpg) and connect power to the device.

Verify that the device appears in maskrom mode:

```shell
$ rkdeveloptool ld
DevNo=1	Vid=0x2207,Pid=0x350b,LocationID=802	Maskrom
```

Build the RK3588 loader:

```shell
git clone https://github.com/rockchip-linux/rkbin --depth 1
(cd rkbin; ./tools/boot_merger RKBOOT/RK3588MINIALL.ini)
```

Push the loader to the device:

```shell
$ rkdeveloptool db rkbin/rk3588_spl_loader_v1.16.113.bin
$ rkdeveloptool ul rkbin/rk3588_spl_loader_v1.16.113.bin
```

Flash the image to the device:

```shell
$ rkdeveloptool wl 0 core-image-full-cmdline-nanopc-nas.rootfs.wic
```

Reboot device:

```shell
$ rkdeveloptool rd
```
