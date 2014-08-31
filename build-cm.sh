#!/bin/bash
# PARAMS:
# $1: Target ID (for example mb526).
# $2: "Name" of the ROM (this will be used as folder in the ROM_OUTPUT_DIRECTORY).
# PWD: This script has to be started from the "source code" folder.

BIN_DIR=${BIN_DIR:-"/home/android/"}
ROM_DATABASE_SCRIPT_DIR=${ROM_DATABASE_SCRIPT_DIR:-"${BIN_DIR}/cm-update-api/"}

DEVICE_ID=${DEVICE_ID:-"$1"}
ROM_SUBDIRECTORY=${ROM_SUBDIRECTORY:-"$2"}
LOCAL_MANIFEST=${LOCAL_MANIFEST:-"$3"}

if [[ -z "${DEVICE_ID}" ]]
then
	echo "Argument #1 (device ID) is required!"
	exit 1
fi

if [[ -z "${ROM_SUBDIRECTORY}" ]]
then
	echo "Argument #2 (ROM subdirectory) is required!"
	exit 1
fi

echo "Build-script was called for target '${DEVICE_ID}' and result directory '${ROM_SUBDIRECTORY}'."

PUBLIC_ROM_DIRECTORY=${PUBLIC_ROM_DIRECTORY:-"${BIN_DIR}/roms/${ROM_SUBDIRECTORY}"}
INCREMENTAL_UPDATES_DIRECTORY=${INCREMENTAL_UPDATES_DIRECTORY:-"${BIN_DIR}/incrementals/${ROM_SUBDIRECTORY}"}
TARGET_FILES_DIRECTORY=${TARGET_FILES_DIRECTORY:-"${BIN_DIR}/targetfiles/${ROM_SUBDIRECTORY}"}

ROM_OUTPUT_DIR="out/target/product/${DEVICE_ID}/"
TARGET_FILES_OUTPUT_DIR="${ROM_OUTPUT_DIR}/obj/PACKAGING/target_files_intermediates/"

DELETE_ROMS_OLDER_THAN=${DELETE_ROMS_OLDER_THAN:-7}

function disable_build {
	FILENAME="${1}"

	(cd $ROM_DATABASE_SCRIPT_DIR && \
		node disable-build.js \
			--device $DEVICE_ID \
			--filename $FILENAME \
			--subdirectory $ROM_SUBDIRECTORY \
			--disable_incrementals)
}

set -e
set -o xtrace
set -o pipefail

# Building will fail of no valid locale is set.
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

# Let's make sure JAVA_HOME is in our path and found first.
if [ ! -z "${JAVA_HOME}" ]
then
	echo "Using JDK from '${JAVA_HOME}'."
	export PATH="${JAVA_HOME}/bin:${PATH}"
fi

