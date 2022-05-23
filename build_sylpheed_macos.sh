#!/bin/bash -e

SOURCE_DIR="$(cd "$(dirname "${0}")" && pwd)"
APP_CERT="Developer ID Application: Petr Zhigalov (48535TNTA7)"
NOTARIZE_USERNAME="peter.zhigalov@gmail.com"
NOTARIZE_PASSWORD="@keychain:Notarize: ${NOTARIZE_USERNAME}"

export MACOSX_DEPLOYMENT_TARGET="10.9"
export PATH="${HOME}/.new_local/bin:${HOME}/.local/bin:${PATH}"

# git clone https://gitlab.gnome.org/GNOME/gtk-osx.git
# cd gtk-osx
# # git checkout d4c0796
# ./gtk-osx-setup.sh
# cd ..

# git clone https://gitlab.gnome.org/GNOME/gtk-mac-bundler.git
# cd gtk-mac-bundler
# # git checkout 3770bb6
# make install
# cd ..

# # wget https://download.gimp.org/mirror/pub/gimp/v2.8/osx/gimp-2.8.22-x86_64.dmg
# # hdiutil attach -readonly -noverify -noautofsck -noautoopen -mountpoint G gimp-2.8.22-x86_64.dmg
# # cp -a G/GIMP.app ./
# # hdiutil detach G

# cp -a ~/.config/jhbuildrc-custom ~/.config/jhbuildrc-custom.bak
# cat << EOF > ~/.config/jhbuildrc-custom
# setup_sdk(target="${MACOSX_DEPLOYMENT_TARGET}")
# setup_release()
# append_autogenargs("murrine-engine", 'LDFLAGS="$LDFLAGS -lpixman-1"')
# EOF

# jhbuild bootstrap
# jhbuild build gtk+
# jhbuild build openssl
# jhbuild build tango-icon-theme
# jhbuild build gtk-engines
# jhbuild build murrine-engine
# jhbuild build gtk-mac-integration

# wget https://sylpheed.sraoss.jp/sylpheed/v3.7/sylpheed-3.7.0.tar.bz2
tar -xvpf sylpheed-3.7.0.tar.bz2
cd sylpheed-3.7.0
patch -p1 -i "${SOURCE_DIR}/patches_sylpheed/0001-Update-macos-bundle-project-for-latest-GTK.patch"
patch -p1 -i "${SOURCE_DIR}/patches_sylpheed/0002-Fix-warning-on-macOS-10.15.patch"
patch -p1 -i "${SOURCE_DIR}/patches_sylpheed/0003-Update-sylpheed-3.4.1-osx-test1.patch-for-3.7.0.patch"
patch -p1 -i "${SOURCE_DIR}/patches_sylpheed/0004-Fix-linking-with-modern-gtkmacintegration.patch"
patch -p1 -i "${SOURCE_DIR}/patches_sylpheed/0005-Update-Info.plist-strings.patch"
jhbuild run ./makeosx.sh
cd macosx/bundle
jhbuild run gtk-mac-bundler sylpheed.bundle
cd ../../..

echo 'gtk-theme-name = "Clearlooks"' >> "${HOME}/Desktop/Sylpheed.app/Contents/Resources/etc/gtk-2.0/gtkrc"
clang "${SOURCE_DIR}/launcher/launcher.m" -o "${HOME}/Desktop/Sylpheed.app/Contents/MacOS/Sylpheed" -framework Foundation -O2 -Weverything -fobjc-arc -mmacos-version-min=${MACOSX_DEPLOYMENT_TARGET}
plutil -replace LSMinimumSystemVersion -string "${MACOSX_DEPLOYMENT_TARGET}" "${HOME}/Desktop/Sylpheed.app/Contents/Info.plist"

BUNDLE_IDENTIFIER="$(plutil -extract CFBundleIdentifier xml1 -o - "${HOME}/Desktop/Sylpheed.app/Contents/Info.plist" | sed -n 's|.*<string>\(.*\)<\/string>.*|\1|p')"
BUNDLE_VERSION="$(plutil -extract CFBundleVersion xml1 -o - "${HOME}/Desktop/Sylpheed.app/Contents/Info.plist" | sed -n 's|.*<string>\(.*\)<\/string>.*|\1|p')"
INSTALL_DIR="${PWD}/Sylpheed"
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
ditto --norsrc --noextattr --noqtn "${HOME}/Desktop/Sylpheed.app" "${INSTALL_DIR}/Sylpheed.app"
ln -s "/Applications" "${INSTALL_DIR}/Applications"

function sign() {
	/usr/bin/codesign \
		--sign "${APP_CERT}" \
		--deep \
		--force \
		--timestamp \
		--options runtime \
		--entitlements "${SOURCE_DIR}/entitlements/entitlements.entitlements" \
		--verbose \
		--strict \
		"${1}"
}
function notarize() {
	/usr/bin/python3 "${SOURCE_DIR}/scripts/MacNotarizer.py" \
		--application "${1}" \
		--primary-bundle-id "${2}" \
		--username "${NOTARIZE_USERNAME}" \
		--password "${NOTARIZE_PASSWORD}"
}
find "${INSTALL_DIR}/Sylpheed.app/Contents/Resources/lib" \( -name '*.so' -or -name '*.dylib' \) -print0 | while IFS= read -r -d '' item ; do sign "${item}" ; done
find "${INSTALL_DIR}/Sylpheed.app/Contents/MacOS" -type f -print0 | while IFS= read -r -d '' item ; do sign "${item}" ; done
sign "${INSTALL_DIR}/Sylpheed.app"
notarize "${INSTALL_DIR}/Sylpheed.app" "${BUNDLE_IDENTIFIER}"

hdiutil create -format UDBZ -fs HFS+ -srcfolder "Sylpheed" -volname "Sylpheed" "Sylpheed_${BUNDLE_VERSION}.dmg"
sign "Sylpheed_${BUNDLE_VERSION}.dmg"
notarize "Sylpheed_${BUNDLE_VERSION}.dmg" "${BUNDLE_IDENTIFIER}"
