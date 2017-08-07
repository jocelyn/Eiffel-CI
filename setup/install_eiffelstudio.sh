#!/bin/sh

set -e

# This script is meant for quick & easy install via:
#   $ curl -fsSL https://github.com/jocelyn/Eiffel-CI/raw/master/setup/install_eiffelstudio.sh -o get-eiffelstudio.sh
#   $ sh get-eiffelstudio.sh
#
# or
#   $ curl -sSL https://github.com/jocelyn/Eiffel-CI/raw/master/setup/install_eiffelstudio.sh | sh

#
# NOTE: Make sure to verify the contents of the script
#       you downloaded matches the contents of install_eiffelstudio.sh
#       located at https://github.com/.../... FIXME !!!
#       before executing.
#
# (Inspired by get.docker.com)

T_CURRENT_DIR=$(pwd)

# This value will automatically get changed for:
#   * latest
#	* specific release, using major.minor.build (such as 17.05.100416)
#   * night

DEFAULT_CHANNEL_VALUE="latest"
if [ -z "$CHANNEL" ]; then
    CHANNEL=$DEFAULT_CHANNEL_VALUE
fi

#Default values
ISE_MAJOR_MINOR=17.05
ISE_BUILD=100416

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
	echo >&2 "Executing eiffelstudio install script ..."
	echo >&2 CHANNEL=$CHANNEL

	architecture=$(uname -m)
	case $architecture in
		# officially supported
		amd64|x86_64)
			ISE_PLATFORM=linux-x86-64
			;;
		# unofficially supported with available repositories
		armv6l|armv6)
			ISE_PLATFORM=linux-armv6
			;;
		# not supported armv7 ...
		*)
			cat >&2 <<-EOF
			Error: $architecture is not a recognized platform.
			EOF
			exit 1
			;;
	esac

	case $CHANNEL in
		latest)
			#Use defaults .. see above.
			echo >&2 Use latest release.
			iseverParse $ISE_MAJOR_MINOR.$ISE_BUILD
			echo >&2 Version=$major.$minor.$build
			ISE_DOWNLOAD_URL=http://downloads.sourceforge.net/eiffelstudio/Eiffel_${ISE_MAJOR_MINOR}_gpl_${ISE_BUILD}-${ISE_PLATFORM}.tar.bz2
			;;
		night)
			echo >&2 Use nighlty release.
			ISE_DOWNLOAD_URL=https://ftp.eiffel.com/pub/beta/nightly/Eiffel_${ISE_MAJOR_MINOR}_gpl_${ISE_BUILD}-${ISE_PLATFORM}.tar.bz2
			;;
		*)
			echo >&2 Use custom release $CHANNEL if any
			iseverParse $CHANNEL
			echo >&2 $major.$minor.$build
			ISE_MAJOR_MINOR=$major.$minor
			ISE_BUILD=$build
			ISE_DOWNLOAD_URL=https://ftp.eiffel.com/pub/download/$ISE_MAJOR_MINOR/Eiffel_${ISE_MAJOR_MINOR}_gpl_${ISE_BUILD}-${ISE_PLATFORM}.tar.bz2
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
		( set -x; sleep 20 )
	fi
		
	user="$(id -un 2>/dev/null || true)"

	curl=''
	if command_exists curl; then
		curl='curl -sSL -H \'Cache-Control: no-cache\' '
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
		cat >&2 <<-'EOF'

			You may press Ctrl+C now to abort this script.
		EOF
		( set -x; sleep 20 )
	fi

	cat >&2 <<-'EOF'
		Get $ISE_DOWNLOAD_URL
	EOF
	if [ -z "$ISE_DOWNLOAD_URL" ]; then
		cat >&2 <<-'EOF'
			No download url !!!
		EOF
		exit 1
	fi
	curl -vSL $ISE_DOWNLOAD_URL | tar -x --bzip2

	ISE_RC_FILE=setup_eiffel_${ISE_MAJOR_MINOR}_${ISE_BUILD}.rc
	echo \# Setup for EiffelStudio ${ISE_MAJOR_MINOR}.${ISE_BUILD} > $ISE_RC_FILE
	echo export ISE_PLATFORM=$ISE_PLATFORM >> $ISE_RC_FILE
	echo export ISE_EIFFEL=$ISE_EIFFEL >> $ISE_RC_FILE
	#PATH=$PATH:$ISE_EIFFEL/studio/spec/$ISE_PLATFORM/bin:$PATH:$ISE_EIFFEL/tools/spec/$ISE_PLATFORM/bin
	echo export PATH=\$PATH:\$ISE_EIFFEL/studio/spec/\$ISE_PLATFORM/bin:\$PATH:\$ISE_EIFFEL/tools/spec/\$ISE_PLATFORM/bin >> $ISE_RC_FILE

	cat $ISE_RC_FILE

	if command_exists ecb; then
		cat >&2 <<-'EOF'
			EiffelStudio installed ...
		EOF
		source $ISE_RC_FILE
		$(ecb -version) >&2
	else
		cat >&2 <<-'EOF'
			ERROR: Installation failed !!!
			Check inside ${ISE_EIFFEL}
		EOF
	fi
	cd $T_CURRENT_DIR
}

# wrapped up in a function so that we have some protection against only getting
# half the file during "curl | sh"

do_install
