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
echo "DEBUG: starting and configuring pacmam"
# pacman-key: need it
#pacman -S --noconfirm gawk

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
sed -i 's/^PKGEXT\s*=.*/PKGEXT=".pkg.tar"/' /etc/makepkg.conf
sed -i 's/^SRCEXT\s*=.*/SRCEXT=".src.tar"/' /etc/makepkg.conf

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

# workaround one bug: https://bugzilla.redhat.com/show_bug.cgi?id=1773148
echo "Set disable_coredump false" >> /etc/sudo.conf

echo "DEBUG: updating pacmam keys"
pacman -Syy && pacman -S archlinuxcn-keyring

echo "DEBUG: pacmam sync"
pacman -Syy

echo "DEBUG: pacmam install basic tools"
#Add "gcc lib32-gcc-libs" for compile in the list:
pacman -S --noconfirm wget base-devel multilib-devel pacman-contrib git tar grep zstd xz
#===========================================================================================

echo "DEBUG: git-describe-remote.sh getting info"
cat > "git-describe-remote.sh" << EOF
#!/usr/bin/awk -f
BEGIN {
  if (ARGC != 2) {
    print "git-describe-remote.awk https://github.com/stedolan/jq"
    exit
  }
  FS = "[ /^]+"
  while ("git ls-remote " ARGV[1] "| sort -Vk2" | getline) {
    if (!sha)
      sha = substr(\$0, 1, 9)
    tag = \$3
  }
  while ("curl -s " ARGV[1] "/releases/tag/" tag | getline)
    if (\$3 ~ "commits")
      com = \$2
  printf com ? "%s-%s-g%s\n" : "%s\n", tag, com, sha
}

EOF
chmod +x git-describe-remote.sh

