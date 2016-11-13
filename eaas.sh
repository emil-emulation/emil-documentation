#!/bin/bash
set -x

### Configuration ###

# version / branch
DOCKER="eaas/wildfly:master-testing"

# if the container instance should be availble to non-local 
# FQDN/IP including port number. By default the container instance
# is bound to http://localhost.
#DOCKER_ENV="-e WEBFQDN=http://emil.bw-fla.uni-freiburg.de"

# define portmapping. the container exposes 
# - port 80 (application server)
# - port 10809 (nbd server / image archive)
# map these ports to your host machine's ports. 
# By default, the application server is mapped to 8080 and 
# the NBD server to 10809.
NETCONF="-p 8080:80 -p 10809:10809"

# container name. default eaas_<pid>
CONTAINER_NAME="eaas_$$"

# custom image archive path. default is <eaas-data-dir>/image-archive
#IMAGE_ARCHIVE=/mnt/image-archive

# add further volume bindings
VOLUMES=""

#set -e
releaseContainer()
{
    RET=$?
    set +e

    if [ -n "$CONTAINER" ]
    then
        docker rm -f "$CONTAINER" 1> /dev/null
    fi

    return $RET
}

abspath()
{
    if [[ -d "$1" ]]
    then
        cd "$1" &> '/dev/null' && echo "$(pwd -P)" && exit 0
    else 
        cd &> '/dev/null' "$(dirname "$1")" && echo "$(pwd -P)/$(basename "$1")" && exit 0
    fi
    exit 30
}

echo "pulling docker image: $DOCKER" 
docker pull "$DOCKER"

if [ $# -eq 0 ]
  then
    	BASEDIR="$(abspath .)" 
  else 
	BASEDIR="$(abspath $1)"
fi

if ! [ -d "$BASEDIR/emil-environments" ]; then
  echo "creating dir: $BASEDIR/emil-environments"
  mkdir -p "$BASEDIR/emil-environments"
fi
VOLUMES="$VOLUMES -v $BASEDIR/emil-environments:/eaas/emil-environments"

if ! [ -d "$BASEDIR/emil-object-environments" ]; then
  echo "creating dir: $BASEDIR/emil-object-environments"
  mkdir -p "$BASEDIR/emil-object-environments"
fi
VOLUMES="$VOLUMES -v $BASEDIR/emil-object-environments:/eaas/emil-object-environments"

if ! [ -d "$BASEDIR/log" ]; then
  echo "creating dir: $BASEDIR/log"
fi
VOLUMES="$VOLUMES -v $BASEDIR/log:/eaas/log"

if [ -d "$BASEDIR/config" ]; then
  echo "found local config: adding to container"
  VOLUMES="$VOLUMES -v $BASEDIR/config:/eaas/config"
fi

if ! [ -d "$BASEDIR/export" ]; then
  echo "creating export directory"
fi
VOLUMES="$VOLUMES -v $BASEDIR/export:/eaas/export"


if ! [ -z $OBJECT_ARCHIVE ]; then 
  VOLUMES="$VOLUMES -v $OBJECT_ARCHIVE:/eaas/objects"
else
  if [ -d "$BASEDIR/objects" ]; then
    echo "found local objects: adding to container"
    VOLUMES="$VOLUMES -v $BASEDIR/objects:/eaas/objects"
  else
    if [ -d "$BASEDIR/object-archive" ]; then
      VOLUMES="$VOLUMES -v $BASEDIR/object-archive:/eaas/objects"
    fi
  fi
fi

if ! [ -z "$IMAGE_ARCHIVE" ]; then
  VOLUMES="$VOLUMES -v $IMAGE_ARCHIVE:/eaas/image-archive"
else 
  if [ -d "$BASEDIR/image-archive" ]; then
  	echo "found local image-archive: adding to container"
  	VOLUMES="$VOLUMES -v $BASEDIR/image-archive:/eaas/image-archive"
  fi
fi

if ! [ -d "$BASEDIR/software-archive" ]; then
  echo "creating a new software archive backend"
  mkdir -p "$BASEDIR/software-archive"
fi
VOLUMES="$VOLUMES -v $BASEDIR/software-archive:/eaas/software-archive"


## need to run in priviliged mode to be able to run sheepshaver (running sysctl)
docker run --privileged $NETCONF $DOCKER_ENV $VOLUMES --name "$CONTAINER_NAME" --net bridge -it $DOCKER  
trap releaseContainer EXIT QUIT INT TERM

echo "FINISHED!"
