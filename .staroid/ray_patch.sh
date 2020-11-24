#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ $# -ne 3 ]; then
    echo "usage) $0 [patch|reset] [RAY_HOME] [WHEEL]"
    exit 1
fi

OP=$1
RAY_HOME=$2
WHEEL=$3

RAY_UID=1000
RAY_GID=100

SED_INPLACE="sed -i"
uname | grep Darwin > /dev/null
if [ $? -eq 0 ]; then
    SED_INPLACE="sed -i .bak"
fi

if [ "$OP" == "patch" ]; then
    # patch wheel url
    echo "$WHEEL" | grep ^http > /dev/null
    if [ $? -ne 0 ]; then
        # path is given
        $SED_INPLACE "s|set -x|set -x; set -e|g" $RAY_HOME/build-docker.sh
        $SED_INPLACE "s|^WHEEL=.*|WHEEL=$WHEEL|g" $RAY_HOME/build-docker.sh
        $SED_INPLACE "s|wget.*||g" $RAY_HOME/build-docker.sh
    else
        # url is given
        $SED_INPLACE "s|^WHEEL_URL=.*|WHEEL_URL=\"$WHEEL\"|g" $RAY_HOME/build-docker.sh
    fi

    # build ray-ml
    $SED_INPLACE "s/\"ray-deps\" \"ray\"/\"ray-deps\" \"ray\" \"ray-ml\"/g" $RAY_HOME/build-docker.sh

    # patch PATH
    $SED_INPLACE "s/\/root/\/home\/ray/g" ${RAY_HOME}/docker/base-deps/Dockerfile

    # remove tensorflow from pip.
    # tensorflow need to be installed using conda, because
    # tensorflow is currently built for cuda 10.1
    # and base nvidia-docker image has cuda 11.0 installed.
    #
    # Although Dockerfile_staroid sym link cuda 10.1 from cuda 11.0 files (cuda 11 supposed to backward compatible),
    # tensorflow detect GPU correctly but crashing actual code in this way.
    #
    # conda install cuda 10.1 binaries together with tensorflow and it works well.
    # Therefore Dockerfile_staroid will install tensorflow using conda.
    $SED_INPLACE "/tensorflow/d" ${RAY_HOME}/python/requirements.txt
    $SED_INPLACE "/tensorflow/d" ${RAY_HOME}/python/requirements_ml_docker.txt
    $SED_INPLACE "/tensorflow/d" ${RAY_HOME}/python/requirements_rllib.txt
    $SED_INPLACE "/tensorflow/d" ${RAY_HOME}/python/requirements_tune.txt

elif [ "$OP" == "reset" ]; then
    git checkout ${RAY_HOME}/docker/ray/Dockerfile
    git checkout ${RAY_HOME}/docker/ray-deps/Dockerfile
    git checkout ${RAY_HOME}/docker/base-deps/Dockerfile
    git checkout ${RAY_HOME}/docker/ray-ml/Dockerfile
    git checkout ${RAY_HOME}/build-docker.sh

    git checkout ${RAY_HOME}/python/requirements.txt
    git checkout ${RAY_HOME}/python/requirements_ml_docker.txt
    git checkout ${RAY_HOME}/python/requirements_rllib.txt
    git checkout ${RAY_HOME}/python/requirements_tune.txt
else
    echo "Invalid operation $OP"
    exit 1
fi
