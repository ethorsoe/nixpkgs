{ lib, fetchFromGitHub, libkdumpfile, python3Packages, gdb, stdenv, python3, writeScriptBin, flex, bison }:

stdenv.mkDerivation rec {
  name = "crash-python";

  src = fetchFromGitHub {
    owner = "crash-python";
    repo = "crash-python";
    rev = "50a19e63632d82f207d8880be1b209da4d78fc7f";
    sha256 = "sha256-+XoNQf0ywf7KiYfJCIwpvIL4uF2koTXJWrBqDkFZkSA=";
  };

  propagatedBuildInputs = with python3Packages; [
    pyelftools libkdumpfile
  ];
  nativeBuildInputs = [ python3Packages.sphinx ];
  #pythonPath = [ libkdumpfile ];

  doCheck = false;
  myGdb = gdb.overrideAttrs (oldAttrs: {
    version = "9.1-crash-python";
    patches = [];
    nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
      flex bison
    ];
    src = fetchFromGitHub {
      owner = "crash-python";
      repo = "gdb-python";
      rev = "395ecfdca4d2c9b4eb7b0fb25c57538fb767095f";
      sha256 = "sha256-suY/mXm2EF3Vv953pwNxvw5608nEOE6LM87ckA/kDOw=";
    };
  });

  postPatch = ''
    patchShebangs
    PYTHONPATH+=":${with python3Packages; makePythonPath [sphinx docutils]}"
    makeFlagsArray+=(GZIPCMD=gzip INSTALL=install datadir=/share DESTDIR=$out)
    sed -i 's/^all: clean build doc test$/all: clean build doc/;s|usr/bin|bin|g' Makefile
    sed -i "s#/usr/share/crash-python#$out/share/crash-python#" crash.sh
    sed -i "s|^ *GDB=.*$|GDB=${myGdb}/bin/gdb|" crash.sh
    echo aa
  '';
  prePatch = ''
    sed -i '3 s|^|export PYTHONPATH=${with python3Packages; makePythonPath [libkdumpfile crash-python]}\n|' crash.sh
    sed -i '3 s|^|export PYTHONDONTWRITEBYTECODE=true\n|' crash.sh
  '';
  meta = with lib; {
    description = "Semantic debugger for the Linux kernel crash dumps.";
    homepage = "https://github.com/crash-python/crash-python";
    license = licenses.gpl2;
    maintainers = with maintainers; [ jkarlson ];
    platforms = platforms.linux;
  };
}
