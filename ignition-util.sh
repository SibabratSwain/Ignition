#! /bin/sh

#
# Copyright (c) 2021 Inductive Automation
# http://www.inductiveautomation.com
# All rights reserved.
#
# A utilities source script which is loaded by the ignition script. It is
# expected that the ignition shell script has sourced this script after and
# only after defining all variables, dirs, etc. This script is sourced first,
# followed by any additional scripts defined in FILES_TO_SOURCE and the
# `ignition.shconf` file. This script also receives the raw arguments assigned
# to the IGNITION_COMMANDS var to allow processing for runtime extraction
#
#
# NOTE:
# Any of the vars defined in this file should be overridden using an
# ignition.shconf file (must have executable permissions) which should just
# define a new value for the variable. This file will be updated on upgrade
# which will revert these values to their defaults.
#

# If set to anything the sudoers file will not be set.
#SKIP_SUDOERS_FILE=

# The location for the sudoers file which will be created when the launchctl
# service is installed. This ensures that gateway restarts for the service can
# happen without interactive login.
SUDOERS_FILE=${SUDOERS_FILE:-"/etc/sudoers.d/99-${APP_NAME}"}

# The path to the launchctl. typically this is `/bin/launchctl`, but allow for
# overriding via the ignition.shconf file
LAUNCHCTL_PATH=${LAUNCHCTL_PATH:-"$(command -v launchctl)"}

#------------------------------------------------------------------------------
#
# Do not modify anything beyond this point
#
#------------------------------------------------------------------------------


# The bundled runtime which should be used to run the gateway
PLATFORM_RUNTIME="jre-mac"

###############################################################################
# Main entry point. checks for the requirements of this script and prevent
# using it they aren't present.
#
# Required ignition vars: REALDIR, APP_NAME
###############################################################################
main() {

    # ignition-util.sh called directly, prevent without the prerequisite vars
    # these vars are the required ignition.sh vars for the usage commands
    if [ -z "${REALDIR}" ]; then
        echo "ERROR: ignition-util.sh cannot be used independently, ignition.sh should be used."
        exit 1
    fi

    # check if in standalone mode and assign the first arg to the command if
    # its not present
    test "${0#*"ignition-util.sh"}" != "$0" && STANDALONE=1 && IGNITION_COMMAND=${1}

    case "${IGNITION_COMMAND}" in
        'start'|'restart'|'install'|'installstart'|'console')
            checkRuntimes
            ;;
        'checkRuntimes'|'checkruntimes')
            checkRuntimes
            exit 0 # Exit here since we only want to check the runtimes
            ;;
        'runUpgrader'|'runupgrader')
            checkRuntimes
            runUpgrader
            exit 0 # Exit here since we only want to run the upgrader
            ;;
        *)
            if [ -n "${STANDALONE}" ]; then
                echo "Usage: ignition-util.sh [ checkruntimes | runupgrader ]"
                echo ""
                echo "Commands:"
                showUtilCommands "${IGNITION_COMMAND}"
            fi
    esac
}


###############################################################################
# Extracts the platform's runtime if it isn't already extracted or if there was
# a version update
#
# Required ignition vars: REALDIR
###############################################################################
checkRuntimes() {
    NEW_VERSION=$(readFileElse "${REALDIR}/lib/runtime/version" "no_new")
    OLD_VERSION=$(readFileElse "${REALDIR}/lib/runtime/${PLATFORM_RUNTIME}/version" "no_old")

    if [ ! -f "${REALDIR}/lib/runtime/${PLATFORM_RUNTIME}/bin/java" ]; then
        echo "decompressing runtime.."
    elif [ "${NEW_VERSION}" != "${OLD_VERSION}" ]; then
        echo "runtime needs to be updated"
    else
        return # We don't need to extract the runtime, so just return
    fi

    echo "decompressing runtime.."
    cd "${REALDIR}/lib/runtime/" && rm -rf "${PLATFORM_RUNTIME}" && tar -xzf "${PLATFORM_RUNTIME}".tar.gz "${PLATFORM_RUNTIME}"

    # If there isn't a version file for some reason, make one
    if [ "${NEW_VERSION}" = "no_new" ]; then
        "${REALDIR}/lib/runtime/${PLATFORM_RUNTIME}/bin/java" --version >> "${REALDIR}/lib/runtime/version"
    fi

    cp "${REALDIR}/lib/runtime/version" "${REALDIR}/lib/runtime/${PLATFORM_RUNTIME}"
    echo "runtime decompression complete"
}

