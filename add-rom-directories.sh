#!/bin/bash

ROM_NAME="${1}"

if [ -z "${ROM_NAME}" ]
then
	echo "ERROR: $0 requires argument 1 (ROM_NAME)!"
	exit 1
fi

if [ ! -d ~/bin/ ]
then
	echo "ERROR: ~/bin does not exist!"
	exit 1
fi

mkdir ~/bin/targetfiles/${ROM_NAME}
mkdir ~/bin/roms/${ROM_NAME}
mkdir ~/bin/incrementals/${ROM_NAME}
