#!/bin/bash
PKG_WORKDIR="pkg_work"
PCSX2_WORKDIR="pcsx2version"

#=========================
die() { echo >&2 "$*"; exit 1; };

 get_archlinux32_pkg() {
	#WARNING: Only work on well formatted html
	#usage:  get_archlinux32_pkg [link] [dest]
	# get_archlinux32_pkg http://pool.mirror.archlinux32.org/pentium4/extra/aom-1.0.0.errata1-1.2-pentium4.pkg.tar.xz ./cache/
	# get_archlinux32_pkg https://www.archlinux32.org/packages/pentium4/extra/xvidcore/ ./cache/
	
	REAL_LINK=""
	PAR_PKG_LINK=$(echo $1 | grep "pkg.tar")
	
	if [ -n "$PAR_PKG_LINK" ]; then
		REAL_LINK="$PAR_PKG_LINK"
	else
		rm -rf tmp_file_html
		wget -nv -c $1 -O tmp_file_html
		REAL_LINK=$(grep "pkg.tar" tmp_file_html | grep --invert-match ".sig" | sed -n 's/.*href="\([^"]*\).*/\1/p')
		rm -rf tmp_file_html
		
		if [ -z "$REAL_LINK" ]; then
			die "* ERROR get_archlinux32_pkg: Fail to download: $1"
		fi
	fi
	
	wget -nv -c $REAL_LINK -P $2
}

get_archlinux32_pkgs() {
	#Usage: get_archlinux32_pkgs [dest] pack1 pack2...
	#https://mirror.datacenter.by/pub/archlinux32/$arch/$repo/"
	
	rm -rf tmp_pentium4_core_html
	rm -rf tmp_pentium4_extra_html
	rm -rf tmp_pentium4_community_html
	wget -nv -c https://mirror.datacenter.by/pub/archlinux32/pentium4/core/ -O tmp_pentium4_core_html
	wget -nv -c https://mirror.datacenter.by/pub/archlinux32/pentium4/extra/ -O tmp_pentium4_extra_html
	wget -nv -c https://mirror.datacenter.by/pub/archlinux32/pentium4/community/ -O tmp_pentium4_community_html
	
	for current_pkg in "${@:2}"
	do
		PKG_NAME_CORE=$(grep "$current_pkg-[0-9]" tmp_pentium4_core_html | grep --invert-match ".sig" | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep "^$current_pkg")
		
		if [ -n "$PKG_NAME_CORE" ]; then
			#echo "CORE: Downloading $current_pkg in $1 : $PKG_NAME_CORE"
			#echo "http://pool.mirror.archlinux32.org/pentium4/core/$PKG_NAME_CORE"
			get_archlinux32_pkg "http://pool.mirror.archlinux32.org/pentium4/core/$PKG_NAME_CORE" $1
		else
			PKG_NAME_EXTRA=$(grep "$current_pkg-[0-9]" tmp_pentium4_extra_html | grep --invert-match ".sig" | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep "^$current_pkg")
			
			if [ -n "$PKG_NAME_EXTRA" ]; then
				#echo "EXTRA: Downloading $current_pkg in $1 : $PKG_NAME_EXTRA"
				#echo "http://pool.mirror.archlinux32.org/pentium4/extra/$PKG_NAME_EXTRA"
				get_archlinux32_pkg "http://pool.mirror.archlinux32.org/pentium4/extra/$PKG_NAME_EXTRA" $1
			else
				PKG_NAME_COMMUNITY=$(grep "$current_pkg-[0-9]" tmp_pentium4_community_html | grep --invert-match ".sig" | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep "^$current_pkg")
				
				if [ -n "$PKG_NAME_COMMUNITY" ]; then
					#echo "COMMUNITY: Downloading $current_pkg in $1 : $PKG_NAME_COMMUNITY"
					#echo "http://pool.mirror.archlinux32.org/pentium4/community/$PKG_NAME_COMMUNITY"
					get_archlinux32_pkg "http://pool.mirror.archlinux32.org/pentium4/community/$PKG_NAME_COMMUNITY" $1
				else
					die "ERROR get_archlinux32_pkgs: Package don't found: $current_pkg"
				fi
			fi
		fi
	done
	
	rm -rf tmp_pentium4_core_html
	rm -rf tmp_pentium4_extra_html
	rm -rf tmp_pentium4_community_html
}
#=========================
#Initializing the keyring requires entropy
pacman-key --init

