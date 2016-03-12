#!/bin/bash

set -e
set -o xtrace
set -o pipefail

source "$(dirname $(readlink -f "${BASH_SOURCE:-$0}"))/rom-database-commands.sh"

ROM_NAME="${1}"
DEVICE_ID="${2}"

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

for FILE in $(find "${BIN_DIR}/roms/${ROM_NAME}" -type f -print)
do
	echo "Removing '${FILE}'..."

	if [[ -n "${DEVICE_ID}" && $FILE =~ \.zip$ ]]
	then
		rom_db_disable_build "${DEVICE_ID}" "${ROM_NAME}" "$(basename "${FILE}")"
	fi

	rm "${FILE}"
done

rmdir "${BIN_DIR}/roms/${ROM_NAME}"
rm -rf "${BIN_DIR}/targetfiles/${ROM_NAME}"
rm -rf "${BIN_DIR}/incrementals/${ROM_NAME}"
