#!/bin/bash

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

	if [[ -n "${ROM_DATABASE_SCRIPT_DIR}" && $FILE =~ \.zip$ ]]
	then
		FILENAME=$(basename $FILE)

		if [ -z "${DEVICE_ID}" ]
		then
			echo "ERROR: $0 requires argument 2 (DEVICE_ID) to disable existing ROMs"
			exit 1
		fi

		(cd $ROM_DATABASE_SCRIPT_DIR && \
			node disable-build.js \
				--device $DEVICE_ID \
				--filename $FILENAME \
				--subdirectory $ROM_NAME \
				--disable_incrementals)
	fi

	rm $FILE
done

rmdir "${BIN_DIR}/roms/${ROM_NAME}"
rm -rf "${BIN_DIR}/targetfiles/${ROM_NAME}"
rm -rf "${BIN_DIR}/incrementals/${ROM_NAME}"
