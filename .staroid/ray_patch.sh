#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ $# -ne 3 ]; then
    echo "usage) $0 [patch|reset] [RAY_HOME] [PYTHON_VERSION]"
    exit 1
fi

OP=$1
RAY_HOME=$2
PYTHON_VERSION=$3

RAY_WHEEL_URL='https://s3-us-west-2.amazonaws.com/ray-wheels/latest/ray-1.1.0.dev0-cp${PY_VER}-cp${PY_VER}m-manylinux1_x86_64.whl'
RAY_UID=1000
RAY_GID=100

SED_INPLACE="sed -i"
uname | grep Darwin > /dev/null
if [ $? -eq 0 ]; then
    SED_INPLACE="sed -i .bak"
fi

if [ "$OP" == "patch" ]; then
    # patch miniconda python version
    $SED_INPLACE "s/python=3.7.7/python=$PYTHON_VERSION/g" $RAY_HOME/docker/base-deps/Dockerfile

    # patch wheel url
    PY_VER=`echo $PYTHON_VERSION | sed 's/\([0-9]\)[.]\([0-9]\).*/\1\2/g'`
    RAY_WHEEL_URL=`eval echo "$RAY_WHEEL_URL"`
    $SED_INPLACE "s|WHEEL_URL=.*.whl\"|WHEEL_URL=\"${RAY_WHEEL_URL}\"|g" $RAY_HOME/build-docker.sh
    $SED_INPLACE "s|set -x|set -x; set -e|g" $RAY_HOME/build-docker.sh

    # patch PATH
    $SED_INPLACE "s/\/root/\/home\/ray/g" ${RAY_HOME}/docker/base-deps/Dockerfile

    # patch PATH in profile
    $SED_INPLACE "s/ \/etc\/profile.d\/conda.sh/\> \/home\/ray\/.bash_profile/g" ${RAY_HOME}/docker/base-deps/Dockerfile

    # patch kubectl installation section
    $SED_INPLACE "s/apt-key add/sudo apt-key add/g" ${RAY_HOME}/docker/base-deps/Dockerfile
    $SED_INPLACE "s/touch \/etc/sudo touch \/etc/g" ${RAY_HOME}/docker/base-deps/Dockerfile
    $SED_INPLACE "s/tee -a \/etc/sudo tee -a \/etc/g" ${RAY_HOME}/docker/base-deps/Dockerfile

    # patch apt-get
    $SED_INPLACE "s/apt-get/sudo apt-get/g" ${RAY_HOME}/docker/base-deps/Dockerfile
    $SED_INPLACE "s/rm -rf \/var/sudo rm -rf \/var/g" ${RAY_HOME}/docker/base-deps/Dockerfile
    $SED_INPLACE "s/apt-get/sudo apt-get/g" ${RAY_HOME}/docker/ray-ml/Dockerfile

    # patch rm
    $SED_INPLACE "s/ rm /sudo rm /g" ${RAY_HOME}/docker/ray-deps/Dockerfile
    $SED_INPLACE "s/ rm /sudo rm /g" ${RAY_HOME}/docker/ray/Dockerfile

    # Add ray user & install sudo
    # lines until 'ARG DEBIAN_FRONTNED ...'
    #
    # install tzdata here to initialize tzdata in non-interactive mode.
    # otherwise, tzdata will be installed as a transitive dependency later and show keyboard prompt
    cat $RAY_HOME/docker/base-deps/Dockerfile | sed '/ARG DEBIAN/q' > /tmp/ray_tmp_docker
    cat <<EOF >> /tmp/ray_tmp_docker
RUN apt-get update -y && apt-get install -y sudo tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean
RUN useradd -ms /bin/bash -d /home/ray ray --uid $RAY_UID --gid $RAY_GID \
    && usermod -aG sudo ray \
    && echo 'ray ALL=NOPASSWD: ALL' >> /etc/sudoers
USER 1000
ENV HOME=/home/ray
EOF
    # lines after 'ARG DEBIAN_FRONTNED ...'
    cat $RAY_HOME/docker/base-deps/Dockerfile | sed '1,/ARG DEBIAN/d' >> /tmp/ray_tmp_docker
    mv /tmp/ray_tmp_docker $RAY_HOME/docker/base-deps/Dockerfile
elif [ "$OP" == "reset" ]; then
    git checkout ${RAY_HOME}/docker/ray/Dockerfile
    git checkout ${RAY_HOME}/docker/ray-deps/Dockerfile
    git checkout ${RAY_HOME}/docker/base-deps/Dockerfile
    git checkout ${RAY_HOME}/docker/ray-ml/Dockerfile
    git checkout ${RAY_HOME}/build-docker.sh
else
    echo "Invalid operation $OP"
    exit 1
fi

