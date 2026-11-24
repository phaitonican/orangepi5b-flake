# NixOS on the Orange Pi 5B (RK3588S)

Two NixOS SD-card images for the Orange Pi 5B. Both are cross-compiled on an
`x86_64-linux` machine, so no emulation or second build machine is needed.
The `nixosConfigurations` used on the board itself stay native
(`aarch64-linux`), so `nixos-rebuild switch` there does not need x86_64 build
tools.

## Quick start

```shell
# Minimal headless server
nix build .#server --out-link result-server

# Full GPU/NPU/media image
nix build .#full --out-link result-full
```

Flash the resulting image (replace `/dev/sdX` with your card):

```shell
sudo dd if=result-server/sd-image/nixos-image-sd-card-server-*.img \
  of=/dev/sdX bs=4M status=progress conv=fsync
```

To install to the eMMC instead, use maskrom mode as described in
[Flash the eMMC (maskrom mode)](#flash-the-emmc-maskrom-mode).

Boot the board, log in as `nixos` with password `nixos`, and run `passwd`.
See [Build](#build), [Flash an SD card](#flash-an-sd-card) and
[First boot](#first-boot) for details.

## Images

| Output | Build | Description |
| --- | --- | --- |
| **server** | `nix build .#server` | Minimal headless server: no Mesa/GPU, no GPU/NPU/media modules, no `rkmon`; Wi-Fi/Bluetooth stack and full `linux-firmware` included |
| **full** | `nix build .#full` | Everything: HDMI + Mali-G610 (Panthor), 3-core NPU (Rocket/Teflon), VPU/AV1 decode, RGA, full `linux-firmware`, `rkmon` |

Both images share the board configuration in
`hosts/orangepi5b/common.nix`. Only the profile module differs:

- `hosts/orangepi5b/server.nix`
- `hosts/orangepi5b/full.nix`

## Features

### Board support (both images)

- Latest mainline kernel and the `rk3588s-orangepi-5b` device tree.
- eMMC/SD, gigabit Ethernet, USB-C/PD, RTC, PWM fan/LEDs and the ES8388
  analog audio codec.
- Serial console on `ttyS2` at `1500000` baud, plus an HDMI text console.
- SSH and NetworkManager.

### Wi-Fi and Bluetooth (both images)

The BCM43752/AP6275P enumerates over PCIe on the latest kernel, but the
upstream device tree does not describe it yet. The patch in
`hosts/orangepi5b/patches/` adds:

- the Wi-Fi node on PCIe;
- the Bluetooth node on UART9 with hardware flow control.

It is applied via `boot.kernelPatches`, so the kernel's DTB includes both
nodes.

`linux-firmware` does not ship the module's firmware yet, so the vendor files
are pinned from `orangepi-xunlong/firmware`:

- `brcmfmac43752-pcie.bin`
- `brcmfmac43752-pcie.txt`
- `brcmfmac43752-pcie.clm_blob`
- `BCM4362A2.hcd` (Bluetooth)

The rest of the stack is enabled as well:

- `networking.networkmanager.enable` + `wpa_supplicant`
- `hardware.bluetooth.enable` + BlueZ
- the `brcmfmac`, `brcmutil`, `bluetooth`, `hci_uart`, `btbcm` and `btusb`
  modules
- full `linux-firmware` (Broadcom/Cypress, Mali, etc.)
- the wireless regulatory database
- Wi-Fi power save disabled (`wifi.powersave = false`), since brcmfmac's power
  save drops frames and stalls TCP sessions (see
  [SSH hangs or freezes over Wi-Fi](#ssh-hangs-or-freezes-over-wi-fi))

`nmcli` and `bluetoothctl` are therefore available. After rebuilding,
`brcmfmac` should load the 43752 firmware instead of failing with `-2
(ENOENT)`. If Bluetooth does not attach, check whether the UART/hci side is
described by the kernel/DT.

### Full image

- **HDMI output** via `rockchipdrm` and the in-kernel `dw-hdmi-qp` driver,
  with a text console on `tty1` and Mesa/Panthor GPU acceleration.
- **Mali-G610 GPU** via Panthor, using the CSF firmware from the full
  `linux-firmware` package.
- **3-core NPU** via the mainline `rocket` DRM-accel driver. The 5B device
  tree enables all three cores; Mesa's `rocket` Gallium driver and Teflon
  delegate are included. The node is `/dev/accel/accel0`.
- **Video decode / 2D acceleration**: the `hantro-vpu` (VPU121 H.264/VP8 and
  the AV1 decoder) and `rockchip-rga` kernel modules are loaded. The 8K
  `rkvdec` block is not described by the current mainline device tree yet.
- **`rkmon`**, a GPU/NPU/VPU/RGA/thermal monitor for RK3588.

The full profile overrides Mesa to build only `panfrost` (GPU) and `rocket`
(NPU), so the full Mesa driver set and software rasterisers are not dragged
in (Mesa still links `libLLVM`). If Panfrost ever fails to probe, add
`"llvmpipe"` to `galliumDrivers` in `hosts/orangepi5b/full.nix` as a fallback.

After booting the full image, check the devices with:

```shell
ls -l /dev/dri/ /dev/accel/
dmesg | grep -Ei 'rocket|panthor|hdmi'
rkmon
```

For direct C/C++ NPU work, the out-of-tree
[`rocket-userspace`](https://github.com/gregordinary/rocket-userspace)
(`librocketnpu`) targets the same mainline `rocket` UAPI.

### Server image

The server profile keeps the common board support (eMMC/SD, gigabit Ethernet,
USB-C/PD, RTC, serial + HDMI text console, SSH, Wi-Fi/Bluetooth stack, etc.)
but disables:

- Mesa and `hardware.graphics`;
- `panthor`, `rocket`, `hantro-vpu` and `rockchip-rga` module loading;
- `rkmon` and the `video`/`render`/`audio` group memberships.

Otherwise the configuration stays close to a stock NixOS installation:
documentation, default packages, journald limits, swap and Nix GC are left at
their NixOS defaults. Only board support (kernel, initramfs, device tree,
firmware and U-Boot), the `nixos` user and Wi-Fi power save (see [SSH hangs or
freezes over Wi-Fi](#ssh-hangs-or-freezes-over-wi-fi)) are set explicitly.

### Not supported by mainline yet

- H.264/H.265 hardware *encoding*.
- The vendor RKNN-Toolkit2/librknnrt stack, which expects the vendor `rknpu`
  kernel driver rather than mainline `rocket`.

## Layout

| File | Purpose |
| --- | --- |
| `flake.nix` | Inputs, cross-compilation platforms, both variants, dev shell |
| `hosts/orangepi5b/common.nix` | Shared kernel, boot, storage, users, services, SD-image assembly |
| `hosts/orangepi5b/server.nix` | Minimal server profile |
| `hosts/orangepi5b/full.nix` | GPU/NPU/media profile |
| `hosts/orangepi5b/u-boot.nix` | U-Boot built from upstream, with the 5B defconfig |
| `hosts/orangepi5b/u-boot/defconfig` | U-Boot config for the 5B (upstream has none) |
| `hosts/orangepi5b/patches/` | Kernel patches applied via `boot.kernelPatches` (5B Wi-Fi/Bluetooth DT) |

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

On `x86_64-linux`, `nix build .#server`/`.#full` selects the cross-compiled
image. On the board, the same attributes build the image natively. The first
cross build compiles quite a few packages; later builds reuse the Nix store.
The NixOS configurations themselves are always native, which is what
`nixos-rebuild` uses on the board. Formatting and flashing tools are available
in the dev shell:

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
which is included in the dev shell. Enter the dev shell from the flake root
first, so the commands below are on `PATH`:

```shell
cd /path/to/orangepi5b-flake
nix develop
```

1. Power off the board, connect the USB-C port to your PC, hold the maskrom
   button, then apply power.
2. Verify maskrom mode:

   ```shell
   rkdeveloptool ld
   ```

3. Build the RK3588 loader:

   ```shell
   git clone https://github.com/rockchip-linux/rkbin --depth 1
   cd rkbin
   ./tools/boot_merger RKBOOT/RK3588MINIALL.ini
   cd ..
   ```

4. Upload the loader and write the chosen image:

   ```shell
   sudo rkdeveloptool db rkbin/rk3588_loader_*.bin
   sudo rkdeveloptool ul rkbin/rk3588_loader_*.bin
   sudo rkdeveloptool wl 0 result-full/sd-image/nixos-image-full-sd-card-*.img
   sudo rkdeveloptool rd
   ```

## First boot

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

Serial console: `ttyS2` at `1500000` baud. An HDMI text console is also
enabled.

On the board, switch/update with the matching configuration:

```shell
sudo nixos-rebuild switch --flake .#orangepi5b-server
# or
sudo nixos-rebuild switch --flake .#orangepi5b-full
```

These configurations are built natively for `aarch64-linux`; the x86_64 cross
setup only applies to the SD-card images built from the `packages` output.

## SSH hangs or freezes over Wi-Fi

Symptom: `ssh` to the board hangs at `Connecting to ...` and times out, or an
established session freezes, while `ping`, DNS and other traffic keep
working. Other clients (phones, `nc`, `ping`) connect fine.

The board is a Wi-Fi client, and OpenSSH marks interactive sessions with
DSCP EF by default (`IPQoS ef`). Some routers drop or stall frames in
certain DSCP classes on the way to a Wi-Fi client — this was observed with a
Telekom Speedport router (`*.speedport.ip`), where `cs1`, `af11`, `af21` and
`ef` timed out but `cs0` worked. The marking comes from the SSH client, not
from the board, so any unmodified OpenSSH client on the same network is
affected, while apps that do not set DSCP (e.g. phone SSH clients) are not.

To confirm, compare a connection with and without the marking:

```shell
ssh -o IPQoS=none nixos@orangepi5b uptime   # works
ssh -o IPQoS=ef   nixos@orangepi5b uptime   # hangs
```

Workaround on the client in `~/.ssh/config`. `IPQoS none` avoids the broken
queue; the keepalives make a stalled connection fail after ~45 s instead of
hanging forever:

```text
Host orangepi5b
    IPQoS none
    TCPKeepAlive yes
    ServerAliveInterval 15
    ServerAliveCountMax 3
```

The actual fix is on the router (disable WMM/QoS, or update its firmware) or
on the link (connect the board over Ethernet). The
`networking.networkmanager.wifi.powersave = false` setting in `common.nix`
also helps, because brcmfmac's power save is what makes the Wi-Fi frame loss
visible. After a rebuild, check with `ssh -o IPQoS=ef` whether the
workaround is still needed.

## Grow the root partition

The `.img` is sized to its contents (roughly 5 GiB), not to the SD card or
eMMC. The configuration in `hosts/orangepi5b/common.nix` grows partition 2
and the ext4 filesystem to the full device on boot:

```nix
boot.growPartition = true;
fileSystems."/".autoResize = true;
```

Both steps run on every boot and are no-ops once the partition fills the disk.

Older images used `sdImage.expandOnBoot`, whose one-shot
`expand-root-partition.service` only ran while `/nix-path-registration`
existed. If such an image is still at ~5 GiB after the first boot, grow it
manually from the running system:

```shell
root=$(findmnt -no SOURCE /)
disk=$(lsblk -npo PKNAME "$root")
sudo nix shell nixpkgs#cloud-utils nixpkgs#e2fsprogs -c bash -c \
  'growpart "$1" "${2##*[!0-9]}" || true; resize2fs "$2"' _ "$disk" "$root"
df -h /
```

`growpart` resizes the partition online and `resize2fs` grows the mounted
ext4, so no reboot is needed. Partition 1 (`BOOT`, 16 MiB) is left alone.

## U-Boot

U-Boot is built from the upstream release pinned in
`hosts/orangepi5b/u-boot.nix` (currently v2026.10), cross-compiled for
`aarch64`. The result is the combined `u-boot-rockchip.bin` image
(idbloader + U-Boot FIT), which is written at sector 64 (32 KiB); this is why
`firmwarePartitionOffset` is 32 MiB. `nix build .#uboot` builds just U-Boot.

Upstream has a device tree for the 5B but no defconfig, so
`hosts/orangepi5b/u-boot/defconfig` is installed into the source tree before
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
over `hosts/orangepi5b/u-boot/defconfig`.
