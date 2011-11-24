#
# Copyright (C) 2011 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#  This file contains various shell function definitions that can be
#  used to either build a static and shared libraries from sources, or
#  generate a Makefile to do it in parallel.
#

_BUILD_TAB=$(echo " " | tr ' ' '\t')

builder_command ()
{
    if [ -z "$_BUILD_MK" ]; then
        if [ "$VERBOSE2" = "yes" ]; then
            echo "$@"
        fi
        $@
    else
        echo "${_BUILD_TAB}${_BUILD_HIDE}$@" >> $_BUILD_MK
    fi
}


builder_log ()
{
    if [ "$_BUILD_MK" ]; then
        echo "${_BUILD_TAB}${_BUILD_HIDE}echo $@" >> $_BUILD_MK
    else
        log "$@"
    fi
}

# $1: Build directory
# $2: Optional Makefile name
builder_begin ()
{
    _BUILD_DIR_NEW=
    _BUILD_DIR=$1
    if [ ! -d "$_BUILD_DIR" ]; then
        mkdir -p "$_BUILD_DIR"
        fail_panic "Can't create build directory: $_BUILD_DIR"
        _BUILD_DIR_NEW=true
    else
        rm -rf "$_BUILD_DIR/*"
        fail_panic "Can't cleanup build directory: $_BUILD_DIR"
    fi
    _BUILD_TARGETS=
    _BUILD_PREFIX=
    _BUILD_MK=$2
    if [ -n "$_BUILD_MK" ]; then
        log "Creating temporary build Makefile: $_BUILD_MK"
        rm -f $_BUILD_MK &&
        echo "# Auto-generated by $0 - do not edit!" > $_BUILD_MK
        echo ".PHONY: all" >> $_BUILD_MK
        echo "all:" >> $_BUILD_MK
    fi
    # HIDE is used to hide the Makefile output, unless --verbose --verbose
    # is used.
    if [ "$VERBOSE2" = "yes" ]; then
        _BUILD_HIDE=""
    else
        _BUILD_HIDE=@
    fi

    builder_begin_module
}

# $1: Variable name
# out: Variable value
_builder_varval ()
{
    eval echo "\$$1"
}

_builder_varadd ()
{
    local _varname=$1
    local _varval=$(_builder_varval $_varname)
    shift
    if [ -z "$_varval" ]; then
        eval $_varname=\"$@\"
    else
        eval $_varname=\$$_varname\" $@\"
    fi
}


builder_set_prefix ()
{
    _BUILD_PREFIX="$@"
}

builder_begin_module ()
{
    _BUILD_CC=
    _BUILD_CXX=
    _BUILD_AR=
    _BUILD_C_INCLUDES=
    _BUILD_CFLAGS=
    _BUILD_CXXFLAGS=
    _BUILD_LDFLAGS_BEGIN_SO=
    _BUILD_LDFLAGS_END_SO=
    _BUILD_LDFLAGS_BEGIN_EXE=
    _BUILD_LDFLAGS_END_EXE=
    _BUILD_LDFLAGS=
    _BUILD_BINPREFIX=
    _BUILD_DSTDIR=
    _BUILD_SRCDIR=.
    _BUILD_OBJECTS=
    _BUILD_STATIC_LIBRARIES=
    _BUILD_SHARED_LIBRARIES=
}

builder_set_binprefix ()
{
    _BUILD_BINPREFIX=$1
    _BUILD_CC=${1}gcc
    _BUILD_CXX=${1}g++
    _BUILD_AR=${1}ar
}

builder_set_builddir ()
{
    _BUILD_DIR=$1
}

builder_set_srcdir ()
{
    _BUILD_SRCDIR=$1
}

builder_set_dstdir ()
{
    _BUILD_DSTDIR=$1
}

builder_ldflags ()
{
    _builder_varadd _BUILD_LDFLAGS $@
}

builder_ldflags_exe ()
{
    _builder_varadd _BUILD_LDFLAGS_EXE $@
}

builder_cflags ()
{
    _builder_varadd _BUILD_CFLAGS $@
}

builder_cxxflags ()
{
    _builder_varadd _BUILD_CXXFLAGS $@
}

builder_c_includes ()
{
    _builder_varadd _BUILD_C_INCLUDES $@
}

builder_reset_cflags ()
{
    _BUILD_CFLAGS=
}

builder_reset_cxxflags ()
{
    _BUILD_CXXFLAGS=
}

builder_reset_c_includes ()
{
    _BUILD_C_INCLUDES=
}

builder_link_with ()
{
    local LIB
    for LIB; do
        case $LIB in
            *.a)
                _builder_varadd _BUILD_STATIC_LIBRARIES $LIB
                ;;
            *.so)
                _builder_varadd _BUILD_SHARED_LIBRARIES $LIB
                ;;
            *)
                echo "ERROR: Unknown link library extension: $LIB"
                exit 1
        esac
    done
}

