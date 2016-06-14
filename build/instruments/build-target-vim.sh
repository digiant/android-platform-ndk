#!/bin/bash

# Copyright (c) 2011-2016 CrystaX.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are
# permitted provided that the following conditions are met:
#
#    1. Redistributions of source code must retain the above copyright notice, this list of
#       conditions and the following disclaimer.
#
#    2. Redistributions in binary form must reproduce the above copyright notice, this list
#       of conditions and the following disclaimer in the documentation and/or other materials
#       provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY CrystaX ''AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL CrystaX OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# The views and conclusions contained in the software and documentation are those of the
# authors and should not be interpreted as representing official policies, either expressed
# or implied, of CrystaX.

# include common function and variable definitions
. `dirname $0`/prebuilt-common.sh

PROGRAM_PARAMETERS="<src-dir>"

PROGRAM_DESCRIPTION=\
"Rebuild VIM for the CrystaX NDK.

This requires a temporary NDK installation containing
toolchain binaries for all target architectures.

By default, this will try with the current NDK directory, unless
you use the --ndk-dir=<path> option.

The output will be placed in appropriate sub-directories of
<ndk>/packages/vim/\$VERSION/\$ABI, but you can override this with the --out-dir=<path>

option.
"

PACKAGE_DIR=
register_var_option "--package-dir=<path>" PACKAGE_DIR "Put prebuilt tarballs into <path>"

NDK_DIR=$ANDROID_NDK_ROOT
register_var_option "--ndk-dir=<path>" NDK_DIR "Specify NDK root path for the build"

BUILD_DIR=
OPTION_BUILD_DIR=
register_var_option "--build-dir=<path>" OPTION_BUILD_DIR "Specify temporary build dir"

ABIS="$PREBUILT_ABIS"
register_var_option "--abis=<list>" ABIS "Specify list of target ABIs"

register_try64_option
register_jobs_option

extract_parameters "$@"

SRCDIR=$(echo $PARAMETERS | sed 1q)
if [ -z "$SRCDIR" ]; then
    echo "ERROR: Please provide the path to the VIM source tree. See --help" 1>&2
    exit 1
fi

if [ ! -d "$SRCDIR" ]; then
    echo "ERROR: No such directory: '$SRCDIR'" 1>&2
    exit 1
fi

ABIS=$(commas_to_spaces $ABIS)

if [ -z "$OPTION_BUILD_DIR" ]; then
    BUILD_DIR=$NDK_TMPDIR/build-vim
else
    eval BUILD_DIR=$OPTION_BUILD_DIR
fi
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
fail_panic "Could not create build directory: $BUILD_DIR"

dump_n "Detecting VIM version... "
VIM_VERSION=$(grep '^#define  *VIM_VERSION_SHORT\>' $SRCDIR/src/version.h | sed 's,^[^"]*"\([^"]*\)".*$,\1,')
if [ -z "$VIM_VERSION" ]; then
    panic "Couldn't detect VIM version!"
fi
dump "$VIM_VERSION"

dump_n "Detecting ncurses version..."
NCURSES_VERSION=$(ls -1 $NDK_DIR/packages/ncurses/ | sort | uniq | tail -n 1)
if [ -z "$NCURSES_VERSION" ]; then
    panic "Couldn't detect ncurses version!"
fi
dump "$NCURSES_VERSION"
NCURSES=$NDK_DIR/packages/ncurses/$NCURSES_VERSION

# $1: ABI
# $2: build directory
build_vim_for_abi ()
{
    local ABI=$1
    local OUTDIR="$2"
    local INSTALLDIR="$NDK_DIR/packages/vim/$VIM_VERSION/$ABI"

    dump "Building $ABI VIM"

    rm -Rf $OUTDIR

    run make -C $SRCDIR/android \
        NDK=$NDK_DIR \
        ABI=$ABI \
        OUTDIR=$OUTDIR \
        NCURSES=$NCURSES/$ABI \

    fail_panic "Couldn't build $ABI VIM"

    run mkdir -p $INSTALLDIR/
    fail_panic "Can't create $ABI install folder"

    run rm -Rf $OUTDIR/install/share/man && \
    run mv $OUTDIR/install/share/vim/vim*/* $OUTDIR/install/share/vim/ && \
    run rmdir $OUTDIR/install/share/vim/vim*/ &&
    ( cd $OUTDIR/install && run tar czf $INSTALLDIR/vim.tar.gz bin share )
    fail_panic "Can't install $ABI VIM"
}

BUILT_ABIS=""
for ABI in $ABIS; do
    DO_BUILD_PACKAGE="yes"
    if [ -n "$PACKAGE_DIR" ]; then
        PACKAGE_NAME="android-vim-$ABI.tar.xz"
        echo "Look for: $PACKAGE_NAME"
        try_cached_package "$PACKAGE_DIR" "$PACKAGE_NAME" no_exit
        if [ $? = 0 ]; then
            DO_BUILD_PACKAGE="no"
        else
            BUILT_ABIS="$BUILT_ABIS $ABI"
        fi
    fi
    if [ "$DO_BUILD_PACKAGE" = "yes" ]; then
        build_vim_for_abi $ABI "$BUILD_DIR/$ABI"
    fi
done

# If needed, package files into tarballs
if [ -n "$PACKAGE_DIR" ] ; then
    for ABI in $BUILT_ABIS; do
        FILES="packages/vim/$VIM_VERSION/$ABI"
        PACKAGE_NAME="android-vim-$ABI.tar.xz"
        PACKAGE="$PACKAGE_DIR/$PACKAGE_NAME"
        log "Packaging: $PACKAGE"
        pack_archive "$PACKAGE" "$NDK_DIR" "$FILES"
        fail_panic "Could not package $ABI VIM binaries!"
        dump "Packaging: $PACKAGE"
        cache_package "$PACKAGE_DIR" "$PACKAGE_NAME"
    done
fi

if [ -z "$OPTION_BUILD_DIR" ]; then
    log "Cleaning up..."
    rm -rf $BUILD_DIR
else
    log "Don't forget to cleanup: $BUILD_DIR"
fi

log "Done!"
