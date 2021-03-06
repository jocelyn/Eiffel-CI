#!/bin/bash

# Default values
ISE_MAJOR_MINOR_LATEST=18.01
ISE_BUILD_LATEST=101424

ISE_MAJOR_MINOR_NIGHTLY=18.01
ISE_BUILD_NIGHTLY=101424

ISE_MAJOR_MINOR_BETA=18.01
ISE_BUILD_BETA=101424

# Arguments
while true; do
	ISE_CHANNEL=$1
	shift || break
	ISE_PLATFORM=$1
	shift || break
	break
done


TMP_SAFETY_DELAY=10

# This script is meant for quick & easy install via:
#   $ curl -fsSL https://github.com/jocelyn/Eiffel-CI/raw/master/setup/install_eiffelstudio.sh -o get-eiffelstudio.sh
#   $ sh get-eiffelstudio.sh
#
# or
#   $ curl -sSL https://github.com/jocelyn/Eiffel-CI/raw/master/setup/install_eiffelstudio.sh | sh
#
# (Inspired by get.docker.com)

T_CURRENT_DIR=$(pwd)

# This value will automatically get changed for:
#   * latest
#	* specific release, using major.minor.build (such as 17.05.100416)
#   * beta
#   * nightly

DEFAULT_ISE_CHANNEL_VALUE="latest"
if [ -z "$ISE_CHANNEL" ]; then
    ISE_CHANNEL=$DEFAULT_ISE_CHANNEL_VALUE
fi

iseverParse() {
	major="${1%%.*}"
	minor="${1#$major.}"
	minor="${minor%%.*}"
	build="${1#$major.$minor.}"
}

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