builder_sources ()
{
    local src srcfull obj cc cflags text
    if [ -z "$_BUILD_DIR" ]; then
        panic "Build directory not set!"
    fi
    if [ -z "$_BUILD_CC" ]; then
        _BUILD_CC=${CC:-gcc}
    fi
    if [ -z "$_BUILD_CXX" ]; then
        _BUILD_CXX=${CXX:-g++}
    fi
    for src in $@; do
        srcfull=$_BUILD_SRCDIR/$src
        if [ ! -f "$srcfull" ]; then
            echo "ERROR: Missing source file: $srcfull"
            exit 1
        fi
        obj=$(basename "$src")
        cflags="$_BUILD_CFLAGS"
        for inc in $_BUILD_C_INCLUDES; do
            cflags=$cflags" -I$inc"
        done
        cflags=$cflags" -I$_BUILD_SRCDIR"
        case $obj in
            *.c)
                obj=${obj%%.c}
                text="C"
                cc=$_BUILD_CC
                ;;
            *.cpp)
                obj=${obj%%.cpp}
                text="C++"
                cc=$_BUILD_CXX
                cflags="$cflags $_BUILD_CXXFLAGS"
                ;;
            *.cc)
                obj=${obj%%.cc}
                text="C++"
                cc=$_BUILD_CXX
                cflags="$cflags $_BUILD_CXXFLAGS"
                ;;
            *)
                echo "Unknown source file extension: $obj"
                exit 1
                ;;
        esac
        obj=$_BUILD_DIR/$obj.o
        if [ "$_BUILD_MK" ]; then
            echo "$obj: $srcfull" >> $_BUILD_MK
        fi
        builder_log "${_BUILD_PREFIX}$text: $src"
        builder_command $NDK_CCACHE $cc -c -o "$obj" "$srcfull" $cflags
        fail_panic "Could not compile ${_BUILD_PREFIX}$src"
        _BUILD_OBJECTS=$_BUILD_OBJECTS" $obj"
    done
}

builder_static_library ()
{
    local lib libname
    libname=$1
    if [ -z "$_BUILD_DSTDIR" ]; then
        panic "Destination directory not set"
    fi
    lib=$_BUILD_DSTDIR/$libname
    lib=${lib%%.a}.a
    if [ "$_BUILD_MK" ]; then
        _BUILD_TARGETS=$_BUILD_TARGETS" $lib"
        echo "$lib: $_BUILD_OBJECTS" >> $_BUILD_MK
    fi
    builder_log "${_BUILD_PREFIX}Archive: $libname"
    builder_command ${_BUILD_BINPREFIX}ar crs "$lib" "$_BUILD_OBJECTS"
    fail_panic "Could not archive ${_BUILD_PREFIX}$libname objects!"
}

builder_host_static_library ()
{
    local lib libname
    libname=$1
    if [ -z "$_BUILD_DSTDIR" ]; then
        panic "Destination directory not set"
    fi
    lib=$_BUILD_DSTDIR/$libname
    lib=${lib%%.a}.a
    if [ "$_BUILD_MK" ]; then
        _BUILD_TARGETS=$_BUILD_TARGETS" $lib"
        echo "$lib: $_BUILD_OBJECTS" >> $_BUILD_MK
    fi
    if [ -z "$BUILD_AR" ]; then
        _BUILD_AR=${AR:-ar}
    fi
    builder_log "${_BUILD_PREFIX}Archive: $libname"
    builder_command ${_BUILD_AR} crs "$lib" "$_BUILD_OBJECTS"
    fail_panic "Could not archive ${_BUILD_PREFIX}$libname objects!"
}

builder_shared_library ()
{
    local lib libname
    libname=$1
    lib=$_BUILD_DSTDIR/$libname
    lib=${lib%%.so}.so
    if [ "$_BUILD_MK" ]; then
        _BUILD_TARGETS=$_BUILD_TARGETS" $lib"
        echo "$lib: $_BUILD_OBJECTS" >> $_BUILD_MK
    fi
    builder_log "${_BUILD_PREFIX}SharedLibrary: $libname"

    # Important: -lgcc must appear after objects and static libraries,
    #            but before shared libraries for Android. It doesn't hurt
    #            for other platforms.
    builder_command ${_BUILD_BINPREFIX}g++ \
        -Wl,-soname,$(basename $lib) \
        -Wl,-shared,-Bsymbolic \
        $_BUILD_LDFLAGS_BEGIN_SO \
        $_BUILD_OBJECTS \
        $_BUILD_STATIC_LIBRARIES \
        -lgcc \
        $_BUILD_SHARED_LIBRARIES \
        -lc -lm \
        $_BUILD_LDFLAGS \
        $_BUILD_LDFLAGS_END_SO \
        -o $lib
    fail_panic "Could not create ${_BUILD_PREFIX}shared library $libname"
}

