#!/bin/bash

set -e

DECODERS="h264,vp8"
LIBAVCODEC_VERSION=59
LIBAVUTIL_VERSION=57

if [ "$#" -le 3 ]; then
    echo "usage: <src_dir> <output_path> <build_arch> <target_system_name>"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

uname_system="$(uname -s)"

case "${uname_system}" in
    Linux*)     system_name=linux;;
    Darwin*)    system_name=macos;;
    CYGWIN*)    system_name=win;;
    MINGW*)     system_name=win;;
    *)          system_name="Unknown OS: ${uname_system}"
esac

src_dir=$1
output_path=$2
build_arch=$3
target_system_name=$4

mkdir -p $output_path

if command -v sudo &> /dev/null
then
    SUDO=sudo
fi

if [[ $system_name == "linux" ]]; then
    $SUDO apt-get update -y
    $SUDO apt-get install -y \
            yasm \
            build-essential \
            clang \
            llvm \
            make \
            automake \
            autoconf \
            pkg-config \
            libtool-bin \
            nasm
fi

if [[ $target_system_name == "linux" ]]; then
    export LDFLAGS="-static-libgcc -static-libstdc++"
    extra_configure_flags="--enable-cross-compile"
elif [[ $target_system_name == "macos" ]]; then
    brew install nasm

    export MACOSX_DEPLOYMENT_TARGET="11.0"
    export cc="clang -arch $build_arch"
    extra_configure_flags="--install-name-dir=\"@rpath\" --enable-cross-compile --disable-xlib"
elif [[ $target_system_name == "win" ]] && [[ $build_arch == "x86_64" ]]; then
    $SUDO apt-get install -y gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64

    export LDFLAGS="-static-libgcc -static-libstdc++ -static"
    extra_configure_flags="--target-os=mingw32 --cross-prefix=x86_64-w64-mingw32- --disable-w32threads"
fi

if [[ $build_arch == "arm64" ]]; then
    extra_configure_flags="$extra_configure_flags --enable-neon"
fi

pushd $src_dir
./configure --arch=$build_arch                    \
            --disable-everything                  \
            --disable-static                      \
            --disable-doc                         \
            --disable-programs                    \
            --disable-swscale                     \
            --disable-avformat                    \
            --disable-swresample                  \
            --disable-avdevice                    \
            --disable-avfilter                    \
            --disable-debug                       \
            --enable-avcodec                      \
            --enable-shared                       \
            --enable-decoder="$DECODERS"          \
            --enable-lto                          \
            --enable-stripping                    \
            $extra_configure_flags                \
            --prefix="install_output"

make -j$(nproc) && make install

mkdir -p $output_path
rm -f $output_path/*

if [[ $target_system_name == "linux" ]]; then
    cp -L install_output/lib/libavcodec.so.$LIBAVCODEC_VERSION $output_path
    cp -L install_output/lib/libavutil.so.$LIBAVUTIL_VERSION $output_path
elif [[ $target_system_name == "macos" ]]; then
    cp -L install_output/lib/libavcodec.$LIBAVCODEC_VERSION.dylib $output_path
    cp -L install_output/lib/libavutil.$LIBAVUTIL_VERSION.dylib $output_path
elif [[ $target_system_name == "win" ]]; then
    cp -L install_output/bin/avcodec-$LIBAVCODEC_VERSION.dll $output_path
    cp -L install_output/bin/avutil-$LIBAVUTIL_VERSION.dll $output_path
fi
popd