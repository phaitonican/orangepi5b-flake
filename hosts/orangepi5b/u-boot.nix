# U-Boot for the Orange Pi 5B, cross-compiled from an upstream release.
#
# Upstream has a device tree for the 5B, but no defconfig, so u-boot/defconfig
# is installed into the source tree before configuring. It is the upstream
# Orange Pi 5 defconfig with the RK3588 eMMC controller enabled and the 5B
# device tree selected.
{
  fetchFromGitHub,
  pkgsCross,
  version ? "2026.10",
  hash ? "sha256-BXIpyAY+uKSohrdG4BxAo0zq4CYmh2z9rFw1jA7Yu8s=",
}:

let
  # nixpkgs' Orange Pi 5 package already knows how to build Rockchip U-Boot:
  # it supplies the RK3588 BL31 (ATF) and DDR TPL blobs that binman needs for
  # the combined u-boot-rockchip.bin image.
  base = pkgsCross.ubootOrangePi5.override {
    inherit version;

    src = fetchFromGitHub {
      owner = "u-boot";
      repo = "u-boot";
      tag = "v${version}";
      inherit hash;
    };

    defconfig = "orangepi-5b-rk3588s_defconfig";

    # The 5B has no SPI NOR flash, so ROCKCHIP_SPI_IMAGE is disabled in the
    # defconfig and u-boot-rockchip-spi.bin is not produced.
    filesToInstall = [
      "u-boot.itb"
      "idbloader.img"
      "u-boot-rockchip.bin"
    ];
  };
in
base.overrideAttrs (old: {
  pname = "uboot-orangepi-5b-rk3588s";

  # Keep nixpkgs' patch/setup steps (patchShebangs, the dtc workaround, ...)
  # and add our defconfig to the source tree.
  postPatch = ''
    ${old.postPatch or ""}
    install -Dm644 ${./u-boot/defconfig} configs/orangepi-5b-rk3588s_defconfig
  '';

  meta = (old.meta or { }) // {
    description = "U-Boot for the Orange Pi 5B (RK3588S)";
  };
})