if [ -n "${LOCAL_MANIFEST}" ]
then
	echo "Using local manifest: ${LOCAL_MANIFEST}"

	if [ -e .repo/local_manifests/*.xml ]
	then
		rm .repo/local_manifests/*.xml
	fi

	SOURCE_MANIFEST_FILEPATH=$(readlink -e "./.repo/manifests/${LOCAL_MANIFEST}")
	ln -s "${SOURCE_MANIFEST_FILEPATH}" .repo/local_manifests/
fi

export USE_CCACHE=${USE_CCACHE:-1}

if [[ -z "${CCACHE_DIR}" ]]
then
	export CCACHE_DIR="${BIN_DIR}/.ccache/"
fi

if [[ "${SKIP_REPO_SYNC}" == "true" ]]
then
	echo "Skipping 'repo sync'"
else
	SOURCE_TIMESTAMP=$(date +"%s")

	echo "Starting 'repo sync'..."
	time repo sync
fi

export CM_BUILDTYPE=${CM_BUILDTYPE:-NIGHTLY}

echo "Getting CM prebuilts..."
time vendor/cm/get-prebuilts

echo "Setting up build environment..."
. ./build/envsetup.sh

IONICE="ionice -c3"
SCHEDULING="${IONICE} schedtool -B -n19 -e"

if [[ "${SKIP_MAKE_CLEAN}" == "true" ]]
then
	echo "Skipping make clean"

	# Remove potentially stale files.
	rm -f $ROM_OUTPUT_DIR/cm-*.zip
	rm -f $ROM_OUTPUT_DIR/md5sum
	rm -f $TARGET_FILES_OUTPUT_DIR/cm_*.zip
	rm -f $ROM_OUTPUT_DIR/system/build.prop
else
	echo "Cleaning output directory..."
	time $SCHEDULING make -j1 clean
fi

# Required, because otherwise CM won't build.
set +e
set +o xtrace

echo "Configuring build..."
time breakfast "${DEVICE_ID}" || exit 1

echo "Starting build..."
time $SCHEDULING make -j1 bacon || exit 1

echo "Finished build!"

set -e
set -o xtrace

TARGET_ROM_ZIP=$ROM_OUTPUT_DIR/cm-*.zip
TARGET_ROM_MD5SUM=$TARGET_ROM_ZIP.md5sum
TARGET_FILES_ZIP=$TARGET_FILES_OUTPUT_DIR/cm_*target*.zip

# Don't use absolute paths in the md5sum file.
sed -r -i "s|$(readlink -e ${ROM_OUTPUT_DIR})/?||g" $TARGET_ROM_MD5SUM

ls -la ${PUBLIC_ROM_DIRECTORY}

echo "Removing builds older than ${DELETE_ROMS_OLDER_THAN} days..."

# Remove old builds
for FILE in $(find "${PUBLIC_ROM_DIRECTORY}" -type f -mtime +${DELETE_ROMS_OLDER_THAN} -print)
do
	echo "Removing '${FILE}'..."

	if [[ -n "${ROM_DATABASE_SCRIPT_DIR}" && $FILE =~ \.zip$ ]]
	then
		disable_build $(basename $FILE)
	fi

	rm $FILE
done

ls -la ${PUBLIC_ROM_DIRECTORY}

if [[ -n "${ROM_DATABASE_SCRIPT_DIR}" ]]
then
	FILENAME=$(basename $TARGET_ROM_ZIP)
	MD5SUM=$(cat $TARGET_ROM_MD5SUM | cut -d' ' -f1)
	TARGET_FILES_FILENAME=$(basename $TARGET_FILES_ZIP)
	API_LEVEL=$(cat $ROM_OUTPUT_DIR/system/build.prop | grep "ro.build.version.sdk" | cut -d'=' -f2)
	BUILD_TIMESTAMP=$(cat $ROM_OUTPUT_DIR/system/build.prop | grep "ro.build.date.utc" | cut -d'=' -f2)
	INCREMENTAL_ID=$(cat $ROM_OUTPUT_DIR/system/build.prop | grep "ro.build.version.incremental" | cut -d'=' -f2)
	CHANGELOG_FILE="${ROM_OUTPUT_DIR}/all-projects-changelog.txt"

	CHANGELOG_SINCE=$(cd $ROM_DATABASE_SCRIPT_DIR && \
				node get-sourcecode-timestamp.js \
					--device $DEVICE_ID \
					--subdirectory $ROM_SUBDIRECTORY)

	# Only generate the changelog if we have a "start" value.
	if [[ -n "${CHANGELOG_SINCE}" ]]
	then
		echo "Generating changelog (since ${CHANGELOG_SINCE})... "
		repo forall -p -c "git log --oneline --since "${CHANGELOG_SINCE}"" > $CHANGELOG_FILE
	else
		echo "Skipping changelog since no 'start' was found... "
		echo "(unknown)" > $CHANGELOG_FILE
	fi

	if [ -z "${SOURCE_TIMESTAMP}" ]
	then
		SOURCE_TIMESTAMP_PARAM=""
	else
		SOURCE_TIMESTAMP_PARAM="--sourcecode_timestamp ${SOURCE_TIMESTAMP}"
	fi

	# Formatting for CMUpdater.
	sed -r -i 's|^project[ ](.*)[/]$|   \* \1|g' "${CHANGELOG_FILE}"

	CHANGELOG_PATH=$(readlink -e "${CHANGELOG_FILE}")
	FILESIZE=$(stat --printf="%s" $TARGET_ROM_ZIP)

	# First disable potentially existing builds
	# (for example if the current build is a re-build on the same date).
	disable_build $FILENAME

	(cd $ROM_DATABASE_SCRIPT_DIR && \
		node add-build.js --device $DEVICE_ID --filename $FILENAME --md5sum $MD5SUM \
			--channel $CM_BUILDTYPE --api_level $API_LEVEL --subdirectory $ROM_SUBDIRECTORY \
			--active --timestamp $BUILD_TIMESTAMP $SOURCE_TIMESTAMP_PARAM \
			--changelogfile $CHANGELOG_PATH --incrementalid $INCREMENTAL_ID \
			--targetfileszip $TARGET_FILES_FILENAME --filesize $FILESIZE)
fi

if [ -d "${TARGET_FILES_DIRECTORY}" ]
then
	# remove old target files
	for FILE in $(find "${TARGET_FILES_DIRECTORY}" -type f -mtime +${DELETE_ROMS_OLDER_THAN} -print)
	do
		echo "Removing '${FILE}'..."
		rm $FILE
	done

	# Incrementals were automatically disabled while disabling the original rom so we can safely delete these now.
	for FILE in $(find "${INCREMENTAL_UPDATES_DIRECTORY}" -type f -mtime +${DELETE_ROMS_OLDER_THAN} -print)
	do
		echo "Removing '${FILE}'..."
		rm $FILE
	done

	# Building incrementals is only possible if the database script exists.
	if [[ -n "${ROM_DATABASE_SCRIPT_DIR}" ]]
	then
		if [[ "${SKIP_BUILDING_INCREMENTALS}" == "true" ]]
		then
			echo "Skipping building incrementals"
		else
			SOURCE_TARGET_FILES=$(cd $ROM_DATABASE_SCRIPT_DIR && \
						node get-target-file-zipnames.js \
							--device $DEVICE_ID \
							--subdirectory $ROM_SUBDIRECTORY \
							--max_age_days $DELETE_ROMS_OLDER_THAN)

			for OLD_TARGET_FILES_ZIP in $SOURCE_TARGET_FILES
			do
				# Skip source == target
				if [ "${TARGET_FILES_FILENAME}" == "${OLD_TARGET_FILES_ZIP}" ]
				then
					continue
				fi

				CMUPDATERINCREMENTAL_HELPER_MAKEFILE="external/helper_cmupdaterincremental/build.mk"

				OLD_TARGET_FILES_ZIP_PATH="${TARGET_FILES_DIRECTORY}/${OLD_TARGET_FILES_ZIP}"
				OLD_ID_WITH_ENDING="${OLD_TARGET_FILES_ZIP##*-}"
				OLD_INCREMENTAL_ID="${OLD_ID_WITH_ENDING%%.*}"

				if [ ! -e "${OLD_TARGET_FILES_ZIP_PATH}" ]
				then
					echo "${OLD_TARGET_FILES_ZIP_PATH} does not exist - skipping building incremental update for it."
					continue
				fi

				echo "Building incremental update from ${OLD_TARGET_FILES_ZIP} (incrementalid: ${OLD_ID}) to ${TARGET_FILES_FILENAME} (incrementalid: ${INCREMENTAL_ID})."

				INCREMENTAL_FILENAME="incremental-${OLD_INCREMENTAL_ID}-${INCREMENTAL_ID}.zip"
				INCREMENTAL_FILE_PATH="${INCREMENTAL_UPDATES_DIRECTORY}/${INCREMENTAL_FILENAME}"

				# Target cmupdaterincremental is not upstream thus it can only be used for custom builds.
				# For all other builds we simply use the command provided in OTA_FROM_TARGET_FILES_SCRIPT.
				if [ -n "${OTA_FROM_TARGET_FILES_SCRIPT}" ]
				then
					time $SCHEDULING $OTA_FROM_TARGET_FILES_SCRIPT \
						--worker_threads 1 \
						--incremental_from $OLD_TARGET_FILES_ZIP_PATH \
						$TARGET_FILES_ZIP \
						$INCREMENTAL_FILE_PATH
				elif [ -e "${CMUPDATERINCREMENTAL_HELPER_MAKEFILE}" ]
				then
					time $SCHEDULING make \
						OTA_FROM_TARGET_SCRIPT_EXTRA_OPTS="--worker_threads 1" \
						INCREMENTAL_SOURCE_BUILD_ID="${OLD_INCREMENTAL_ID}" \
						INCREMENTAL_SOURCE_TARGETFILES_ZIP="${OLD_TARGET_FILES_ZIP_PATH}" \
						WITHOUT_CHECK_API=true \
						ONE_SHOT_MAKEFILE="${CMUPDATERINCREMENTAL_HELPER_MAKEFILE}" \
						cmupdaterincremental
				else
					echo "ERROR: No strategy for building incremental updates found!"
				fi

				mv "${ROM_OUTPUT_DIR}/${INCREMENTAL_FILENAME}" "${INCREMENTAL_FILE_PATH}"

				(cd $ROM_DATABASE_SCRIPT_DIR && \
						node add-incremental.js --filename $INCREMENTAL_FILENAME \
							--md5sum $(md5sum $INCREMENTAL_FILE_PATH | cut -d' ' -f1) \
							--filesize $(stat --printf="%s" $INCREMENTAL_FILE_PATH) \
							--subdirectory $ROM_SUBDIRECTORY \
							--timestamp $BUILD_TIMESTAMP \
							--from_target_files $OLD_TARGET_FILES_ZIP \
							--to_target_files $TARGET_FILES_FILENAME \
							--active)
			done
		fi
	fi
else
	echo "Incremental updates are not handled since their directory (${TARGET_FILES_DIRECTORY}) does not exist."
fi

mv $TARGET_ROM_ZIP "${PUBLIC_ROM_DIRECTORY}"
mv $TARGET_ROM_MD5SUM "${PUBLIC_ROM_DIRECTORY}"
mv $TARGET_FILES_ZIP "${TARGET_FILES_DIRECTORY}"

find ${PUBLIC_ROM_DIRECTORY} -type f -exec chmod 644 {} \;
