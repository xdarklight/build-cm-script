build-cm-script
===============

A hacky script for building CyanogenMod roms. Use at your own risk - may eat kittens!<br>
It also has [cm-update-server] integration.

---

System setup (global variables):

```bash
export JAVA_HOME=/usr/lib/jvm/j2sdk1.7-oracle/

# This contains the subdirectories: targetfiles, incrementals, roms
export BIN_DIR=/path/to/storage/

# Recommended, but not necessary
export CCACHE_DIR=~/.ccache

# Specify how long you want to keep builds
export DELETE_ROMS_OLDER_THAN=8

# Required if you use cm-update-server:
export NODE_ENV=production
export ROM_DATABASE_SCRIPT_DIR=/path/to/cm-update-server
```

"Per build" variables:

```bash
# One of: NIGHTLY, SNAPSHOT, RELEASE, EXPERIMENTAL
export CM_BUILDTYPE=NIGHTLY

# Use if you don't want to "make clean" before the new build
# export SKIP_MAKE_CLEAN=true

# Use if you don't want to "repo sync" before the new build
# export SKIP_REPO_SYNC=true

# Use if you don't want to build incremental updates for this build
# export SKIP_BUILDING_INCREMENTALS=true

# Required if you want to build incremental updates, you may have to add additional parameters to this command to get the incrementals building correctly:
export OTA_FROM_TARGET_FILES_SCRIPT=build/tools/releasetools/ota_from_target_files
```

Starting the build:

```bash
build-cm.sh deviceid romdirectory local_manifest_device.xml

# Example:
# build-cm.sh falcon motog-cm11.0 local_manifest_moto_g.xml
```

**Note:** To create the required subdirectories in BIN_DIR (= before the very first build) you can simply use:
```bash
add-rom-directories.sh romdirectory

# Example:
# add-rom-directories.sh motog-cm11.0
```

  [cm-update-server]: https://github.com/xdarklight/cm-update-server/

