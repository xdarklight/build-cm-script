#!/bin/bash

ROM_NAME="${1}"

if [ -z "${ROM_NAME}" ]
then
	echo "ERROR: $0 requires argument 1 (ROM_NAME)!"
	exit 1
fi

if [ ! -d "${BIN_DIR}" ]
then
	echo "ERROR: ${BIN_DIR} does not exist!"
	exit 1
fi

mkdir "${BIN_DIR}/targetfiles/${ROM_NAME}"
mkdir "${BIN_DIR}/roms/${ROM_NAME}"
mkdir "${BIN_DIR}/incrementals/${ROM_NAME}"
