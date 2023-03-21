{ lib , fetchFromGitHub , buildLinux, fetchpatch, ... } @ args:
let
  modDirVersion = "6.2.0";
in
buildLinux (args // {
  inherit modDirVersion;
  version = "${modDirVersion}-vf2";

  src = fetchFromGitHub {
    owner = "esmil";
    repo = "linux";
    rev = "f3df0dfa0962172885dda035fbc579c418b78519";
    sha256 = "sha256-mfI8RB/T0r/PkEH1eJTZ4ta0GRu7vbU6sd0DqhVJtfQ=";
  };

  structuredExtraConfig = with lib.kernel; {
    SOC_STARFIVE = yes;
    SOC_STARFIVE_JH7110 = yes;
    CLK_STARFIVE_JH7110_SYS = yes;
    RESET_STARFIVE_JH7110 = yes;
    PINCTRL_STARFIVE_JH7110 = yes;
    SERIAL_8250_DW = yes;

    # (apparently) doesn't work as module
    SPI_PL022 = yes;
    SPI_PL022_STARFIVE = yes;
    RTC_DRV_STARFIVE = yes;
  };

  extraMeta = {
    branch = "jh7110";
    description = "Linux kernel for StarFive's VisionFive2";
    platforms = [ "riscv64-linux" ];
  };
} // (args.argsOverride or { }))
