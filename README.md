# PCSX2_Appimage

PCSX2 Appimage that include all 32bits deps, for all linux 64bits (include no-multilib pure 64bits).
If you want the PCSX2-git, then get it [HERE][PCSX2_git]

#### 1- Download "pcsx2-1.4.0-x86_64.AppImage" [HERE][PCSX2]
If you use the proprietary NVIDIA driver, you can download the respective version instead.
#### 2- Make executable:
- `$ chmod +x pcsx2-1.4.0-x86_64.AppImage`
#### 3- Run it:
- `$ ./pcsx2-1.4.0-x86_64.AppImage`
#### 4- To plugins work:
- `Change the plugins default path to "/tmp/.mount_pcsx2-??????/usr/lib32/pcsx2/"`
#### Optional 1- To test the OpenGL of your video card:
- `$ ./pcsx2-1.4.0-x86_64.AppImage glxinfo32`
- `$ ./pcsx2-1.4.0-x86_64.AppImage glxgears32 -info`
- `$ ./pcsx2-1.4.0-x86_64.AppImage shape32`
- `$ ./pcsx2-1.4.0-x86_64.AppImage shape32`
- `$ ./pcsx2-1.4.0-x86_64.AppImage glxspheres32`
#### Optional 2- You can use PRIME too:
- `$ DRI_PRIME=1 ./pcsx2-1.4.0-x86_64.AppImage glxgears32 -info`

[PCSX2_git]: https://github.com/ferion11/PCSX2_git_Appimage/releases/tag/continuous "HERE"
[PCSX2]: https://github.com/ferion11/PCSX2_Appimage/releases/tag/continuous "HERE"
