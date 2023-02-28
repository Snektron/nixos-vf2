{ lib, stdenv, fetchFromGitHub }:
stdenv.mkDerivation rec {
  pname = "splTool";
  version = "1.0";

  src = fetchFromGitHub {
    owner = "starfive-tech";
    repo = "Tools";
    rev = "8c5acc4e5eb7e4ad012463b05a5e3dbbfed1c38d";
    sha256 = "sha256-Kf9+68lsctVcG765Tv9R6g1Px8RCHUKzbIg23+o9E3g=";
  };

  installPhase = ''
    mkdir -p "$out/bin/"
    cp spl_tool "$out/bin/"
  '';

  sourceRoot = "${src.name}/spl_tool";
}