###############################################################################
# Runs the Ignition Upgrader utility
#
# Required ignition vars: REALDIR
###############################################################################
runUpgrader() {
    echo "running Ignition Upgrader.."

    if ! OUTPUT=$("${REALDIR}/lib/runtime/${PLATFORM_RUNTIME}/bin/java" \
        -classpath "${REALDIR}/lib/core/common/common.jar" \
        com.inductiveautomation.ignition.common.upgrader.Upgrader \
        "${REALDIR}" \
        "${REALDIR}/data" \
        "${REALDIR}/logs" \
        file=ignition.conf 2>&1); then
        echo "error running upgrader: ${OUTPUT}"
        exit 1
    else
        echo "Upgrader completed successfully"
        exit 0
    fi
}

###############################################################################
# Reads the supplied file in $1 if it exists, if it doesn't $2 is echoed.
# Both arguments are required
###############################################################################
readFileElse() {
  if [ -f "$1" ]; then
        cat "$1"
  else
        echo "$2"
  fi
}

###############################################################################
# Creates an APP_NAME sudoers file to allow service restarts for launchctl The
# sudoers file is only created if RUN_AS_USER is specified and SKIP_SUDOERS_FILE
# is _NOT_ set. The sudoers file is checked with visudo to ensure correctness.
#
# The compliment to this is `removeSudoersFile`
#
# Required ignition vars: RUN_AS_USER, APP_PLIST_BASE, APP_PLIST
###############################################################################
maybeCreateSudoersFile() (
    # NOTE: This is a sub-shell function to ensure that checkInstalled doesn't
    #       modify the global-scope `installedStatus` variable.
    checkInstalled

    # shellcheck disable=SC2154
    if [ "${installedStatus}" != "${SERVICE_INSTALLED_DEFAULT}" ]; then
        return
    fi

    if [ "X${RUN_AS_USER}" != "X" ] && [ -z "${SKIP_SUDOERS_FILE}" ]; then

        if [ -f "${SUDOERS_FILE}" ]; then
            echo "updating default service sudoers file for user '${RUN_AS_USER}' at '${SUDOERS_FILE}'..."
        else
            echo "creating default service sudoers file for user '${RUN_AS_USER}' at '${SUDOERS_FILE}'..."
        fi

        {
            echo "# Allow Ignition applications to work with sudo"
            echo "Cmnd_Alias IGNITION_SVC_CMDS = ${LAUNCHCTL_PATH} start ${APP_PLIST_BASE}, \\"
            echo "                               ${LAUNCHCTL_PATH} stop ${APP_PLIST_BASE}, \\"
            echo "                               ${LAUNCHCTL_PATH} load /Library/LaunchDaemons/${APP_PLIST}, \\"
            echo "                               ${LAUNCHCTL_PATH} unload /Library/LaunchDaemons/${APP_PLIST}"
            echo "${RUN_AS_USER} ALL = (ALL) NOPASSWD: IGNITION_SVC_CMDS"
        } > "${SUDOERS_FILE}.tmp"

        # Only move the file if its valid by checking it with visudo
        if ! OUTPUT=$(visudo -cf "${SUDOERS_FILE}.tmp" 2>&1); then
            echo "sudoers file error: ${OUTPUT}"
        else
            mv "${SUDOERS_FILE}.tmp" "${SUDOERS_FILE}"
        fi
    fi
)

###############################################################################
# Removes the sudoers file which allows service restarts for launchctl
#
# The compliment to this is `maybeCreateSudoersFile`
###############################################################################
removeSudoersFile() {
    checkRootOrExit
    if [ -f "${SUDOERS_FILE}" ]; then
        echo "removing Ignition sudoers file"
        rm "${SUDOERS_FILE}"
    fi

    if [ -f "${SUDOERS_FILE}.tmp" ]; then
        echo "removing Ignition sudoers tmp file"
        rm "${SUDOERS_FILE}.tmp"
    fi
}

