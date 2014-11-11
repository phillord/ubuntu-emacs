#! /usr/bin/env bash

# Author: Damien Cassou
#
# This is the script I use to build Emacs packages for Ubuntu. These
# packages are uploaded to
# https://launchpad.net/~cassou/+archive/emacs/. Each package is
# either build from a Debian package or from
# http://emacs.naquadah.org/.

set -e

MAIN_VERSION=20140101
SUB_VERSION=1

PATCH_FUNCTION=noPatch

function noPatch() {
    echo nothing to do
}

function patchForOldDistribution() {
    # Change compression from xz to bzip2
    sed --in-place 's/\(dh_builddeb .* \)-Z xz/\1-Z bzip2/' rules

    # Lower dependency requirements for older ubuntu distributions
    sed --in-place 's/\(dpkg.* \)(>= 1.15.6)/\1(>= 1.15.5)/' control
    sed --in-place 's/\(dpkg.* \)(>= 1.15.6)/\1(>= 1.15.5)/' control.in
    sed --in-place 's/debhelper (>= .*)/debhelper (>= 5.0.0)/' control
    sed --in-place 's/debhelper (>= .*)/debhelper (>= 5.0.0)/' control.in
    sed --in-place 's/Standards-Version: .*/Standards-Version: 3.9.1/' control
    sed --in-place 's/Standards-Version: .*/Standards-Version: 3.9.1/' control.in
    echo 7 > compat
}

function patchForEmacsRelease() {
    # Replace use of backquote '`' by $(shell ...)
    sed --in-place 's/`\([^`]\+\)`/$(shell \1)/g' rules

    # - Add missing LDFLAGS=$(LDFLAGS)
    # - Add the final "cat config.log" so that all log is sent to stdout
    sed --in-place 'sXCFLAGS="$(CFLAGS)" CPPFLAGS="$(CPPFLAGS)" ./configure \(.*\)$XCFLAGS="$(CFLAGS)" CPPFLAGS="$(CPPFLAGS)" LDFLAGS="$(LDFLAGS)" ./configure \1 || cat config.logX' rules

    # Insert missing override_dh_auto_test (I don't know why tests are not working)
    sed --in-place 's/^override_dh_auto_configure: debian/override_dh_auto_test:\n\ttrue\n\noverride_dh_auto_configure: debian/' rules

    # Don't depend on libtiff4-dev explicitly as there is now libtiff5-dev
    sed --in-place 's/libtiff4-dev | //g' control
    sed --in-place 's/libtiff4-dev | //g' control.in

    # Don't give the full path of the icon
    sed --in-place 'sX^Icon=/usr/share/icons/.*$XIcon=@DEB_FLAVOR@Xg' emacsVER.desktop

}

function packageForDistribution() {
    distrib="$1"
    mkdir build_$distrib
    cp --link *.tar.gz build_$distrib
    cp --link *.tar.bz2 build_$distrib
    cp --link *.tar.xz build_$distrib 2>/dev/null || echo
    cp --link *.dsc build_$distrib
    cd build_$distrib

    dpkg-source -x *.dsc

    cd ${PACKAGE}-${MAIN_VERSION}*

    cd debian
    $PATCH_FUNCTION
    cd ..

    EMAIL=damien.cassou@gmail.com dch --distribution "$distrib" --local "~ppa$SUB_VERSION~$distrib" "Build for $distrib"

    debuild -k0xE2490AB1 -S -sa --changes-option='-DDistribution='${distrib}
    cd ..
    dput ppa:cassou/emacs ${PACKAGE}_${MAIN_VERSION}*.changes
    cd ..
}

function cleanTempDirectory() {
    cd ~/tmp && rm -rf emacs && mkdir emacs && cd emacs
}

function convertFromXz() {
    # Convert from tar.xz to tar.bz2 to support Ubuntu lucid and its dpkg < 1.15.6
    file=${PACKAGE}_${MAIN_VERSION}.orig.tar
    unxz --stdout $file.xz | bzip2 --compress --stdout > $file.bz2
    rm -f $file.xz
}

