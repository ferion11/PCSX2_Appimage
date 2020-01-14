#!/bin/bash
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
			echo "* ERROR get_archlinux32_pkg: Fail to download: $1"
			return 1;
		fi
	fi
	
	wget -nv -c $REAL_LINK -P $2
}

get_archlinux32_pkgs() {
	#Usage: get_archlinux32_pkgs [dest] pack1 pack2...
	#https://mirror.datacenter.by/pub/archlinux32/$arch/$repo/"
	
	rm -rf tmp_pentium4_core_html
	rm -rf tmp_pentium4_core_html
	wget -nv -c https://mirror.datacenter.by/pub/archlinux32/pentium4/core/ -O tmp_pentium4_core_html
	wget -nv -c https://mirror.datacenter.by/pub/archlinux32/pentium4/extra/ -O tmp_pentium4_extra_html
	
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
				echo "ERROR get_archlinux32_pkgs: Package don't found: $current_pkg"
			fi
		fi
	done
	
	rm -rf tmp_pentium4_core_html
	rm -rf tmp_pentium4_extra_html
}
#=========================
#Initializing the keyring requires entropy
pacman-key --init

# Enable Multilib
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

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
pacman -S --noconfirm wget file pacman-contrib tar grep sed zstd xz

#===========================================================================================
# Get pcsx2
# using the package
mkdir "$PCSX2_WORKDIR"

#===========================================================================================
cd "$PCSX2_WORKDIR" || die "ERROR: Directory don't exist: $PCSX2_WORKDIR"

# Add a dependency library, such as freetype font library
dependencys=$(pactree -s -u pcsx2 |grep lib32 | xargs)

mkdir cache

pacman -Scc --noconfirm
pacman -Syw --noconfirm --cachedir cache pcsx2 lib32-alsa-lib lib32-alsa-plugins lib32-fontconfig lib32-freetype2 lib32-gcc-libs lib32-gettext lib32-giflib lib32-glu lib32-libjpeg-turbo lib32-libjpeg6-turbo lib32-libpng lib32-libpng12 lib32-libsm lib32-libxcomposite lib32-libxcursor lib32-libxdamage lib32-libxi lib32-libxml2 lib32-libxmu lib32-libxrandr lib32-libxslt lib32-libxxf86vm lib32-mesa lib32-mesa-libgl lib32-openal lib32-sdl2 lib32-libdrm lib32-libva lib32-portaudio lib32-sdl2 lib32-sdl2_image lib32-sdl2_mixer lib32-sdl2_ttf lib32-virtualgl lib32-ladspa lib32-libao lib32-libpulse lib32-libcanberra-pulse lib32-glew lib32-mesa-demos lib32-libxinerama lib32-vulkan-icd-loader lib32-vulkan-intel lib32-vulkan-radeon lib32-gtk2 lib32-wxgtk2 $dependencys || die "ERROR: Some packages not found!!!"
#---------------------------------

# Remove non lib32 pkgs before extracting (save pcsx2 package):
mv ./cache/pcsx2* ./
#echo "All files in ./cache: $(ls ./cache)"
find ./cache -type f ! -name "lib32*" -exec rm {} \; -exec echo "Removing: {}" \;
#find ./cache -type f -name "*x86_64*" -exec rm {} \; -exec echo "Removing: {}" \; #don't work because the name of lib32 multilib packages have the x86_64 too
#mv ./pcsx2* ./cache/
echo "All files in ./cache: $(ls ./cache)"

# Add the archlinux32 pentium4 packages (some deps):
#get_archlinux32_pkgs ./cache/ gst-libav libwbclient tevent talloc ldb libbsd avahi libarchive smbclient libsoxr libssh vid.stab l-smash libtirpc
#---------------------------------

# extracting *tar.xz...
find ./cache -name '*tar.xz' -exec tar --warning=no-unknown-keyword -xJf {} \;

# extracting *tar.zst...
find ./cache -name '*tar.zst' -exec tar --warning=no-unknown-keyword --zstd -xf {} \;
#---------------------------------

# PCSX2_WORKDIR cleanup
rm -rf cache; rm -rf include; rm usr/lib32/{*.a,*.o}; rm -rf usr/lib32/pkgconfig; rm -rf share/man; rm -rf usr/include; rm -rf usr/share/{applications,doc,emacs,gtk-doc,java,licenses,man,info,pkgconfig}; rm usr/lib32/locale
rm -rf boot; rm -rf dev; rm -rf home; rm -rf mnt; rm -rf opt; rm -rf proc; rm -rf root; rm sbin; rm -rf srv; rm -rf sys; rm -rf tmp; rm -rf var
rm -rf usr/src; rm -rf usr/share; rm usr/sbin; rm -rf usr/local; rm usr/lib/{*.a,*.o}
#---------------------------------

# Install pcsx2 after clean (to keep icons, themes...)
find ./ -name 'pcsx2*tar.xz' -exec tar --warning=no-unknown-keyword -xJf {} \;
find ./ -name 'pcsx2*tar.zst' -exec tar --warning=no-unknown-keyword --zstd -xf {} \;
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
ln -s libpcap.so libpcap.so.0.8
mv -n libpcap.so.0.8 usr/lib32

ln -s libva.so libva.so.1
ln -s libva-drm.so libva-drm.so.1
ln -s libva-x11.so libva-x11.so.1
mv -n libva.so.1 usr/lib32
mv -n libva-drm.so.1 usr/lib32
mv -n libva-x11.so.1 usr/lib32
#===========================================================================================

# Disable internal PulseAudio
rm etc/asound.conf; rm -rf etc/modprobe.d/alsa.conf; rm -rf etc/pulse

#===========================================================================================
# appimage
cd ..

wget -nv -c "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" -O  appimagetool.AppImage
chmod +x appimagetool.AppImage

chmod +x AppRun

cp AppRun $PCSX2_WORKDIR
cp resource/* $PCSX2_WORKDIR

./appimagetool.AppImage --appimage-extract

export ARCH=x86_64; squashfs-root/AppRun -v $PCSX2_WORKDIR -u 'gh-releases-zsync|ferion11|pcsx2_Appimage|continuous|pcsx2-i386*arch*.AppImage.zsync' pcsx2-i386_${ARCH}-archlinux.AppImage
