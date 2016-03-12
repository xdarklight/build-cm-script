#!/bin/bash

rom_db_is_available() {
	if [[ -n "${ROM_DATABASE_SCRIPT_DIR}" ]]
	then
		return 0
	else
		return 1
	fi
}

_rom_db_execute_command() {
	if rom_db_is_available
	then
		pushd "${ROM_DATABASE_SCRIPT_DIR}"
		node "${1}" "${@:2}"
		popd
	fi
}

rom_db_disable_build() {
	local DEVICE_ID="${1}"
	local ROM_SUBDIRECTORY="${2}"
	local FILENAME="${3}"

	_rom_db_execute_command \
		disable-build.js \
			--device "${DEVICE_ID}" \
			--filename "${FILENAME}" \
			--subdirectory "${ROM_SUBDIRECTORY}" \
			--disable_incrementals
}

rom_db_get_source_timestamp() {
	local DEVICE_ID="${1}"
	local ROM_SUBDIRECTORY="${2}"

	_rom_db_execute_command \
		get-sourcecode-timestamp.js \
			--device "${DEVICE_ID}" \
			--subdirectory "${ROM_SUBDIRECTORY}"
}

rom_db_get_target_files_zip_names() {
	local DEVICE_ID="${1}"
	local ROM_SUBDIRECTORY="${2}"
	local MAX_AGE_DAYS="${2}"

	_rom_db_execute_command \
		get-target-file-zipnames.js \
			--device "${DEVICE_ID}" \
			--subdirectory "${ROM_SUBDIRECTORY}" \
			--max_age_days "${MAX_AGE_DAYS}"
}

rom_db_add_build() {
	local DEVICE_ID="${1}"
	local ROM_SUBDIRECTORY="${2}"
	local ROM_FILE="${3}"
	local ROM_MD5SUM="${4}"
	local TARGET_FILES_FILE="${5}"
	local BUILD_PROP_FILE="${6}"
	local BUILD_TYPE="${7}"
	local SOURCE_TIMESTAMP="${8}"
	local CHANGELOG_FILE="${9}"
	local API_LEVEL
	local BUILD_TIMESTAMP
	local INCREMENTAL_ID

	API_LEVEL="$(grep "ro.build.version.sdk" "${BUILD_PROP_FILE}" | cut -d'=' -f2)"
	BUILD_TIMESTAMP="$(grep "ro.build.date.utc" "${BUILD_PROP_FILE}" | cut -d'=' -f2)"
	INCREMENTAL_ID="$(grep "ro.build.version.incremental" "${BUILD_PROP_FILE}" | cut -d'=' -f2)"

	if [ -z "${SOURCE_TIMESTAMP}" ]
	then
		local SOURCE_TIMESTAMP_PARAM=""
	else
		local SOURCE_TIMESTAMP_PARAM="--sourcecode_timestamp ${SOURCE_TIMESTAMP}"
	fi

	# First disable potentially existing builds
	# (for example if the current build is a re-build on the same date).
	rom_db_disable_build "${DEVICE_ID}" "${ROM_SUBDIRECTORY}" "${ROM_FILE}"

	_rom_db_execute_command \
		add-build.js \
			--active \
			--device "${DEVICE_ID}" \
			--subdirectory "${ROM_SUBDIRECTORY}" \
			--filename "$(basename "${ROM_FILE}")" \
			--md5sum "${ROM_MD5SUM}" \
			--filesize "$(stat --printf="%s" "${ROM_FILE}")" \
			--targetfileszip "${TARGET_FILES_FILE}" \
			--channel "${BUILD_TYPE}" \
			--api_level "${API_LEVEL}" \
			--timestamp "${BUILD_TIMESTAMP}" \
			--changelogfile "${CHANGELOG_FILE}" \
			--incrementalid "${INCREMENTAL_ID}" \
			$SOURCE_TIMESTAMP_PARAM
}

rom_db_add_incremental() {
	local ROM_SUBDIRECTORY="${1}"
	local INCREMENTAL_FILE="${2}"
	local INCREMENTAL_MD5SUM="${3}"
	local FROM_TARGET_FILES="${4}"
	local TO_TARGET_FILES="${5}"
	local BUILD_TIMESTAMP="${6}"

	_rom_db_execute_command \
		add-incremental.js \
			--active \
			--subdirectory "${ROM_SUBDIRECTORY}" \
			--filename "$(basename "${INCREMENTAL_FILE}")" \
			--md5sum "${INCREMENTAL_MD5SUM}" \
			--filesize "$(stat --printf="%s" "${INCREMENTAL_FILE}")" \
			--from_target_files "${FROM_TARGET_FILES}" \
			--to_target_files "${TO_TARGET_FILES}" \
			--timestamp "${BUILD_TIMESTAMP}"
}
