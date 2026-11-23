# NixOS on the Orange Pi 5B (RK3588S)

Two NixOS image variants for the Orange Pi 5B. Both are cross-compiled on an
`x86_64-linux` machine, so you do not need emulation or a second build machine.

## Images

| Output | Build | Contents |
| --- | --- | --- |
| **server** | `nix build .#server` | Minimal headless server: no Mesa/GPU, no GPU/NPU/media modules, no `rkmon`; WiFi/BT stack + full `linux-firmware` included |
| **full** | `nix build .#full` | Everything: HDMI + Mali-G610 (Panthor), 3-core NPU (Rocket/Teflon), VPU/AV1 decode, RGA, full `linux-firmware`, `rkmon` |

`nix build` and `nix build .#opi5b` still build the full image for backwards
compatibility. `nix build .#` is the same.

Both images share the same board configuration. The difference is only the
profile module:

- `hosts/orangepi5b/server.nix`
- `hosts/orangepi5b/full.nix`

## Layout

| File | Purpose |
| --- | --- |
| `flake.nix` | Inputs, cross-compilation platforms, both variants, dev shell |
| `hosts/orangepi5b/common.nix` | Shared kernel, boot, storage, users, services, SD-image assembly |
| `hosts/orangepi5b/server.nix` | Minimal server profile |
| `hosts/orangepi5b/full.nix` | GPU/NPU/media profile |
| `hosts/orangepi5b/u-boot.nix` | U-Boot built from upstream, with the 5B defconfig |
| `orangepi-5b-rk3588s_defconfig` | U-Boot config for the 5B (upstream has none) |

## Full image features

The latest mainline kernel has good RK3588S support, so the full profile enables:

- **HDMI output** via `rockchipdrm` + the in-kernel `dw-hdmi-qp` driver,
  with a text console on `tty1` and Mesa/Panthor GPU acceleration.
- **Mali-G610 GPU** via Panthor, using the CSF firmware from the full
  `linux-firmware` package.
- **3-core NPU** via the mainline `rocket` DRM-accel driver. The 5B device
  tree enables all three cores; Mesa's `rocket` Gallium driver and Teflon
  delegate are included. The node is `/dev/accel/accel0`.
- **Video decode / 2D acceleration**: `hantro-vpu` (VPU121 H.264/VP8 and
  the AV1 decoder) and `rockchip-rga` kernel modules are loaded. The 8K
  `rkvdec` block is not described by the current mainline device tree yet.
- **eMMC/SD, gigabit Ethernet, USB-C/PD, RTC, PWM fan/LEDs and the ES8388
  analog audio codec** are described by the mainline device tree.

WiFi/Bluetooth is enabled in **both** images. The BCM43752/AP6275P enumerates
over PCIe on the latest kernel, but `linux-firmware` still does not contain its
firmware, so the vendor files are pinned from
`orangepi-xunlong/firmware`:

- `brcmfmac43752-pcie.bin`
- `brcmfmac43752-pcie.txt`
- `brcmfmac43752-pcie.clm_blob`
- `BCM4362A2.hcd` (Bluetooth)

The rest of the stack is also present:

- `networking.networkmanager.enable` + `wpa_supplicant`
- `hardware.bluetooth.enable` + BlueZ
- `brcmfmac`, `brcmutil`, `bluetooth`, `hci_uart`, `btbcm` and `btusb`
- full `linux-firmware` (Broadcom/Cypress, Mali, etc.)
- the wireless regulatory database

So `nmcli` and `bluetoothctl` are available. After rebuilding, `brcmfmac`
should load the 43752 firmware instead of failing with `-2 (ENOENT)`. If
Bluetooth does not attach, check whether the UART/hci side is described by the
kernel/DT.

Also not supported by mainline yet: H.264/H.265 hardware *encoding*, and the
vendor RKNN-Toolkit2/librknnrt stack, which expects the vendor `rknpu` kernel
driver rather than mainline `rocket`.

After booting the full image, the relevant devices can be checked with:

```shell
ls -l /dev/dri/ /dev/accel/
dmesg | grep -Ei 'rocket|panthor|hdmi'
rkmon        # GPU/NPU/VPU/RGA/thermal monitor
```