function prepareBuildFromNaquadahUnstable() {

    cleanTempDirectory

    SERVER=http://emacs.naquadah.org/unstable
    PKG_VERSION=-1
    VERSION=${MAIN_VERSION}${PKG_VERSION}
    PACKAGE=emacs-snapshot

    wget --no-clobber ${SERVER}/${PACKAGE}_${VERSION}.dsc
    wget --no-clobber ${SERVER}/${PACKAGE}_${MAIN_VERSION}.orig.tar.xz
    wget --no-clobber ${SERVER}/${PACKAGE}_${VERSION}.debian.tar.gz
}

function prepareBuildFromNaquadahStable() {

    cleanTempDirectory

    SERVER=http://emacs.naquadah.org/stable
    PKG_VERSION=-1+squeeze
    VERSION=${MAIN_VERSION}${PKG_VERSION}
    PACKAGE=emacs-snapshot

    wget --no-clobber ${SERVER}/${PACKAGE}_${VERSION}.dsc
    wget --no-clobber ${SERVER}/${PACKAGE}_${MAIN_VERSION}.orig.tar.xz
    wget --no-clobber ${SERVER}/${PACKAGE}_${VERSION}.debian.tar.gz

    convertFromXz
}

function prepareBuildFromDebianRelease() {

    cleanTempDirectory

    SERVER=http://ftp.fr.debian.org/debian/pool/main/e/emacs24
    MAIN_VERSION=24.3+1
    PKG_VERSION=-2
    VERSION=${MAIN_VERSION}${PKG_VERSION}
    PACKAGE=emacs24

    wget --no-clobber ${SERVER}/${PACKAGE}_${VERSION}.dsc
    wget --no-clobber ${SERVER}/${PACKAGE}_${MAIN_VERSION}.orig.tar.bz2
    wget --no-clobber ${SERVER}/${PACKAGE}_${VERSION}.debian.tar.gz

    PATCH_FUNCTION=patchForEmacsRelease
}

function prepareBuildFromDebianNondfsgRelease() {

    cleanTempDirectory

    SERVER=http://cdn.debian.net/debian/pool/non-free/e/emacs24-non-dfsg/
    MAIN_VERSION=24.3+1
    PKG_VERSION=-1
    VERSION=${MAIN_VERSION}${PKG_VERSION}
    PACKAGE=emacs24-non-dfsg

    wget --no-clobber ${SERVER}/${PACKAGE}_${VERSION}.dsc
    wget --no-clobber ${SERVER}/${PACKAGE}_${MAIN_VERSION}.orig.tar.bz2
    wget --no-clobber ${SERVER}/${PACKAGE}_${VERSION}.debian.tar.gz
}

function prepareBuildFromOld() {

    cleanTempDirectory

    SERVER=https://launchpad.net/~cassou/+archive/emacs/+files
    PACKAGE=emacs-snapshot
    MAIN_VERSION=20120823
    PKG_VERSION=-1~ppa~oneiric1
    VERSION=${MAIN_VERSION}${PKG_VERSION}

    wget --no-clobber http://emacs.naquadah.org/stable/emacs-snapshot_20120823.orig.tar.xz
    wget --no-clobber https://launchpad.net/~cassou/+archive/emacs/+files/emacs-snapshot_20120728-fake2-1~ppa~oneiric1.debian.tar.gz

    convertFromXz
}

#prepareBuildFromOld
# prepareBuildFromDebianRelease
# prepareBuildFromDebianNondfsgRelease
# prepareBuildFromNaquadahStable
# prepareBuildFromNaquadahUnstable

packageForDistribution precise # 12.04 LTS
packageForDistribution quantal # 12.10
packageForDistribution saucy   # 13.10
packageForDistribution trusty  # 14.04
