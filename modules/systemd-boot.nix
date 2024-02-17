# https://github.com/misuzu/nixos-vf2/blob/master/systemd-boot.nix
{ config, pkgs, ... }: {
  boot.loader.systemd-boot.extraInstallCommands = ''
    set -euo pipefail
    ${pkgs.coreutils}/bin/cp --no-preserve=mode -r ${config.hardware.deviceTree.package} ${config.boot.loader.efi.efiSysMountPoint}/
    for filename in ${config.boot.loader.efi.efiSysMountPoint}/loader/entries/nixos*-generation-[1-9]*.conf; do
      if ! ${pkgs.gnugrep}/bin/grep -q 'devicetree' $filename; then
        ${pkgs.coreutils}/bin/echo "devicetree /dtbs/${config.hardware.deviceTree.name}" >> $filename
      fi
    done
  '';
}
