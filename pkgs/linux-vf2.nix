{ lib , fetchFromGitHub , buildLinux, fetchpatch, ... } @ args:
let
  modDirVersion = "6.5.0-rc1";
in
buildLinux (args // {
  inherit modDirVersion;
  version = "${modDirVersion}-vf2";

  src = fetchFromGitHub {
    owner = "starfive-tech";
    repo = "linux";
    rev = "67e8df01b875afd312a7d2ab77f56a62f39dd6d9";
    hash = "sha256-H+INnZTrfeCLmxPYbQEu3658/e5/Wz/Y5Ann2+lU6WQ=";
  };

  structuredExtraConfig = with lib.kernel; {
    # According to starfive-tech/linux readme
    ARCH_STARFIVE = yes;
    SOC_STARFIVE = yes;
    SERIAL_8250_DW = yes;
    PINCTL_STARFIVE_JH7110_SYS = yes;
    MMC_DW_STARFIVE = yes;
    DWMAC_STARFIVE = yes;
  };

  extraMeta = {
    branch = "JH7110_VisionFive2_upstream";
    description = "Linux kernel for StarFive's VisionFive2";
    platforms = [ "riscv64-linux" ];
  };
} // (args.argsOverride or { }))