# Enable Multilib
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

# Configure for compilation:
#sed -i '/^BUILDENV/s/\!ccache/ccache/' /etc/makepkg.conf
sed -i '/#MAKEFLAGS=/c MAKEFLAGS="-j2"' /etc/makepkg.conf
#sed -i '/^COMPRESSXZ/s/\xz/xz -T 2/' /etc/makepkg.conf
#sed -i "s/^PKGEXT='.pkg.tar.gz'/PKGEXT='.pkg.tar.xz'/" /etc/makepkg.conf
#sed -i '$a   CFLAGS="$CFLAGS -w"'   /etc/makepkg.conf
#sed -i '$a CXXFLAGS="$CXXFLAGS -w"' /etc/makepkg.conf
sed -i 's/^CFLAGS\s*=.*/CFLAGS="-march=nehalem -O2 -pipe -fno-stack-protector"/' /etc/makepkg.conf
sed -i 's/^CXXFLAGS\s*=.*/CXXFLAGS="-march=nehalem -O2 -pipe -fno-stack-protector"/' /etc/makepkg.conf
#sed -i 's/^LDFLAGS\s*=.*/LDFLAGS="-Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now"/' /etc/makepkg.conf
sed -i 's/^#PACKAGER\s*=.*/PACKAGER="DanielDevBR"/' /etc/makepkg.conf

# Add more repo:
echo "" >> /etc/pacman.conf

# https://github.com/archlinuxcn/repo
echo "[archlinuxcn]" >> /etc/pacman.conf
echo "SigLevel = Optional TrustAll" >> /etc/pacman.conf
echo "Server = https://repo.archlinuxcn.org/\$arch" >> /etc/pacman.conf
echo "" >> /etc/pacman.conf

# https://lonewolf.pedrohlc.com/chaotic-aur/
echo "[chaotic-aur]" >> /etc/pacman.conf
echo "SigLevel = Optional TrustAll" >> /etc/pacman.conf
echo "Server = http://lonewolf-builder.duckdns.org/\$repo/x86_64" >> /etc/pacman.conf
echo "Server = http://chaotic.bangl.de/\$repo/x86_64" >> /etc/pacman.conf
echo "Server = https://repo.kitsuna.net/x86_64" >> /etc/pacman.conf
echo "" >> /etc/pacman.conf
#pacman-key --keyserver keys.mozilla.org -r 3056513887B78AEB
#pacman-key --lsign-key 3056513887B78AEB

pacman -Syy && pacman -S archlinuxcn-keyring

pacman -Syy
#Add "gcc lib32-gcc-libs" for compile in the list:
pacman -S --noconfirm wget base-devel multilib-devel pacman-contrib git tar grep sed zstd xz
#===========================================================================================

# Get pcsx2-git
# using the package
mkdir "$PCSX2_WORKDIR"
mkdir "$PKG_WORKDIR"

#Delete a nobody's password (make it empty):
passwd -d nobody

# Allow the nobody passwordless sudo:
printf 'nobody ALL=(ALL) ALL\n' | tee -a /etc/sudoers

# change workind dir to nobody own:
chown nobody.nobody "$PKG_WORKDIR"
#===========================================================================================
# INFO: https://wiki.archlinux.org/index.php/Makepkg
cd "$PKG_WORKDIR" || die "ERROR: Directory don't exist: $PKG_WORKDIR"
#------------------

