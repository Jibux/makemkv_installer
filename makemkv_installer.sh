#!/bin/bash


set -o errexit -o errtrace -o pipefail -o nounset


date_fmt()
{
	date +"%H:%M:%S"
}

log()
{
	echo "$(date_fmt) - INFO - $1"
}

warn()
{
	echo "$(date_fmt) - WARN - $1" >&2
}

fail()
{
	echo "$(date_fmt) - ERROR - ${1:-Something wrong happened}" >&2
	exit 1
}

safe_cd()
{
	local d=$1
	cd "$d" || fail "Cannot cd to '$d'"
	log "Current dir: '$d'"
}

install_requirements()
{
	log "Install requirements"
	sudo apt-get install build-essential pkg-config libc6-dev libssl-dev\
		libexpat1-dev libavcodec-dev libgl1-mesa-dev qtbase5-dev zlib1g-dev
}

test_tar()
{
	tar -tzf "$1" &> /dev/null
}

download_tar()
{
	local file="$1.tar.gz"
	local dst="$WORKDIR/$file"
	if [ -f "$dst" ]; then
		if test_tar "$dst"; then
			log "$dst already exist"
			return 0
		else
			warn "$dst archive contains error, download it again"
			rm "$dst"
		fi
	fi
	log "Download $file to $dst"
	curl -# -o "$dst" "$DOWNLOAD_URL/$file" || fail "Download of '$file' failed"
	test_tar "$dst" || fail "'$dst' archive contains error"
}

untar()
{
	local f=$1
	log "Untar '$f'"
	tar -xzf "$f"
}

oss_install()
{
	safe_cd "$WORKDIR"
	untar "$OSS_PKG.tar.gz"
	safe_cd "$WORKDIR/$OSS_PKG"
	./configure
	make
	sudo make install
}

bin_install()
{
	safe_cd "$WORKDIR"
	untar "$BIN_PKG.tar.gz"
	safe_cd "$WORKDIR/$BIN_PKG"
        mkdir -p tmp
        echo -n accepted >tmp/eula_accepted
	make
	sudo make install
}

clean()
{
	log "Clean '$WORKDIR' workdir"
	rm -rf "$WORKDIR/makemkv"*
	rmdir "$WORKDIR" || true
}



trap fail ERR

WORKDIR="$HOME/makemkv_build"
DOWNLOAD_URL="https://www.makemkv.com/download"
VERSION=$(curl -s "$DOWNLOAD_URL/" | awk '/MakeMKV .+ for Windows/{print $3}')

[ -z "$VERSION" ] && fail "Cannot get version from MakeMKV website"

BIN_PKG="makemkv-bin-$VERSION"
OSS_PKG="makemkv-oss-$VERSION"

[ -d "$WORKDIR" ] || mkdir "$WORKDIR"

install_requirements

download_tar "$OSS_PKG"
download_tar "$BIN_PKG"

oss_install
bin_install

read -r -n 1 -t 60 -p "Clean workdir? (Y/n) " resp || true
echo
[[ "${resp:-y}" =~ (n|N) ]] || clean

exit 0

