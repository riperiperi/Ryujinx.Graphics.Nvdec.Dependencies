#!/bin/bash

set -e

if [ "$#" -le 3 ]; then
    echo "usage: <src_dir> <output_path> <build_arch> <target_system_name>"
    exit 1
fi

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

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

mkdir -p $output_path

if command -v podman &> /dev/null; then
    DOCKER=podman
elif command -v docker &> /dev/null; then
    DOCKER=docker
fi

if [ $target_system_name == "linux" ] && [ $build_arch == "arm64" ]; then
    $DOCKER run --rm -v $SCRIPT_DIR:/scripts -v $output_path:/output -v $src_dir:/source -t arm64v8/ubuntu:focal bash /scripts/compile.sh /source /output $build_arch "$target_system_name"
else
    $SCRIPT_DIR/compile.sh "$src_dir" "$output_path" "$build_arch" "$target_system_name"
fi