do_install() {
	echo >&2 "Executing eiffelstudio install script ... ($ISE_CHANNEL)"

	if [ -n "$HOSTTYPE" ]; then
		architecture=$HOSTTYPE
	else
		architecture=$(uname -m)
	fi
	if [ -z "$ISE_PLATFORM" ]; then
		case $architecture in
			# officially supported
			amd64|x86_64)
				ISE_PLATFORM=linux-x86-64
				;;
			i386|i686)
				ISE_PLATFORM=linux-x86
				;;
			# unofficially supported with available repositories
			armv6l|armv6)
				ISE_PLATFORM=linux-armv6
				;;
			# not supported armv7 ...
			*)
				echo >&2 Error: $architecture is not a recognized platform.
				exit 1
				;;
		esac
	else
		echo >&2 Using existing ISE_PLATFORM=$ISE_PLATFORM on architecture $architecture
	fi

	case $ISE_CHANNEL in
		nightly)
			if [ "$ISE_MAJOR_MINOR_NIGHTLY.$ISE_BUILD_NIGHTLY" = "$ISE_MAJOR_MINOR_LATEST.$ISE_BUILD_LATEST" ]; then
				# Use latest release!
				echo >&2 Nightly is same as latest release.
				ISE_CHANNEL="latest"
			elif [ "$ISE_MAJOR_MINOR_NIGHTLY.$ISE_BUILD_NIGHTLY" = "$ISE_MAJOR_MINOR_BETA.$ISE_BUILD_BETA" ]; then
				# Use beta release!
				echo >&2 Nightly is same as beta release.
				ISE_CHANNEL="beta"
			fi
			;;
		beta)
			if [ "$ISE_MAJOR_MINOR_BETA.$ISE_BUILD_BETA" = "$ISE_MAJOR_MINOR_LATEST.$ISE_BUILD_LATEST" ]; then
				# Use latest release!
				echo >&2 Beta is same as latest release.
				ISE_CHANNEL="latest"
			fi
			;;
		*)
			;;
	esac


	case $ISE_CHANNEL in
		latest)
			#Use defaults .. see above.
			echo >&2 Use latest release.
			ISE_MAJOR_MINOR=$ISE_MAJOR_MINOR_LATEST
			ISE_BUILD=$ISE_BUILD_LATEST
			ISE_DOWNLOAD_FILE=Eiffel_${ISE_MAJOR_MINOR}_gpl_${ISE_BUILD}-${ISE_PLATFORM}.tar.bz2
			ISE_DOWNLOAD_URL=https://downloads.sourceforge.net/eiffelstudio/$ISE_DOWNLOAD_FILE
			iseverParse $ISE_MAJOR_MINOR.$ISE_BUILD
			echo >&2 Version=$major.$minor.$build
			;;
		beta)
			echo >&2 Use beta release.
			ISE_MAJOR_MINOR=$ISE_MAJOR_MINOR_BETA
			ISE_BUILD=$ISE_BUILD_BETA
			ISE_DOWNLOAD_URL=https://ftp.eiffel.com/pub/beta/${ISE_MAJOR_MINOR}/$ISE_DOWNLOAD_FILE
			iseverParse $ISE_MAJOR_MINOR.$ISE_BUILD
			echo >&2 Version=$major.$minor.$build
			;;
		nightly)

			echo >&2 Use nighlty release.
			ISE_MAJOR_MINOR=$ISE_MAJOR_MINOR_NIGHTLY
			ISE_BUILD=$ISE_BUILD_NIGHTLY

			ISE_DOWNLOAD_FILE=Eiffel_${ISE_MAJOR_MINOR}_gpl_${ISE_BUILD}-${ISE_PLATFORM}.tar.bz2
			ISE_DOWNLOAD_URL=https://ftp.eiffel.com/pub/beta/nightly/$ISE_DOWNLOAD_FILE
			iseverParse $ISE_MAJOR_MINOR.$ISE_BUILD
			echo >&2 Version=$major.$minor.$build
			;;
		*)
			echo >&2 Use custom release $ISE_CHANNEL if any
			iseverParse $ISE_CHANNEL
			echo >&2 $major.$minor.$build
			ISE_MAJOR_MINOR=$major.$minor
			ISE_BUILD=$build
			ISE_DOWNLOAD_FILE=Eiffel_${ISE_MAJOR_MINOR}_gpl_${ISE_BUILD}-${ISE_PLATFORM}.tar.bz2
			ISE_DOWNLOAD_URL=https://ftp.eiffel.com/pub/download/$ISE_MAJOR_MINOR/$ISE_DOWNLOAD_FILE
			;;
	esac

	if command_exists ecb; then
		cat >&2 <<-'EOF'
			Warning: the "ecb" command appears to already exist on this system.

			If you already have EiffelStudio installed, this script can cause trouble, which is
			why we're displaying this warning and provide the opportunity to cancel the
			installation.

			If you installed the current EiffelStudio package using this script and are using it
		EOF
		#FIXME: check if conflict may exists!
		cat >&2 <<-'EOF'
		again to update EiffelStudio, you can safely ignore this message.
		EOF

		cat >&2 <<-'EOF'

			You may press Ctrl+C now to abort this script.
		EOF
		( set -x; sleep $TMP_SAFETY_DELAY )
	fi
		
	user="$(id -un 2>/dev/null || true)"

	curl=''
	if command_exists curl; then
		curl='curl -sSL'
		#curl="$curl -H 'Cache-Control: no-cache'"
	elif command_exists wget; then
		curl='wget -qO-'
	elif command_exists busybox && busybox --list-modules | grep -q wget; then
		curl='busybox wget -qO-'
	fi

	#mkdir -p eiffel; cd eiffel
	ISE_EIFFEL=$(pwd)/Eiffel_$ISE_MAJOR_MINOR

	if [ -d "$ISE_EIFFEL" ]; then
		cat >&2 <<-'EOF'
			Warning: the folder $ISE_EIFFEL already exists!

			This script will remove it, to install a fresh release, which is
			why we're displaying this warning and provide the opportunity to cancel the
			installation.

			If you installed the current EiffelStudio package using this script and are using it
		EOF
		cat >&2 <<-'EOF'

			You may press Ctrl+C now to abort this script.
		EOF
		( set -x; sleep $TMP_SAFETY_DELAY )
		\rm -rf "$ISE_EIFFEL"
	fi

	echo >&2 Get $ISE_DOWNLOAD_URL
	if [ -z "$ISE_DOWNLOAD_URL" ]; then
		echo >&2 No download url !!!
		exit 1
	fi
	$curl $ISE_DOWNLOAD_URL | tar -x -p -s --bzip2
        #if [ -f "$ISE_DOWNLOAD_FILE" ]; then
	#	echo >&2 Already there.
        #else
	#	$curl -o $ISE_DOWNLOAD_FILE $ISE_DOWNLOAD_URL
        #fi
	#echo Extracting ...
	#tar -xv --bzip2 -f $ISE_DOWNLOAD_FILE

	ISE_RC_FILE="./eiffel_${ISE_MAJOR_MINOR}_${ISE_BUILD}.rc"
	echo \# Setup for EiffelStudio ${ISE_MAJOR_MINOR}.${ISE_BUILD} > $ISE_RC_FILE
	echo export ISE_PLATFORM=$ISE_PLATFORM >> $ISE_RC_FILE
	echo export ISE_EIFFEL=$ISE_EIFFEL >> $ISE_RC_FILE
	echo export PATH=\$ISE_EIFFEL/studio/spec/\$ISE_PLATFORM/bin:\$ISE_EIFFEL/tools/spec/\$ISE_PLATFORM/bin:\$ISE_EIFFEL/library/gobo/spec/\$ISE_PLATFORM/bin:\$ISE_EIFFEL/esbuilder/spec/\$ISE_PLATFORM/bin:\$PATH >> $ISE_RC_FILE
	cat $ISE_RC_FILE

	#export ISE_PLATFORM=$ISE_PLATFORM
	#export ISE_EIFFEL=$ISE_EIFFEL 
	#export PATH=$PATH:$ISE_EIFFEL/studio/spec/$ISE_PLATFORM/bin:$ISE_EIFFEL/tools/spec/$ISE_PLATFORM/bin

	. $ISE_RC_FILE

	if command_exists ecb; then
		echo >&2 EiffelStudio installed in $ISE_EIFFEL
		$ISE_EIFFEL/studio/spec/$ISE_PLATFORM/bin/ecb -version  >&2
		echo >&2 Use the file `pwd`/$ISE_RC_FILE to setup your Eiffel environment.
		case $ISE_CHANNEL in
			latest)
				ln -s -f $ISE_RC_FILE eiffel_latest.rc > /dev/null
				echo >&2 or the file `pwd`/eiffel_latest.rc
				;;
			beta)
				ln -s -f $ISE_RC_FILE eiffel_beta.rc > /dev/null
				echo >&2 or the file `pwd`/eiffel_beta.rc
				;;
			nightly)
				ln -s -f $ISE_RC_FILE eiffel_nightly.rc > /dev/null
				echo >&2 or the file `pwd`/eiffel_nightly.rc
				;;
			*)
				;;
		esac
		echo >&2 Happy Eiffeling!
	else
		echo >&2 ERROR: Installation failed !!!
		echo >&2 Check inside ${ISE_EIFFEL}
	fi
	cd $T_CURRENT_DIR
}

# wrapped up in a function so that we have some protection against only getting
# half the file during "curl | sh"

do_install