`/dev/accel/accel0` is the NPU. The open-source userspace path is Mesa's
`rocket` Gallium driver and its Teflon TensorFlow-Lite delegate. For direct
C/C++ NPU work, the out-of-tree
[`rocket-userspace`](https://github.com/gregordinary/rocket-userspace)
(`librocketnpu`) targets the same mainline `rocket` UAPI.

## Server image

The server profile keeps the common board support (eMMC/SD, gigabit Ethernet,
USB-C/PD, RTC, serial + HDMI text console, SSH, WiFi/Bluetooth software stack,
etc.) but disables:

- Mesa and `hardware.graphics`
- `panthor`, `rocket`, `hantro-vpu` and `rockchip-rga` module loading
- `rkmon` and the `video`/`render`/`audio` group memberships

The common configuration otherwise stays close to a stock NixOS installation:
documentation, default packages, journald limits, swap, Nix GC and the network
stack are left at their NixOS defaults. Only board support (kernel, initramfs,
device tree, firmware and U-Boot) and the `nixos` user are set explicitly.

The full profile overrides `mesa` to build only `panfrost` (GPU) and `rocket`
(NPU), so the full Mesa driver set and software rasterisers are not dragged in
(Mesa still links `libLLVM`). If Panfrost ever fails to probe, add `"llvmpipe"`
to `galliumDrivers` in `hosts/orangepi5b/full.nix` as a fallback.

## Build

```shell
# Minimal server image
nix build .#server --out-link result-server

# Full GPU/NPU image
nix build .#full --out-link result-full

# U-Boot only (u-boot-rockchip.bin, i.e. idbloader + U-Boot FIT)
nix build .#uboot
```

The images are written to:

```text
result-server/sd-image/nixos-image-sd-card-server-*.img
result-full/sd-image/nixos-image-full-sd-card-*.img
```

The first build cross-compiles quite a few packages. Later builds reuse the
Nix store. Formatting and flashing tools are available in the dev shell:

```shell
nix develop
```

## Flash an SD card

```shell
sudo dd if=result-server/sd-image/nixos-image-sd-card-server-*.img \
  of=/dev/sdX bs=4M status=progress conv=fsync
```

Use `result-full/...` instead for the full image. The U-Boot image is already
written into the gap before the first partition by the flake, so you only need
to write the `.img` file.

## Flash the eMMC (maskrom mode)

You need [`rkdeveloptool`](https://github.com/rockchip-linux/rkdeveloptool),
which is included in the dev shell.

1. Power off the board, connect the USB-C port to your PC, hold the maskrom
   button, then apply power.
2. Verify maskrom mode:

   ```shell
   rkdeveloptool ld
   ```

3. Build the RK3588 loader:

   ```shell
   git clone https://github.com/rockchip-linux/rkbin --depth 1
   (cd rkbin; ./tools/boot_merger RKBOOT/RK3588MINIALL.ini)
   ```

4. Upload the loader and write the chosen image:

   ```shell
   rkdeveloptool db rkbin/rk3588_spl_loader_*.bin
   rkdeveloptool ul rkbin/rk3588_spl_loader_*.bin
   rkdeveloptool wl 0 result-full/sd-image/nixos-image-full-sd-card-*.img
   rkdeveloptool rd
   ```

## Login

Both images create one normal user, `nixos`, with the initial password
`nixos` — similar to the NixOS installation media.

- Server image: member of `wheel` and `networkmanager`.
- Full image: member of `wheel`, `networkmanager`, `video`, `render` and
  `audio`.

Change the password with `passwd` after the first login. The username and
initial password are defined once in `flake.nix`:

```nix
username = "nixos";
initialPassword = "nixos";
```

Change them there and rebuild to use your own account. Add an SSH key and set
`services.openssh.settings.PasswordAuthentication = false` in
`hosts/orangepi5b/common.nix` before exposing the board to a network.

Serial console: `ttyS2` at `1500000` baud. HDMI text console is also enabled.

On the board, switch/update with the matching configuration:

```shell
sudo nixos-rebuild switch --flake .#orangepi5b-server
# or
sudo nixos-rebuild switch --flake .#orangepi5b-full
```

## U-Boot

U-Boot is now built from the upstream release pinned in
`hosts/orangepi5b/u-boot.nix` (currently v2026.10), cross-compiled for
`aarch64`. The result is the combined `u-boot-rockchip.bin` image
(idbloader + U-Boot FIT), which is written at sector 64 (32 KiB); this is why
`firmwarePartitionOffset` is 32 MiB. `nix build .#uboot` builds just U-Boot.

Upstream has a device tree for the 5B but no defconfig, so
`orangepi-5b-rk3588s_defconfig` is installed into the source tree before
configuring. It is the upstream Orange Pi 5 defconfig plus:

- `CONFIG_DEFAULT_DEVICE_TREE` / `CONFIG_DEFAULT_FDT_FILE` pointing at
  `rockchip/rk3588s-orangepi-5b`;
- the RK3588 eMMC controller (`CONFIG_MMC_SDHCI*`), which the 5B needs but
  the Orange Pi 5 (SD only) does not;
- no `CONFIG_ROCKCHIP_SPI_IMAGE`, because the 5B has no SPI NOR flash.

The device tree is taken from the kernel source tree mirrored in U-Boot
(`dts/upstream/`); the generic `rk3588s-u-boot.dtsi` is applied automatically
and already includes `&sdhci` in the SPL boot order, so eMMC boot works.

To update U-Boot, change `version` (and `hash`) in
`hosts/orangepi5b/u-boot.nix`; `nix build .#uboot` will report the correct
hash if it is stale. If the new release needs different options, regenerate
the defconfig with `make savedefconfig` in a U-Boot tree and copy the result
over `orangepi-5b-rk3588s_defconfig`.
