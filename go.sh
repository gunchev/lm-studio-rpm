#!/usr/bin/env bash

# https://lmstudio.ai/download/latest/linux/x64?format=deb
_DEB=LM-Studio-0.4.8-1-x64.deb
LM-Studio-0.4.8-1-x64.deb

# dpkg-deb --info "$DEB" control 2>/dev/null
# dpkg-deb --info "$DEB" conffiles 2>/dev/null
# dpkg-deb --fsys-tarfile "$DEB" | tar tf -
# dpkg-deb --info "$DEB" postinst 2>/dev/null
# dpkg-deb --info "$DEB" postrm 2>/dev/null
# dpkg-deb --info "$DEB" preinst 2>/dev/null
# dpkg-deb --info "$DEB" prerm 2>/dev/null
mkdir lm-studio
chmod 755 lm-studio
dpkg-deb -x LM-Studio-0.4.8-1-x64.deb lm-studio

# Fix the 0x0 directory name, it is 1024x1024
if test -d ./lm-studio/usr/share/icons/hicolor/0x0; then
	mv ./lm-studio/usr/share/icons/hicolor/0x0 ./lm-studio/usr/share/icons/hicolor/1024x1024
fi

rpmbuild --buildroot="$PWD/lm-studio" -bb --target "$(uname -m)" 'lm-studio-0.4.8+1-1.spec'

rm -r ./lm-studio