###############################################################################
# Essentially the same as mustBeRootOrExit, but used within the confines of
# this script. its redefined here to be used directly without resourcing
# ignition.sh.
###############################################################################
checkRootOrExit() {
    checkIsRoot
    if [ "${IS_ROOT}" != "true" ] ; then
        echo "Must be root to perform this action."
        exit 1
    fi
}

###############################################################################
# when launchctl is used we elevate permissions to account for the installed
# user. This will succeed if the user has already elevated anyways, its mainly
# to ensure that when Ignition itself attempts to perform service restarts etc.
# it will succeed without requiring interactive authentication
#
# Required ignition vars: APP_PLIST, APP_PLIST_BASE, RUN_AS_USER
###############################################################################
launchctl() {

    # if there isn't a specified RUN_AS_USER, let login requirements remain
    if [ -z "${RUN_AS_USER}" ]; then
        "${LAUNCHCTL_PATH}" "$@"
        return
    fi

    # load then unload is a "restart"
    case "$@" in
        "start ${APP_PLIST_BASE}")
            sudo "${LAUNCHCTL_PATH}" start "${APP_PLIST_BASE}"
            ;;
        "stop ${APP_PLIST_BASE}")
            sudo "${LAUNCHCTL_PATH}" stop "${APP_PLIST_BASE}"
            ;;
        "load /Library/LaunchDaemons/${APP_PLIST}")
            sudo "${LAUNCHCTL_PATH}" load "/Library/LaunchDaemons/${APP_PLIST}"
            ;;
        "unload /Library/LaunchDaemons/${APP_PLIST}")
            sudo "${LAUNCHCTL_PATH}" unload "/Library/LaunchDaemons/${APP_PLIST}"
            ;;
        *)
            "${LAUNCHCTL_PATH}" "$@"
            ;;
  esac
}

###############################################################################
# Prints the usage of the exposed functions from this script and only this
# script
###############################################################################
showUtilCommands() {
    echo "  checkruntimes   Extracts the Ignition platform runtime if necessary"
    echo "  runupgrader     Runs the Ignition Upgrader utility"
}

#------------------------------------------------------------------------------
#
# Overridden functions. These override functions in ignition.sh to perform some
# ancillary functionality like creating and removing sudoers files.
#
# Calls back to ignition.sh can happen, but should be done through the
# `ignitionSh` function
#
#------------------------------------------------------------------------------

###############################################################################
# Prints the usage of the exposed functions from this script _after_ the
# ignition.sh usage
#
# Required ignition vars: REALDIR
###############################################################################
showUsage() {
    if [ -z "${NO_SOURCE_IA_UTIL}" ]; then
        ignitionSh "${IGNITION_COMMAND}"
    fi
    echo "Additional Commands:"
    showUtilCommands
}

###############################################################################
# Override the installdeamon method which conditionally installs the sudoers
# file. This ensures that the sudoers file is only installed if launchctl
# install succeeds
###############################################################################
installdaemon() {
    if ignitionSh "${IGNITION_COMMAND}"; then
        maybeCreateSudoersFile
    fi
}

###############################################################################
# Override the removedaemon method which conditionally installs the sudoers
# file. This ensures that the sudoers file is only removed if launchctl removal
# succeeds
###############################################################################
removedaemon() {
    if ignitionSh "${IGNITION_COMMAND}"; then
      removeSudoersFile
    fi
}

###############################################################################
# Override the mustBeRootOrExit method. This checks if the sodoers file exists and
# that the calling user matches the one defined in RUN_AS_USER. If both of those
# conditions are true, the method just returns, ensuring the ability to perform
# start, stop, and restart functions.
#
# Required ignition vars: RUN_AS_USER
###############################################################################
mustBeRootOrExit() {
    # do some checks here to see if the sudoers file exists and that the user
    # matches the RUN_AS_USER user. If so, skip checkIsRoot
    if [ -f "${SUDOERS_FILE}" ] && [ "$(whoami)" = "${RUN_AS_USER}" ]; then
          return
    fi

    checkRootOrExit
}

###############################################################################
# Calls ignition.sh with the env var NO_SOURCE_IA_UTIL assigned a value which
# prevents this script from getting sourced again. Failing to do this results
# in an infinite loop.
###############################################################################
# shellcheck disable=SC2120
ignitionSh() {
    NO_SOURCE_IA_UTIL=1 "${REALDIR}/ignition.sh" "$@"
}

main "$@"
