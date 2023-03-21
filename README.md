# NixOS for VisionFive 2

This flake hosts my take on running NixOS on the VisionFive 2.

## Building & Running

A basic SD-card image can be created by building the `sd` package:
```shell
nix build github:Snektron/nixos-vf2#sd
```
The resulting image can be flashed to an SD card using `dd`, after decompressing:
```shell
zstd -d result/std-image/nixos-sd-image-*.img.zst -o sdcard.img
sudo dd if=sdcard.img of=/dev/your-disk bs=1M oflag=sync status=progress
```

### Booting

The SD card image also contains a patched-up bootloader version. This means that the image is bootable on a new VisionFive 2 board *without* having to flash a newer bootloader version. To boot using this included bootloader the VisionFive 2 must be configured to boot from SDIO3.0, which can be done by setting the `GPIO_0` switch to high (1), and the `GPIO_1` switch to low (0). See also the [VF2 quick start guide, 4.6. Boot Mode Settings](https://doc-en.rvspace.org/VisionFive2/PDF/VisionFive2_QSG.pdf).

Note: sometimes when pressing the reset switch, the only thing that shows up is

> BOOT fail,Error is 0xffffffff

In this case, just keep pressing the reset switch until it works.

## Flake features
- `packages.${system}.kernel` is a Linux kernel version that works on the VisionFive 2. Currently used is [esmil/linux/jh7110](https://github.com/esmil/linux/tree/jh7110).
- `packages.${system}.splTool` is StarFive's  [spl_tool](https://github.com/starfive-tech/Tools/tree/master/spl_tool), required for building firmware.
- `packages.${system}.uboot` is a [patched u-boot](https://github.com/Snektron/u-boot-vf2) that properly works with NixOS. This version properly fixes up the memory and ethernet device tree nodes, cleans up the initialization script, and enables booting from sd, mmc, and nvme.
- `packages.${system}.opensbi` is upstream OpenSBI configured to compile with the custom u-boot.
- `packages.${system}.firmware` creates `u-boot-spl.bin` and `visionfive2_fw_payload.img` from above u-boot and OpenSBI versions. These can also be flashed to the VisionFive 2's flash like the regular images, as described in the [VF2 quick start guide, 4.3. Updating SPL and U-Boot](https://doc-en.rvspace.org/VisionFive2/PDF/VisionFive2_QSG.pdf).
- `packages.${system}.sd` is an alias that builds `nixosConfiguration.sd`.
- `nixosConfigurations.sd` is a basic bootable SD-card image. It starts sshd and sgetty on boot. Default credentials are `root` with password `secret`.
- `nixosModules.sdImage` is an implementation of `sd-card.nix` tweaked for booting the VisionFive 2. Besides the root filesystem, it contains a boot partition, OpenSBI and u-boot.
- `devShells.${system}.default` is a dev shell with picocom.
