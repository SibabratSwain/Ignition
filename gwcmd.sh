#! /bin/bash

IGNITION_PATH=$(cd "$( dirname "${BASH_SOURCE[0]}")" && pwd)
JAVA_CMD="${IGNITION_PATH}/lib/runtime/jre-mac/bin/java"
GW_JARS="${IGNITION_PATH}/lib/core/gateway/*"
COMMON_JARS="${IGNITION_PATH}/lib/core/common/*"

# cd to ignition dir
cd "${IGNITION_PATH}" >/dev/null 2>&1 || { echo "Failure to navigate to Ignition directory."; exit 1; }

# check runtimes through ignition.sh checkRuntimes function
[ ! -x "${IGNITION_PATH}/ignition.sh" ] && echo "File '${IGNITION_PATH}/ignition.sh' is not executable" && exit 1
"${IGNITION_PATH}/ignition.sh" "checkRuntimes"

# Run HeadlessControlUtil
"${JAVA_CMD}" -classpath "${IGNITION_PATH}:${GW_JARS}:${COMMON_JARS}" \
    com.inductiveautomation.catapult.control.HeadlessControlUtil \
    dataDir=data \
    currentDir="${IGNITION_PATH}" \
    "$@"
