#! /usr/bin/env bash

# Author: Damien Cassou
# Author: Phillip Lord
#
# This script is derived from Damien Cassou's ppa script. I think that
# snapshots already exist, and I am not going to build them, so this builds
# simply from the debian packages


## Crash is anything goes wrong
set -e

## The whole script works my manipulating global state
PATCH_FUNCTION=noPatch

function noPatch() {
    echo nothing to do
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

    ## PWL commented
    # Don't give the full path of the icon
    ##sed --in-place 'sX^Icon=/usr/share/icons/.*$XIcon=@DEB_FLAVOR@Xg' emacsVER.desktop

}

function packageForDistribution() {
    distrib="$1"
    mkdir build_$distrib
    ##cp --link *.tar.gz build_$distrib
    cp --link *.tar.bz2 build_$distrib
    cp --link *.tar.xz build_$distrib 2>/dev/null || echo
    cp --link *.dsc build_$distrib
    cd build_$distrib

    dpkg-source -x *.dsc

    cd ${PACKAGE}-${MAIN_VERSION}*

    cd debian
    $PATCH_FUNCTION
    cd ..

    ## PWL commented dch is in devscripts
    EMAIL=phillip.lord@newcastle.ac.uk dch --distribution "$distrib" --local "~ppa$SUB_VERSION~$distrib" "Build for $distrib"
    debuild -k0x60C3B396 -S -sa --changes-option='-DDistribution='${distrib}
    cd ..
    ## This actually uploads stuff -- god knows where to
    ## config is not needed because the ppa has a default configuraton in /etc/dput.cf
    dput ppa:phillip-lord/test-emacs ${PACKAGE}_${MAIN_VERSION}*.changes
    ##dput ppa:cassou/emacs ${PACKAGE}_${MAIN_VERSION}*.changes
    cd ..
}

function cleanTempDirectory() {
    cd /tmp && rm -rf emacs && mkdir emacs && cd emacs
}

function convertFromXz() {
    # Convert from tar.xz to tar.bz2 to support Ubuntu lucid and its dpkg < 1.15.6
    file=${PACKAGE}_${MAIN_VERSION}.orig.tar
    unxz --stdout $file.xz | bzip2 --compress --stdout > $file.bz2
    rm -f $file.xz
}


function prepareBuildFromDebianRelease() {

    cleanTempDirectory

    SERVER=http://ftp.fr.debian.org/debian/pool/main/e/emacs24
    PACKAGE=emacs24

    wget --no-clobber ${SERVER}/${PACKAGE}_${VERSION}.dsc
    wget --no-clobber ${SERVER}/${PACKAGE}_${MAIN_VERSION}.orig.tar.bz2
    ## PWL commented -- change to xv
    wget --no-clobber ${SERVER}/${PACKAGE}_${VERSION}.debian.tar.xz

    PATCH_FUNCTION=patchForEmacsRelease
    ##convertFromXz
}

function prepareBuildFromDebianNondfsgRelease() {

    cleanTempDirectory

    SERVER=http://cdn.debian.net/debian/pool/non-free/e/emacs24-non-dfsg
    PACKAGE=emacs24-non-dfsg

    wget --no-clobber ${SERVER}/${PACKAGE}_${VERSION}.dsc
    wget --no-clobber ${SERVER}/${PACKAGE}_${MAIN_VERSION}.orig.tar.bz2
    wget --no-clobber ${SERVER}/${PACKAGE}_${VERSION}.debian.tar.gz
}


#prepareBuildFromOld

MAIN_VERSION=24.4+1
PKG_VERSION=-1
VERSION=${MAIN_VERSION}${PKG_VERSION}

prepareBuildFromDebianRelease

packageForDistribution "precise" # 12.04 LTS
packageForDistribution "quantal" # 12.10
packageForDistribution "saucy"   # 13.10
packageForDistribution "trusty"  # 14.04

## Apparently NonDFSG release takes longer than DebianRelease

# prepareBuildFromDebianNondfsgRelease

# packageForDistribution "precise" # 12.04 LTS
# packageForDistribution "quantal" # 12.10
# packageForDistribution "saucy"   # 13.10
# packageForDistribution "trusty"  # 14.04

# prepareBuildFromNaquadahStable
# prepareBuildFromNaquadahUnstable

