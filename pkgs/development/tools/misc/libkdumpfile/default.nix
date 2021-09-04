{ lib, fetchFromGitHub, stdenv, autoreconfHook, pkg-config, zlib, lzop, snappy, python3, ncurses }:

stdenv.mkDerivation rec {
  pname = "libkdumpfile";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "ptesarik";
    repo = "libkdumpfile";
    rev = "v${version}";
    sha256 = "sha256-RPw3JRZrYNrWHIm/qFqAH576YQ4IYZI43KAdmeoz9+0=";
  };

  nativeBuildInputs = [ autoreconfHook pkg-config];
  buildInputs = [ zlib lzop snappy python3 ncurses ];

  meta = with lib; {
    description = "Library for parsing linux kernel coredumps";
    homepage = "https://github.com/ptesarik/libkdumpfile";
    license = licenses.gpl2;
    maintainers = with maintainers; [ jkarlson ];
    platforms = platforms.linux;
  };
}
