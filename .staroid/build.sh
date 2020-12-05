#!/bin/bash
# Custom builder script for Skaffold
# https://skaffold.dev/docs/pipeline-stages/builders/custom/
#

set -x
set -e
pwd

RAY_REPO=https://github.com/ray-project/ray.git
RAY_CHECKOUT=260b07cf0cf2c10c091711cc3d598663133c2dc5
PYTHON_VERSION=$1
SHORT_VER=`echo $PYTHON_VERSION | sed "s/\([0-9]*\)[.]\([0-9]*\)[.][0-9]*/\1\2/g"`

echo "PYTHON_VERSION=$PYTHON_VERSION, SHORT_VER=$SHORT_VER"

# Checkout ray source
git clone $RAY_REPO ray-py$SHORT_VER
cd ray-py$SHORT_VER
git checkout $RAY_CHECKOUT

# true to build .whl from source (will take about 3 hours).
# false to use pre-built whl file from http(s) url.
BUILD_WHEEL=${BUILD_WHEEL:-true}

if [ "$BUILD_WHEEL" == "true" ]; then
    if [ ! -d ".whl" ]; then # check if already built.
        git config user.name "build"
        git config user.email "ci@build.com"

        # patch default ray serve bind address from 127.0.0.1 to 0.0.0.0
        sed -i "s/DEFAULT_HTTP_HOST = \"127.0.0.1\"/DEFAULT_HTTP_HOST = \"0.0.0.0\"/g" python/ray/serve/constants.py
        git commit python/ray/serve/constants.py -m "patch serve bind address"

        # increase timeout for 'ray up' command
        sed -i "s/NODE_START_WAIT_S = 300/NODE_START_WAIT_S = 1200/g" python/ray/autoscaler/_private/command_runner.py
        git commit python/ray/autoscaler/_private/command_runner.py -m "increase ray up timeout"

        # Uncomment followings to build wheel for only single python version.
        if [ "BUILD_WHEEL_SINGLE_VERSION" == "true" ]; then
            if [ "$SHORT_VER" == "36" ]; then
                WHL_STRING="cp36-cp36m"
            elif [ "$SHORT_VER" == "37" ]; then
                WHL_STRING="cp37-cp37m"
            elif [ "$SHORT_VER" == "38" ]; then
                WHL_STRING="cp38-cp38"
            fi
            sed -ie "/^PYTHONS=/,+2d" python/build-wheel-manylinux1.sh
            sed -ie "/^chmod/a PYTHONS=\(\"$WHL_STRING\"\)" python/build-wheel-manylinux1.sh
            git commit python/build-wheel-manylinux1.sh -m "update"
            cat python/build-wheel-manylinux1.sh
        fi

        # current commit
        COMMIT=`git rev-parse HEAD`

        docker run \
            -e TRAVIS_COMMIT=$COMMIT \
            --rm -i \
            -w /ray \
            -v `pwd`:/ray \
            quay.io/pypa/manylinux2014_x86_64 \
            /ray/python/build-wheel-manylinux2014.sh
    fi

    WHEEL=`ls .whl/*-cp$SHORT_VER-*`
else
    if [ "$SHORT_VER" == "36" ]; then
        WHEEL="https://s3-us-west-2.amazonaws.com/ray-wheels/latest/ray-1.1.0.dev0-cp36-cp36m-manylinux1_x86_64.whl"
    elif [ "$SHORT_VER" == "37" ]; then
        WHEEL="https://s3-us-west-2.amazonaws.com/ray-wheels/latest/ray-1.1.0.dev0-cp37-cp37m-manylinux1_x86_64.whl"
    elif [ "$SHORT_VER" == "38" ]; then
        WHEEL="https://s3-us-west-2.amazonaws.com/ray-wheels/latest/ray-1.1.0.dev0-cp38-cp38-manylinux1_x86_64.whl"
    fi
fi

# apply non-root docker image patch
../.staroid/ray_patch.sh reset . .
../.staroid/ray_patch.sh patch . $WHEEL

# apply additional docker file commands
cat ../.staroid/Dockerfile_staroid >> docker/ray-ml/Dockerfile

# print patched files
git diff

cat docker/base-deps/Dockerfile
cat docker/ray-deps/Dockerfile
cat docker/ray/Dockerfile
cat docker/ray-ml/Dockerfile

# cp requirements to ray-ml dir
cp python/requirements* docker/ray-ml

# build docker image
./build-docker.sh --no-cache-build --gpu --python-version $PYTHON_VERSION

# print images
docker tag rayproject/ray-ml:nightly-gpu $IMAGE
docker images

# verify image hash are all different.
# In case of a parent image build fail,
# 'FROM ...' command child image will pull from internet instead of using local build,
# and child image bulid will success without error.
# In this case, multiple image may end up with the same image hash.
UNIQ_IMAGES=`docker images | grep ray-py | awk '{print $3}' | uniq | wc -l`
NUM_IMAGES=`docker images | grep ray-py | awk '{print $3}' | wc -l`

if [ "$NUM_IMAGES" != "$UNIQ_IMAGES" ]; then
    echo "Error. Duplicated image hash found."
    exit 1
fi

if $PUSH_IMAGE; then
    docker push $IMAGE
fi