builder_host_shared_library ()
{
    local lib libname
    libname=$1
    lib=$_BUILD_DSTDIR/$libname
    lib=${lib%%.so}.so
    if [ "$_BUILD_MK" ]; then
        _BUILD_TARGETS=$_BUILD_TARGETS" $lib"
        echo "$lib: $_BUILD_OBJECTS" >> $_BUILD_MK
    fi
    builder_log "${_BUILD_PREFIX}SharedLibrary: $libname"

    if [ -z "$_BUILD_CXX" ]; then
        _BUILD_CXX=${CXX:-g++}
    fi

    # Important: -lgcc must appear after objects and static libraries,
    #            but before shared libraries for Android. It doesn't hurt
    #            for other platforms.
    builder_command ${_BUILD_CXX} \
        -shared -s \
        $_BUILD_OBJECTS \
        $_BUILD_STATIC_LIBRARIES \
        $_BUILD_SHARED_LIBRARIES \
        $_BUILD_LDFLAGS \
        -o $lib
    fail_panic "Could not create ${_BUILD_PREFIX}shared library $libname"
}

builder_host_executable ()
{
    local exe exename
    exename=$1
    exe=$_BUILD_DSTDIR/$exename$HOST_EXE
    if [ "$_BUILD_MK" ]; then
        _BUILD_TARGETS=$_BUILD_TARGETS" $exe"
        echo "$exe: $_BUILD_OBJECTS" >> $_BUILD_MK
    fi
    builder_log "${_BUILD_PREFIX}Executable: $exename$HOST_EXE"

    if [ -z "$_BUILD_CXX" ]; then
        _BUILD_CXX=${CXX:-g++}
    fi

    # Important: -lgcc must appear after objects and static libraries,
    #            but before shared libraries for Android. It doesn't hurt
    #            for other platforms.
    builder_command ${_BUILD_CXX} \
        -s \
        $_BUILD_OBJECTS \
        $_BUILD_STATIC_LIBRARIES \
        $_BUILD_SHARED_LIBRARIES \
        $_BUILD_LDFLAGS \
        -o $exe
    fail_panic "Could not create ${_BUILD_PREFIX}executable $libname"
}


builder_end ()
{
    if [ "$_BUILD_MK" ]; then
        echo "all: $_BUILD_TARGETS" >> $_BUILD_MK
        run make -j$NUM_JOBS -f $_BUILD_MK
        fail_panic "Could not build project!"
    fi

    if [ "$_BUILD_DIR_NEW" ]; then
        log2 "Cleaning up build directory: $_BUILD_DIR"
        rm -rf "$_BUILD_DIR"
        _BUILD_DIR_NEW=
    fi
}

# Same as builder_begin, but to target Android with a specific ABI
# $1: ABI name (e.g. armeabi)
# $2: Build directory
# $3: Optional Makefile name
builder_begin_android ()
{
    local ARCH ABI PLATFORM BUILDDIR DSTDIR SYSROOT CFLAGS
    local CRTBEGIN_SO_O CRTEND_SO_O CRTBEGIN_EXE_SO CRTEND_SO_O
    if [ -z "$NDK_DIR" ]; then
        panic "NDK_DIR is not defined!"
    elif [ ! -d "$NDK_DIR/platforms" ]; then
        panic "Missing directory: $NDK_DIR/platforms"
    fi
    ABI=$1
    ARCH=$(convert_abi_to_arch $ABI)
    PLATFORM=${2##android-}
    SYSROOT=$NDK_DIR/platforms/android-$PLATFORM/arch-$ARCH

    BINPREFIX=$NDK_DIR/$(get_default_toolchain_binprefix_for_arch $ARCH)
    SYSROOT=$NDK_DIR/$(get_default_platform_sysroot_for_arch $ARCH)

    CRTBEGIN_EXE_O=$SYSROOT/usr/lib/crtbegin_dynamic.o
    CRTEND_EXE_O=$SYSROOT/usr/lib/crtend_android.o

    CRTBEGIN_SO_O=$SYSROOT/usr/lib/crtbegin_so.o
    CRTEND_SO_O=$SYSROOT/usr/lib/crtend_so.o
    if [ ! -f "$CRTBEGIN_SO_O" ]; then
        CRTBEGIN_SO_O=$CRTBEGIN_EXE_O
    fi
    if [ ! -f "$CRTEND_SO_O" ]; then
        CRTEND_SO_O=$CRTEND_EXE_O
    fi

    builder_begin "$2" "$3"
    builder_set_prefix "$ABI "
    builder_set_binprefix "$BINPREFIX"

    builder_cflags "--sysroot=$SYSROOT"
    builder_cxxflags "--sysroot=$SYSROOT"
    _BUILD_LDFLAGS_BEGIN_SO="--sysroot=$SYSROOT -nostdlib $CRTBEGIN_SO_O"
    _BUILD_LDFLAGS_BEGIN_EXE="--sysroot=$SYSROOT -nostdlib $CRTBEGIN_EXE_O"

    _BUILD_LDFLAGS_END_SO="$CRTEND_SO_O"
    _BUILD_LDFLAGS_END_EXE="$CRTEND_EXE_O"

    case $ABI in
        armeabi)
            builder_cflags "-mthumb"
            ;;
        armeabi-v7a)
            builder_cflags "-march=armv7-a -mfloat-abi=softfp"
            builder_ldflags "-Wl,--fix-cortex-a8"
            ;;
    esac
}

# $1: Build directory
# $2: Optional Makefile name
builder_begin_host ()
{
    prepare_host_build
    builder_begin "$1" "$2"
    builder_set_prefix "$HOST_TAG "
}
