#!/bin/sh

# Variables
_SCRIPTNAME="${0##*/}"

# Functions
_err() {
	printf '\033[1;31m%s\033[0m\n' "$@" >&2
}
_log() {
	printf '\033[1;33m%s\033[0m\n' "$@"
}
_ListURLs() {
	printf '\033[0;33mURLs for %s:\033[0m\n' "$_DistroName"
	for URL; do
		local iter="$((iter + 1))"
		printf '\033[0;34m%s\033[0m: %s\n' "$iter" "$URL"
	done
}
_DownloadDistro() {
	# Vars
	_DistroDir="$1"
	_DistroName="$2"
#	_DistroURLs=remaining args
	shift 2

	# Setup dirs
	if [ ! -e "./${_DistroDir}" ]; then
		_log "No ${_DistroDir} directory found, gonna make it"
		mkdir "./${_DistroDir}"
	else
		_log "${_DistroDir} directory found, We wont clobber anything"
	fi
	unset _ANS
	cd "$_DistroDir"

	# List URLs
	_ListURLs $@	# Unquoted so it will expand to multiple arguments with our URLs

	# Confirm listed URLs are okay then download
	_log "Wanna download these to the ${_DistroDir} dir?"
	read -p '[y/n] ' _ANS
	if echo "$_ANS" | grep -Eiq 'y|yes'; then
		# We use until loop incase some download comes short
		until wget2 --progress=bar --continue --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 0 -- $@; do 		# Unquoted $@ so it will expand to multiple arguments with our URLs
			# this wget command is basically:
			# tell me how its goin, continue guys inprogress, retry even if bastard says no, but like wait a lil after they say no and even if they're quiet just like sit around for a bit and DONT GIVE UP
			_log 'A download failed, trying again...'
		done
	fi
	cd ..
}

# Guard against wrong dir
if [ ! -e './.ventoy' ]; then
	_err 'No ".ventoy" file found, this likely isnt the right spot'
	exit 1
fi
# we need the guy
if ! command -v wget2 >/dev/null 2>&1; then
	_err 'We need wget 2 plz'
	exit 1
fi

_log 'Fetching download URLs...'
# URLs for ISOs

## Void URLs
_VoidOfficialURLs="$(wget -q -O- https://voidlinux.org/download/ | grep -Eo 'https://repo-default.voidlinux.org/live/current/void-live-x86_64-[a-zA0-9\_\-]+.iso')"
_VoidUnofficialVoidBuildsURLs="$(wget -q -O- https://voidbuilds.xyz/download/ | grep -Eo 'void-live-unofficial-x86_64-[0-9\.\_]+-[0-9]+.iso|void-live-[a-zA-Z0-9\_]+-unofficial-x86_64-[0-9\.\_]+-[0-9]+.iso' | uniq)"
_VoidUnofficialVoidBuildsURLs="$(for i in $_VoidUnofficialVoidBuildsURLs; do echo "https://voidbuilds.xyz/download/${i}"; done)"

## Fedora requires a bit more work
_FedoraVERSION="$(wget -q -O- https://fedoraproject.org/workstation/download/ | grep -Eo 'https://download.fedoraproject.org/pub/fedora/linux/releases/[0-9]+' | head -n1 | rev | cut -d'/' -f1 | rev)"
_FedoraURLs="
https://download.fedoraproject.org/pub/fedora/linux/releases/${_FedoraVERSION}/Everything/x86_64/iso/$(wget -q -O- https://download.fedoraproject.org/pub/fedora/linux/releases/${_FedoraVERSION}/Everything/x86_64/iso | grep -Eo "Fedora-Everything-netinst-x86_64-${_FedoraVERSION}-[\.0-9]+.iso" | uniq)
https://download.fedoraproject.org/pub/fedora/linux/releases/${_FedoraVERSION}/Sericea/x86_64/iso/$(wget -q -O- https://download.fedoraproject.org/pub/fedora/linux/releases/${_FedoraVERSION}/Sericea/x86_64/iso | grep -Eo "Fedora-Sericea-ostree-x86_64-${_FedoraVERSION}-[\.0-9]+.iso" | uniq)
https://download.fedoraproject.org/pub/fedora/linux/releases/${_FedoraVERSION}/Silverblue/x86_64/iso/$(wget -q -O- https://download.fedoraproject.org/pub/fedora/linux/releases/${_FedoraVERSION}/Silverblue/x86_64/iso | grep -Eo "Fedora-Silverblue-ostree-x86_64-${_FedoraVERSION}-[\.0-9]+.iso" | uniq)
https://download.fedoraproject.org/pub/fedora/linux/releases/${_FedoraVERSION}/Workstation/x86_64/iso/$(wget -q -O- https://download.fedoraproject.org/pub/fedora/linux/releases/${_FedoraVERSION}/Workstation/x86_64/iso | grep -Eo "Fedora-Workstation-Live-x86_64-${_FedoraVERSION}-[\.0-9]+.iso" | uniq)
"
_FedoraSpinsURLs="$(wget -q -O- "https://download.fedoraproject.org/pub/fedora/linux/releases/${_FedoraVERSION}/Spins/x86_64/iso" | grep -Eo "Fedora-[a-zA-Z0-9\_]+-Live-x86_64-${_FedoraVERSION}-[\.0-9]+.iso" | uniq)"
_FedoraSpinsURLs="$(for i in $_FedoraSpinsURLs; do echo "https://download.fedoraproject.org/pub/fedora/linux/releases/${_FedoraVERSION}/Spins/x86_64/iso/$i"; done)"

## Alpine URL
_AlpineURLs="$(wget -q -O- https://alpinelinux.org/downloads/ | grep 'standard' | grep 'x86_64' | grep -Eo 'href=".*iso"' | sed 's/&#x2F;/\//g' | grep -Eo 'https.*.iso')"

## Arch URL
### Well shit, the only thing arch is actually fucking good at
### they make it piss easy to get a latest image (common activity for seasoned arch users) ((they need to reinstall every 3 months)) (((cause their systems break from the garbage "package manager" called pacman)))
_ArchURLs="https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso"

## Ubuntu
_UbuntuVERSIONS="$(wget -q -O- https://ubuntu.com/download/desktop | grep -Eo '\?version=[0-9\.]+' | rev | cut -d'=' -f1 | rev)"
_UbuntuURLs="$(for i in $_UbuntuVERSIONS; do echo https://releases.ubuntu.com/${i}/ubuntu-${i}-desktop-amd64.iso; done)"


# Download distro ISOs into specific dirs

## Void
_DownloadDistro 'Void' 'Void Linux' "$_VoidOfficialURLs"
_DownloadDistro 'Void' 'Void Unofficial (voidbuilds.xyz)' "$_VoidUnofficialVoidBuildsURLs"

## Fedora
_DownloadDistro 'Fedora' 'Fedora Linux' "$_FedoraURLs"
_DownloadDistro 'Fedora' "Fedora Spins" "$_FedoraSpinsURLs"

## Alpine
_DownloadDistro 'Alpine' 'Alpine Linux' "$_AlpineURLs"

## Arch
_DownloadDistro 'Arch' 'Arch Linux' "$_ArchURLs"

## Ubuntu
_DownloadDistro 'Ubuntu' 'Ubuntu Linux' "$_UbuntuURLs"