# Dep compile/install sample:
# libcpuid-git  https://aur.archlinux.org/packages/libcpuid-git/
#sudo -u nobody git clone https://aur.archlinux.org/libcpuid-git.git
#cd libcpuid-git
#sudo -u nobody makepkg --syncdeps --noconfirm
#echo "* All files HERE: $(ls ./)"
#pacman --noconfirm -U ./*.pkg.tar*
#mv *.pkg.tar* ../ || die "ERROR: Can't create the libcpuid-git package"
#cd ..
#------------------

# pcsx2-git  https://aur.archlinux.org/packages/pcsx2-git/
#sudo -u nobody git clone https://aur.archlinux.org/pcsx2-git.git
sudo -u nobody mkdir pcsx2-git
sudo -u nobody cat > "./pcsx2-git/PKGBUILD" << EOF
# Maintainer: Maxime Gauduin <alucryd@archlinux.org>
# Contributor: josephgbr <rafael.f.f1@gmail.com>
# Contributor: Themaister <maister@archlinux.us>

pkgname=pcsx2-git
pkgver=1.5.0.r3365-g8550cb9b1
pkgrel=1
pkgdesc='A Sony PlayStation 2 emulator'
arch=(x86_64)
url=https://www.pcsx2.net
license=(
  GPL2
  GPL3
  LGPL2.1
  LGPL3
)
depends=(
  lib32-glew
  lib32-libaio
  lib32-libcanberra
  lib32-libjpeg-turbo
  lib32-libpcap
  lib32-libpulse
  lib32-portaudio
  lib32-sdl2
  lib32-soundtouch
  lib32-wxgtk2
)
makedepends=(
  gcc
  cmake
  git
  png++
  xorgproto
)
provides=(pcsx2)
conflicts=(pcsx2)
source=(git+https://github.com/PCSX2/pcsx2.git)
sha256sums=(SKIP)

pkgver() {
  cd pcsx2

  git describe --tags | sed 's/^v//; s/-dev//; s/-/.r/; s/-g/./'
}

prepare() {
  if [[ -d build ]]; then
    rm -rf build
  fi
  mkdir build

  # Disable ZeroGS and ZZOgl-PG
  rm -rf pcsx2/plugins/{zerogs,zzogl-pg}
}

build() {
  cd build

  export CC=gcc
  export CXX=g++

  cmake ../pcsx2 \
    -DCMAKE_TOOLCHAIN_FILE=cmake/linux-compiler-i386-multilib.cmake \\
    -DCMAKE_BUILD_TYPE=Release \\
    -DCMAKE_INSTALL_PREFIX=/usr \\
    -DCMAKE_LIBRARY_PATH=/usr/lib32 \\
    -DPLUGIN_DIR=/usr/lib32/pcsx2 \\
    -DGAMEINDEX_DIR=/usr/share/pcsx2 \\
    -DEXTRA_PLUGINS=ON \\
    -DREBUILD_SHADER=ON \\
    -DGLSL_API=ON \\
    -DPACKAGE_MODE=ON \\
    -DXDG_STD=ON \\
    -DDISABLE_ADVANCE_SIMD=ON
  make
}

package() {
  make DESTDIR="\${pkgdir}" -C build install
}

# vim: ts=2 sw=2 et:

EOF

sudo -u nobody cat > "./pcsx2-git/makepkg.i686.conf" << EOF
#
# /etc/makepkg.conf
#

#########################################################################
# SOURCE ACQUISITION
#########################################################################
#
#-- The download utilities that makepkg should use to acquire sources
#  Format: 'protocol::agent'
DLAGENTS=('file::/usr/bin/curl -gqC - -o %o %u'
          'ftp::/usr/bin/curl -gqfC - --ftp-pasv --retry 3 --retry-delay 3 -o %o %u'
          'http::/usr/bin/curl -gqb "" -fLC - --retry 3 --retry-delay 3 -o %o %u'
          'https::/usr/bin/curl -gqb "" -fLC - --retry 3 --retry-delay 3 -o %o %u'
          'rsync::/usr/bin/rsync --no-motd -z %u %o'
          'scp::/usr/bin/scp -C %u %o')
# Other common tools:
# /usr/bin/snarf
# /usr/bin/lftpget -c
# /usr/bin/wget
#-- The package required by makepkg to download VCS sources
#  Format: 'protocol::package'
VCSCLIENTS=('bzr::bzr'
            'git::git'
            'hg::mercurial'
            'svn::subversion')

#########################################################################
# ARCHITECTURE, COMPILE FLAGS
#########################################################################
#
CARCH="i686"
CHOST="i686-unknown-linux-gnu"

#-- Compiler and Linker Flags
#CPPFLAGS="-D_FORTIFY_SOURCE=2"
CFLAGS="-m32 -march=prescott -mssse3 -msse4.1 -msse4.2 -O2 -pipe -fstack-protector-strong"
CXXFLAGS="\${CFLAGS}"
LDFLAGS="-m32 -Wl,-O1,--sort-common,--as-needed,-z,relro"

MAKEFLAGS="-j2"

##-- Debugging flags
#DEBUG_CFLAGS="-g -fvar-tracking-assignments"
#DEBUG_CXXFLAGS="-g -fvar-tracking-assignments"

#########################################################################
# BUILD ENVIRONMENT
#########################################################################
#
# Defaults: BUILDENV=(!distcc !color !ccache check !sign)
#  A negated environment option will do the opposite of the comments below.
#
#-- distcc:   Use the Distributed C/C++/ObjC compiler
#-- color:    Colorize output messages
#-- ccache:   Use ccache to cache compilation
#-- check:    Run the check() function if present in the PKGBUILD
#-- sign:     Generate PGP signature file
#
BUILDENV=(!distcc color !ccache check !sign)
#
#-- If using DistCC, your MAKEFLAGS will also need modification. In addition,
#-- specify a space-delimited list of hosts running in the DistCC cluster.
#DISTCC_HOSTS=""
#
#-- Specify a directory for package building.
#BUILDDIR=/tmp/makepkg

#########################################################################
# GLOBAL PACKAGE OPTIONS
#   These are default values for the options=() settings
#########################################################################
#
# Default: OPTIONS=(!strip docs libtool staticlibs emptydirs !zipman !purge !debug)
#  A negated option will do the opposite of the comments below.
#
#-- strip:      Strip symbols from binaries/libraries
#-- docs:       Save doc directories specified by DOC_DIRS
#-- libtool:    Leave libtool (.la) files in packages
#-- staticlibs: Leave static library (.a) files in packages
#-- emptydirs:  Leave empty directories in packages
#-- zipman:     Compress manual (man and info) pages in MAN_DIRS with gzip
#-- purge:      Remove files specified by PURGE_TARGETS
#-- debug:      Add debugging flags as specified in DEBUG_* variables
#
OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge !debug)
#-- File integrity checks to use. Valid: md5, sha1, sha256, sha384, sha512
INTEGRITY_CHECK=(md5)
#-- Options to be used when stripping binaries. See \'man strip\' for details.
STRIP_BINARIES="--strip-all"
#-- Options to be used when stripping shared libraries. See \'man strip\' for details.
STRIP_SHARED="--strip-unneeded"
#-- Options to be used when stripping static libraries. See \'man strip\' for details.
STRIP_STATIC="--strip-debug"
#-- Manual (man and info) directories to compress (if zipman is specified)
MAN_DIRS=({usr{,/local}{,/share},opt/*}/{man,info})
#-- Doc directories to remove (if !docs is specified)
DOC_DIRS=(usr/{,local/}{,share/}{doc,gtk-doc} opt/*/{doc,gtk-doc})
#-- Files to be removed from all packages (if purge is specified)
PURGE_TARGETS=(usr/{,share}/info/dir .packlist *.pod)
#-- Directory to store source code in for debug packages
DBGSRCDIR="/usr/src/debug"
#########################################################################
# PACKAGE OUTPUT
#########################################################################
#
# Default: put built package and cached source in build directory
#
#-- Destination: specify a fixed directory where all packages will be placed
#PKGDEST=/home/packages
#-- Source cache: specify a fixed directory where source files will be cached
#SRCDEST=/home/sources
#-- Source packages: specify a fixed directory where all src packages will be placed
#SRCPKGDEST=/home/srcpackages
#-- Log files: specify a fixed directory where all log files will be placed
#LOGDEST=/home/makepkglogs
#-- Packager: name/email of the person or organization building packages
#PACKAGER="John Doe <john@doe.com>"
PACKAGER="DanielDevBR"
#-- Specify a key to use for package signing
#GPGKEY=""
#########################################################################
# COMPRESSION DEFAULTS
#########################################################################
#
COMPRESSGZ=(gzip -c -f -n)
COMPRESSBZ2=(bzip2 -c -f)
COMPRESSXZ=(xz -c -z -)
COMPRESSZST=(zstd -c -z -q -)
COMPRESSLRZ=(lrzip -q)
COMPRESSLZO=(lzop -q)
COMPRESSZ=(compress -c -f)
COMPRESSLZ4=(lz4 -q)
COMPRESSLZ=(lzip -c -f)
#########################################################################
# EXTENSION DEFAULTS
#########################################################################
#
PKGEXT='.pkg.tar.xz'
SRCEXT='.src.tar.gz'

EOF

#-------
cd pcsx2-git
sudo -u nobody makepkg --syncdeps --noconfirm
echo "* All files HERE: $(ls ./)"
mv *.pkg.tar* ../ || die "ERROR: Can't create the pcsx2-git package"
cd ..
#------------------

mv *.pkg.tar* ../"$PCSX2_WORKDIR"

cd ..
rm -rf "$PKG_WORKDIR"
#===========================================================================================

cd "$PCSX2_WORKDIR" || die "ERROR: Directory don't exist: $PCSX2_WORKDIR"

# Add a dependency library, such as freetype font library
dependencys=$(pactree -s -u pcsx2 |grep lib32 | xargs)

mkdir cache

pacman -Scc --noconfirm
pacman -Syw --noconfirm --cachedir cache lib32-nvidia-utils lib32-nvidia-390xx-utils lib32-alsa-lib lib32-alsa-plugins lib32-fontconfig lib32-freetype2 lib32-gcc-libs lib32-gettext lib32-giflib lib32-glu lib32-libjpeg-turbo lib32-libjpeg6-turbo lib32-libpng lib32-libpng12 lib32-libsm lib32-libxcomposite lib32-libxcursor lib32-libxdamage lib32-libxi lib32-libxml2 lib32-libxmu lib32-libxrandr lib32-libxslt lib32-libxxf86vm lib32-mesa lib32-mesa-libgl lib32-openal lib32-sdl2 lib32-libdrm lib32-libva lib32-portaudio lib32-sdl2 lib32-sdl2_image lib32-sdl2_mixer lib32-sdl2_ttf lib32-virtualgl lib32-ladspa lib32-libao lib32-libpulse lib32-libcanberra-pulse lib32-glew lib32-mesa-demos lib32-libxinerama lib32-vulkan-icd-loader lib32-vulkan-intel lib32-vulkan-radeon lib32-gtk2 lib32-wxgtk2 $dependencys || die "ERROR: Some packages not found!!!"
#---------------------------------

#Save nvidia packages for later
mv ./cache/lib32-nvidia-utils* ../
mv ./cache/lib32-nvidia-390xx-utils* ../

# Remove non lib32 pkgs before extracting (save pcsx2 package):
#mv ./cache/pcsx2* ./
#echo "All files in ./cache: $(ls ./cache)"
find ./cache -type f ! -name "lib32*" -exec rm {} \; -exec echo "Removing: {}" \;
#find ./cache -type f -name "*x86_64*" -exec rm {} \; -exec echo "Removing: {}" \; #don't work because the name of lib32 multilib packages have the x86_64 too
#mv ./pcsx2* ./cache/
echo "All files in ./cache: $(ls ./cache)"

# Add the archlinux32 pentium4 packages (some deps):
#get_archlinux32_pkgs ./cache/ gst-libav libwbclient tevent talloc ldb libbsd avahi libarchive smbclient libsoxr libssh vid.stab l-smash libtirpc
get_archlinux32_pkgs ./cache/ gtk-engines gtk-engine-murrine
#---------------------------------

# extracting *tar.xz *tar.zst...
find ./cache -name '*tar.xz' -exec tar --warning=no-unknown-keyword -xJf {} \;
find ./cache -name '*tar.zst' -exec tar --warning=no-unknown-keyword --zstd -xf {} \;

# Install vulkan tools:
wget -nv -c https://github.com/ferion11/libsutil/releases/download/vulkan32_tools_v1.0/vkcube32
wget -nv -c https://github.com/ferion11/libsutil/releases/download/vulkan32_tools_v1.0/vkcubepp32
wget -nv -c https://github.com/ferion11/libsutil/releases/download/vulkan32_tools_v1.0/vulkaninfo32
chmod +x vkcube32 vkcubepp32 vulkaninfo32
mv -n vkcube32 usr/bin
mv -n vkcubepp32 usr/bin
mv -n vulkaninfo32 usr/bin
#----------------------------------------------

# PCSX2_WORKDIR cleanup
rm -rf cache; rm -rf include; rm usr/lib32/{*.a,*.o}; rm -rf usr/lib32/pkgconfig; rm -rf share/man; rm -rf usr/include; rm -rf usr/share/{applications,doc,emacs,gtk-doc,java,licenses,man,info,pkgconfig}; rm usr/lib32/locale
rm -rf boot; rm -rf dev; rm -rf home; rm -rf mnt; rm -rf opt; rm -rf proc; rm -rf root; rm sbin; rm -rf srv; rm -rf sys; rm -rf tmp; rm -rf var
rm -rf usr/src; rm -rf usr/share; rm usr/sbin; rm -rf usr/local; rm usr/lib/{*.a,*.o}
#---------------------------------

# Install pcsx2 after clean (to keep icons, themes...)
find ./ -maxdepth 1 -mindepth 1 -name 'pcsx2*tar.xz' -exec tar --warning=no-unknown-keyword -xJf {} \;
find ./ -maxdepth 1 -mindepth 1 -name 'pcsx2*tar.zst' -exec tar --warning=no-unknown-keyword --zstd -xf {} \;
rm ./pcsx2*
#===========================================================================================

# fix broken link libglx_indirect and others
rm usr/lib32/libGLX_indirect.so.0
ln -s libGLX_mesa.so.0 libGLX_indirect.so.0
mv -n libGLX_indirect.so.0 usr/lib32

rm usr/lib/libGLX_indirect.so.0
ln -s ../lib32/libGLX_mesa.so.0 libGLX_indirect.so.0
mv -n libGLX_indirect.so.0 usr/lib
#--------

rm usr/lib32/libkeyutils.so
ln -s libkeyutils.so.1 libkeyutils.so
mv -n libkeyutils.so usr/lib32

rm usr/lib/libkeyutils.so
ln -s ../lib32/libkeyutils.so.1 libkeyutils.so
mv -n libkeyutils.so usr/lib
#--------

# workaround some of libs
ln -s libva.so libva.so.1
ln -s libva-drm.so libva-drm.so.1
ln -s libva-x11.so libva-x11.so.1
mv -n libva.so.1 usr/lib32
mv -n libva-drm.so.1 usr/lib32
mv -n libva-x11.so.1 usr/lib32
#--------

# Find and link all gtk2 engines:
if [ -d "usr/lib/gtk-2.0/2.10.0/engines" ]; then
	for lib_i in $(find "usr/lib/gtk-2.0/2.10.0/engines" -name *.so -exec basename {} \;); do
		ln -s ../../../../lib/gtk-2.0/2.10.0/engines/"$lib_i" "$lib_i"
		mv "$lib_i" usr/lib32/gtk-2.0/2.10.0/engines/
	done
fi

#PCSX2 Langs
ln -s ../share/locale Langs
mv Langs usr/lib32
#===========================================================================================

# Disable internal PulseAudio
rm etc/asound.conf; rm -rf etc/modprobe.d/alsa.conf; rm -rf etc/pulse
cd ..
#===========================================================================================

# Get AppImage and setting $PCSX2_WORKDIR:
wget -nv -c "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" -O  appimagetool.AppImage
chmod +x appimagetool.AppImage

chmod +x AppRun

cp AppRun $PCSX2_WORKDIR
cp resource/* $PCSX2_WORKDIR
#===========================================================================================

# Nvidia variation with lib32-nvidia-utils:
PCSX2_NVIDIA_WORKDIR="pcsx2_nvidia_version"
cp -rp "$PCSX2_WORKDIR" "$PCSX2_NVIDIA_WORKDIR"
cd "$PCSX2_NVIDIA_WORKDIR" || die "ERROR: Directory don't exist: $PCSX2_NVIDIA_WORKDIR"
mv ../lib32-nvidia-utils* ./

# Remove opensource nouveau:
rm -rf usr/lib32/dri/nouveau*
rm -rf usr/lib32/libdrm_nouveau*

# extracting *tar.xz and *tar.zst
find ./ -maxdepth 1 -mindepth 1 -name '*tar.xz' -exec tar --warning=no-unknown-keyword -xJf {} \;
find ./ -maxdepth 1 -mindepth 1 -name '*tar.zst' -exec tar --warning=no-unknown-keyword --zstd -xf {} \;

rm -rf lib32-nvidia-utils*
cd ..
#===========================================================================================

# Nvidia Legacy variation with lib32-nvidia-390xx-utils:
PCSX2_NVIDIA_LEGACY_WORKDIR="pcsx2_nvidia_legacy_version"
cp -rp "$PCSX2_WORKDIR" "$PCSX2_NVIDIA_LEGACY_WORKDIR"
cd "$PCSX2_NVIDIA_LEGACY_WORKDIR" || die "ERROR: Directory don't exist: $PCSX2_NVIDIA_LEGACY_WORKDIR"
mv ../lib32-nvidia-390xx-utils* ./

# Remove opensource nouveau:
rm -rf usr/lib32/dri/nouveau*
rm -rf usr/lib32/libdrm_nouveau*

# extracting *tar.xz *tar.zst...
find ./ -maxdepth 1 -mindepth 1 -name '*tar.xz' -exec tar --warning=no-unknown-keyword -xJf {} \;
find ./ -maxdepth 1 -mindepth 1 -name '*tar.zst' -exec tar --warning=no-unknown-keyword --zstd -xf {} \;

rm -rf lib32-nvidia-390xx-utils*
cd ..
#===========================================================================================

# AppImage generation:
./appimagetool.AppImage --appimage-extract

export ARCH=x86_64; squashfs-root/AppRun -v $PCSX2_WORKDIR -u 'gh-releases-zsync|ferion11|pcsx2_git_Appimage|continuous|pcsx2-1.5.0dev-*arch*.AppImage.zsync' pcsx2-1.5.0dev-${ARCH}.AppImage
export ARCH=x86_64; squashfs-root/AppRun -v $PCSX2_NVIDIA_WORKDIR -u 'gh-releases-zsync|ferion11|pcsx2_git_Appimage|continuous|pcsx2_NVIDIA-1.5.0dev-*arch*.AppImage.zsync' pcsx2_NVIDIA-1.5.0dev-${ARCH}.AppImage
export ARCH=x86_64; squashfs-root/AppRun -v $PCSX2_NVIDIA_LEGACY_WORKDIR -u 'gh-releases-zsync|ferion11|pcsx2_git_Appimage|continuous|pcsx2_NVIDIA390xx-1.5.0dev-*arch*.AppImage.zsync' pcsx2_NVIDIA390xx-1.5.0dev-${ARCH}.AppImage
