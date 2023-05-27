{ lib , fetchFromGitHub , buildLinux, fetchpatch, ... } @ args:
let
  modDirVersion = "6.4.0-rc3";
in
buildLinux (args // {
  inherit modDirVersion;
  version = "${modDirVersion}-vf2";

  src = fetchFromGitHub {
    owner = "starfive-tech";
    repo = "linux";
    rev = "d2637628afd75af2064e74fd1b81fb4a97a76a92";
    hash = "sha256-39yhOsHP3RP75Mge3Zhktj6+oIwTHQZlOb82jjM2Hbg=";
  };

  structuredExtraConfig = with lib.kernel; {
    ARCH_STARFIVE = yes;
    SOC_STARFIVE = yes;

    SERIAL_8250 = yes;

    NO_HZ_IDLE = yes;
    CPU_FREQ = yes;
    CPUFREQ_DT = yes;
    CPUFREQ_DT_PLATDEV = yes;
    HIBERNATION = yes;

    GPIO_SYSFS = yes;
    POWER_RESET_GPIO_RESET = yes;

    PROC_KCORE = yes;

    PWM = yes;
    PWM_STARFIVE_PTC = yes;

    SIFIVE_CCACHE = yes;

    V4L_PLATFORM_DRIVERS = yes; # TODO: Make module

    PL330_DMA = no;
  };

  extraMeta = {
    branch = "JH7110_VisionFive2_upstream";
    description = "Linux kernel for StarFive's VisionFive2";
    platforms = [ "riscv64-linux" ];
  };
} // (args.argsOverride or { }))
