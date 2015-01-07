#!/bin/bash

ROM_NAME="${1}"

if [ -z "${ROM_NAME}" ]
then
	echo "ERROR: $0 requires argument 1 (ROM_NAME)!"
	exit 1
fi

if [ ! -d "${BIN_DIR}" ]
then
	# Nothing to do in this case.
	exit 0
fi

rm -rf "${BIN_DIR}/targetfiles/${ROM_NAME}"
rm -rf "${BIN_DIR}/roms/${ROM_NAME}"
rm -rf "${BIN_DIR}/incrementals/${ROM_NAME}"