FULL=$(./git-describe-remote.sh https://github.com/PCSX2/pcsx2)

ARCHV=$(echo $FULL | sed 's/^v//; s/-dev//; s/-/.r/; s/-g/./')

VERSION=$(echo $FULL | cut -d- -f1)
RELEASE=$(echo $FULL | cut -d- -f3)
GITHASH=$(echo $FULL | cut -d- -f4)

echo "=== VERSIONS ==="
echo "FULL: $FULL"
echo "ARCHV: $ARCHV"
echo "VERSION: $VERSION"
echo "RELEASE: $RELEASE"
echo "GITHASH: $GITHASH"

rm -rf git-describe-remote.sh
#===========================================================================================

echo "DEBUG: making packages"

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

echo "DEBUG: making nvidia old package"
# INFO: https://wiki.archlinux.org/index.php/Makepkg
cd "$PKG_WORKDIR" || die "ERROR: Directory don't exist: $PKG_WORKDIR"
#------------------

# lib32-nvidia-340xx-utils from https://aur.archlinux.org/packages/lib32-nvidia-340xx-utils/
sudo -u nobody git clone https://aur.archlinux.org/lib32-nvidia-340xx-utils.git
cd  lib32-nvidia-340xx-utils
sudo -u nobody makepkg --syncdeps --noconfirm
echo "* All files HERE: $(ls ./)"
mv lib32-nvidia-340xx-utils*.pkg.tar ../ || die "ERROR: Can't create the lib32-nvidia-340xx-utils package"
cd ..
#------------------

echo "DEBUG: making pcsx2 package"
# pcsx2-git  https://aur.archlinux.org/packages/pcsx2-git/
#sudo -u nobody git clone https://aur.archlinux.org/pcsx2-git.git
sudo -u nobody mkdir pcsx2-git
sudo -u nobody cat > "./pcsx2-git/PKGBUILD" << EOF
# Maintainer: Maxime Gauduin <alucryd@archlinux.org>
# Contributor: josephgbr <rafael.f.f1@gmail.com>
# Contributor: Themaister <maister@archlinux.us>

pkgname=pcsx2-git
pkgver=$ARCHV
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
  patch -p0 < /tmp/evar.patch

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
sudo -u nobody chmod a+rw "./pcsx2-git/PKGBUILD"


echo "================================================"
sudo -u nobody cat > "/tmp/evar.patch" << EOF
diff -rcN pcsx2/pcsx2/gui/AppConfig.cpp pcsx2_new/pcsx2/gui/AppConfig.cpp
*** pcsx2/pcsx2/gui/AppConfig.cpp	2020-02-23 23:38:36.939457634 -0300
--- pcsx2_new/pcsx2/gui/AppConfig.cpp	2020-02-23 23:31:34.209485289 -0300
***************
*** 173,178 ****
--- 173,180 ----
  
  	wxDirName GetProgramDataDir()
  	{
+ 		char * evar_curr = getenv( "PCSX2_GAMEINDEX_DIR" );
+ 		if ( evar_curr != NULL ) return wxDirName( evar_curr );
  #ifndef GAMEINDEX_DIR_COMPILATION
  		return AppRoot();
  #else
***************
*** 221,226 ****
--- 223,230 ----
  
  	wxDirName GetPlugins()
  	{
+ 		char * evar_curr = getenv( "PCSX2_PLUGIN_DIR" );
+ 		if ( evar_curr != NULL ) return wxDirName( evar_curr );
  		// Each linux distributions have his rules for path so we give them the possibility to
  		// change it with compilation flags. -- Gregory
  #ifndef PLUGIN_DIR_COMPILATION

EOF

#-------
cd pcsx2-git
sudo -u nobody makepkg --syncdeps --noconfirm
echo "* All files HERE: $(ls ./)"
mv *.pkg.tar ../ || die "ERROR: Can't create the pcsx2-git package"
cd ..
#------------------

mv *.pkg.tar ../"$PCSX2_WORKDIR"

cd ..
rm -rf "$PKG_WORKDIR"
#===========================================================================================

cd "$PCSX2_WORKDIR" || die "ERROR: Directory don't exist: $PCSX2_WORKDIR"

# Add a dependency library, such as freetype font library
dependencys=$(pactree -s -u pcsx2-git |grep lib32 | xargs)

mkdir cache

pacman -Scc --noconfirm
pacman -Syw --noconfirm --cachedir cache lib32-nvidia-utils lib32-nvidia-390xx-utils lib32-alsa-lib lib32-alsa-plugins lib32-fontconfig lib32-freetype2 lib32-gcc-libs lib32-gettext lib32-giflib lib32-glu lib32-libjpeg-turbo lib32-libjpeg6-turbo lib32-libpng lib32-libpng12 lib32-libsm lib32-libxcomposite lib32-libxcursor lib32-libxdamage lib32-libxi lib32-libxml2 lib32-libxmu lib32-libxrandr lib32-libxslt lib32-libxxf86vm lib32-mesa lib32-mesa-libgl lib32-sdl2 lib32-libdrm lib32-libva lib32-portaudio lib32-sdl2 lib32-sdl2_image lib32-sdl2_mixer lib32-sdl2_ttf lib32-ladspa lib32-libao lib32-libpulse lib32-libcanberra-pulse lib32-glew lib32-mesa-demos lib32-libxinerama lib32-gtk2 lib32-wxgtk2 $dependencys || die "ERROR: Some packages not found!!!"
#---------------------------------

#Save nvidia packages for later
mv ./cache/lib32-nvidia-utils* ../
mv ./cache/lib32-nvidia-390xx-utils* ../
mv ./lib32-nvidia-340xx-utils* ../

# Remove non lib32 pkgs before extracting (save pcsx2 package):
#mv ./cache/pcsx2* ./
#echo "All files in ./cache: $(ls ./cache)"
find ./cache -type f ! -name "lib32*" -exec rm {} \; -exec echo "Removing: {}" \;
#find ./cache -type f -name "*x86_64*" -exec rm {} \; -exec echo "Removing: {}" \; #don't work because the name of lib32 multilib packages have the x86_64 too
#mv ./pcsx2* ./cache/
echo "DEBUG: clean some packages"
rm -rf ./cache/lib32-clang*
rm -rf ./cache/lib32-nvidia-cg-toolkit*
rm -rf ./cache/lib32-ocl-icd*
rm -rf ./cache/lib32-opencl-mesa*
echo "All files in ./cache: $(ls ./cache)"

# Add the archlinux32 pentium4 packages (some deps):
#get_archlinux32_pkgs ./cache/ gst-libav libwbclient tevent talloc ldb libbsd avahi libarchive smbclient libsoxr libssh vid.stab l-smash libtirpc
get_archlinux32_pkgs ./cache/ gtk-engines gtk-engine-murrine
#---------------------------------

# extracting *.pkg.tar.xz *.pkg.tar.zst...
find ./cache -name '*.pkg.tar.xz' -exec tar --warning=no-unknown-keyword -xJf {} \;
find ./cache -name '*.pkg.tar.zst' -exec tar --warning=no-unknown-keyword --zstd -xf {} \;

## Install vulkan tools:
#wget -nv -c https://github.com/ferion11/libsutil/releases/download/vulkan32_tools_v1.0/vkcube32
#wget -nv -c https://github.com/ferion11/libsutil/releases/download/vulkan32_tools_v1.0/vkcubepp32
#wget -nv -c https://github.com/ferion11/libsutil/releases/download/vulkan32_tools_v1.0/vulkaninfo32
#chmod +x vkcube32 vkcubepp32 vulkaninfo32
#mv -n vkcube32 usr/bin
#mv -n vkcubepp32 usr/bin
#mv -n vulkaninfo32 usr/bin
#----------------------------------------------

# PCSX2_WORKDIR cleanup
rm -rf cache; rm -rf include; rm usr/lib32/{*.a,*.o}; rm -rf usr/lib32/pkgconfig; rm -rf share/man; rm -rf usr/include; rm -rf usr/share/{applications,doc,emacs,gtk-doc,java,licenses,man,info,pkgconfig}; rm usr/lib32/locale
rm -rf boot; rm -rf dev; rm -rf home; rm -rf mnt; rm -rf opt; rm -rf proc; rm -rf root; rm sbin; rm -rf srv; rm -rf sys; rm -rf tmp; rm -rf var
rm -rf usr/src; rm -rf usr/share; rm usr/sbin; rm -rf usr/local; rm usr/lib/{*.a,*.o}
#---------------------------------

# Install pcsx2 after clean (to keep icons, themes...)
find ./ -maxdepth 1 -mindepth 1 -name 'pcsx2*.pkg.tar' -exec tar --warning=no-unknown-keyword -xf {} \;
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
find ./ -maxdepth 1 -mindepth 1 -name '*.pkg.tar.xz' -exec tar --warning=no-unknown-keyword -xJf {} \;
find ./ -maxdepth 1 -mindepth 1 -name '*.pkg.tar.zst' -exec tar --warning=no-unknown-keyword --zstd -xf {} \;

rm -rf lib32-nvidia-utils*
cd ..
#===========================================================================================

# Nvidia Legacy variation with lib32-nvidia-390xx-utils:
PCSX2_NVIDIA_390xx_WORKDIR="pcsx2_nvidia_390xx_version"
cp -rp "$PCSX2_WORKDIR" "$PCSX2_NVIDIA_390xx_WORKDIR"
cd "$PCSX2_NVIDIA_390xx_WORKDIR" || die "ERROR: Directory don't exist: $PCSX2_NVIDIA_390xx_WORKDIR"
mv ../lib32-nvidia-390xx-utils* ./

# Remove opensource nouveau:
rm -rf usr/lib32/dri/nouveau*
rm -rf usr/lib32/libdrm_nouveau*

# extracting *.pkg.tar.xz *.pkg.tar.zst...
find ./ -maxdepth 1 -mindepth 1 -name '*.pkg.tar.xz' -exec tar --warning=no-unknown-keyword -xJf {} \;
find ./ -maxdepth 1 -mindepth 1 -name '*.pkg.tar.zst' -exec tar --warning=no-unknown-keyword --zstd -xf {} \;

rm -rf lib32-nvidia-390xx-utils*
cd ..
#===========================================================================================

# Nvidia Legacy variation with lib32-nvidia-340xx-utils:
PCSX2_NVIDIA_340xx_WORKDIR="pcsx2_nvidia_340xx_version"
cp -rp "$PCSX2_WORKDIR" "$PCSX2_NVIDIA_340xx_WORKDIR"
cd "$PCSX2_NVIDIA_340xx_WORKDIR" || die "ERROR: Directory don't exist: $PCSX2_NVIDIA_340xx_WORKDIR"
mv ../lib32-nvidia-340xx-utils* ./

# Remove opensource nouveau:
rm -rf usr/lib32/dri/nouveau*
rm -rf usr/lib32/libdrm_nouveau*

# extracting *.pkg.tar ...
find ./ -maxdepth 1 -mindepth 1 -name '*.pkg.tar' -exec tar --warning=no-unknown-keyword -xf {} \;

rm -rf lib32-nvidia-340xx-utils*
cd ..
#===========================================================================================

# AppImage generation:
./appimagetool.AppImage --appimage-extract

export ARCH=x86_64; squashfs-root/AppRun -v $PCSX2_WORKDIR -u 'gh-releases-zsync|ferion11|pcsx2_Appimage|continuous|pcsx2-${VERSION}-dev-${RELEASE}-${GITHASH}-*arch*.AppImage.zsync' pcsx2-${VERSION}-dev-${RELEASE}-${GITHASH}-${ARCH}.AppImage
export ARCH=x86_64; squashfs-root/AppRun -v $PCSX2_NVIDIA_WORKDIR -u 'gh-releases-zsync|ferion11|pcsx2_Appimage|continuous|pcsx2_NVIDIA-${VERSION}-dev-${RELEASE}-${GITHASH}-*arch*.AppImage.zsync' pcsx2_NVIDIA-${VERSION}-dev-${RELEASE}-${GITHASH}-${ARCH}.AppImage
export ARCH=x86_64; squashfs-root/AppRun -v $PCSX2_NVIDIA_390xx_WORKDIR -u 'gh-releases-zsync|ferion11|pcsx2_Appimage|continuous|pcsx2_NVIDIA390xx-${VERSION}-dev-${RELEASE}-${GITHASH}-*arch*.AppImage.zsync' pcsx2_NVIDIA390xx-${VERSION}-dev-${RELEASE}-${GITHASH}-${ARCH}.AppImage
export ARCH=x86_64; squashfs-root/AppRun -v $PCSX2_NVIDIA_340xx_WORKDIR -u 'gh-releases-zsync|ferion11|pcsx2_Appimage|continuous|pcsx2_NVIDIA340xx-${VERSION}-dev-${RELEASE}-${GITHASH}-*arch*.AppImage.zsync' pcsx2_NVIDIA340xx-${VERSION}-dev-${RELEASE}-${GITHASH}-${ARCH}.AppImage

echo "Packing tar result file..."
rm -rf appimagetool.AppImage
tar cvf result.tar *.AppImage *.zsync
echo "* result.tar size: $(du -hs result.tar)"
