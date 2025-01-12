#!/bin/bash
set -e

THISDIR="$(cd $(dirname $0) ; pwd)"

#https://www.python.org/dev/peps/pep-0425/

usage()
{
    echo "Usage: $0 [<options>]"
    echo "Options:"
    echo "  --pylon-base <name>           Base to get the pylon installer name. Something like ./installer/pylon-5.0.12.11829 This script will add -<arch>.tar.gz"
    echo "  --pylon-dir <name>            Directory where to look for pylon installers. This script then tries to find the correct one. This is not needed, if pylon-base is given"
    echo "  --platform-tag <name>         The python platform tag to build"
    echo "  --abi-tag <package>           The python abi tag to build"
    echo "  --disable-tests               Disable automatic unittests"
    echo "  -h                            This usage help"
}

ABI_TAG=""
PLATFORM_TAG=""
PYLON_TGZ_DIR=""
PYLON_BASE=""
PYLON_DIR=""
DISABLE_TESTS=""

while [ $# -gt 0 ]; do
    arg="$1"
    case $arg in
        --pylon-base) PYLON_BASE="$2" ; shift ;;
        --pylon-dir) PYLON_DIR="$2" ; shift ;;
        --platform-tag) PLATFORM_TAG="$2" ; shift ;;
        --abi-tag) ABI_TAG="$2" ; shift ;;
        --disable-tests) DISABLE_TESTS=1 ;;
        -h|--help) usage ; exit 1 ;;
        *)         echo "Unknown argument $arg" ; usage ; exit 1 ;;
    esac
    shift
done

BASE_IMAGE=""
QEMU_ARCH=""
PYTHON="python"
PYLON_ARCH=""
PYLON=""

case $ABI_TAG in
    cp27m) BASE_IMAGE="python:2.7.16-jessie" ;;
    cp34m) BASE_IMAGE="python:3.4.8-jessie" ;;
    cp35m) BASE_IMAGE="python:3.5.6-jessie" ;;
    cp36m) BASE_IMAGE="python:3.6.4-jessie" ;;
    cp37m) BASE_IMAGE="python:3.7.2-stretch" ;;
    *)
    echo "Unsupported abi '$ABI_TAG'. Supported tags: cp27m,cp34m,cp35m,cp36m,cp37m"
    exit 1
esac

case $PLATFORM_TAG in
    linux_x86_64)  QEMU_ARCH="x86_64";  BASE_IMAGE="amd64/$BASE_IMAGE";   PYLON_ARCH=x86_64 ;;
    linux_i686)    QEMU_ARCH="i386";    BASE_IMAGE="i386/$BASE_IMAGE";    PYLON_ARCH=x86 ;;
    linux_armv7l)  QEMU_ARCH="arm";     BASE_IMAGE="arm32v7/$BASE_IMAGE"; PYLON_ARCH=armhf ;;
    linux_aarch64) QEMU_ARCH="aarch64"; BASE_IMAGE="arm64v8/$BASE_IMAGE"; PYLON_ARCH=aarch64 ;;
    manylinux1_*) echo "manylinux is not yet supported :-("; exit 1 ;;
    *)
    echo "Unsupported platform tag '$PLATFORM_TAG'. Supported platforms: linux_x86_64, linux_i686, linux_armv7l, linux_aarch64"
    exit 1
esac

if [ -n "$PYLON_DIR" ]; then
    files=( $PYLON_DIR/pylon-*-$PYLON_ARCH.tar.gz )
    PYLON="${files[0]}"

    #special case for pylon 5.x where aarch64 was named arm64
    if [ ! -f "$PYLON" -a $PYLON_ARCH == "aarch64" ]; then
        files=( $PYLON_DIR/pylon-*-arm64.txar.gz )
        PYLON="${files[0]}"
    fi

    if [ ! -f "$PYLON" ]; then
        echo "Couldn't find pylon installer in $PYLON_DIR"
        exit 1
    fi
else
    PYLON=$PYLON_BASE-$PYLON_ARCH.tar.gz

    #special case for pylon 5.x where aarch64 was named arm64
    if [ ! -f "$PYLON" -a $PYLON_ARCH == "aarch64" ]; then
        PYLON="$PYLON_BASE-arm64.tar.gz"
    fi

    if [ ! -f "$PYLON" ]; then
        echo "Pylon installer $PYLON doesn't exist"
        exit 1
    fi
fi

ARGS=""
if [ -n "$DISABLE_TESTS" ]; then
    ARGS="$ARGS --disable-tests"
fi

echo "build-with-docker.sh --qemu-target-arch $QEMU_ARCH --docker-base-image $BASE_IMAGE --python $PYTHON --pylon-tgz $PYLON $ARGS"
$THISDIR/build-with-docker.sh --qemu-target-arch $QEMU_ARCH --docker-base-image $BASE_IMAGE --python $PYTHON --pylon-tgz $PYLON $ARGS
