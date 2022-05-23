#!/bin/bash -e

SOURCE_DIR="$(cd "$(dirname "${0}")" && pwd)"
#SOURCE_DIR="/Users/peter/Desktop/sylpheed-macos"
APP_CERT="Developer ID Application: Petr Zhigalov (48535TNTA7)"
NOTARIZE_USERNAME="peter.zhigalov@gmail.com"
NOTARIZE_PASSWORD="@keychain:Notarize: ${NOTARIZE_USERNAME}"
NOTARIZE_ASC_PROVIDER="${APP_CERT: -11:10}"

export MACOSX_DEPLOYMENT_TARGET="10.9"
export PATH="${HOME}/gtk/inst/bin:${HOME}/.new_local/bin:${HOME}/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin"
export PKG_CONFIG_PATH="${HOME}/gtk/inst/lib/pkgconfig"

git clone https://gitlab.gnome.org/GNOME/gtk-osx.git
cd gtk-osx
git checkout bc3f9ca8a9e536cfde747a96e7973e99897976c1
cp -a "${SOURCE_DIR}/modulesets/bootstrap.modules" "./modulesets-stable/"
./gtk-osx-setup.sh
cd ..

git clone https://gitlab.gnome.org/GNOME/gtk-mac-bundler.git
cd gtk-mac-bundler
git checkout b01203ec8073637e0c0909f598eded9a260d19cd
make install
cd ..

pushd "${HOME}/Source/jhbuild" >/dev/null
git checkout 30ef98f32c357ed3f2290a466c94bc728279cd1e
popd >/dev/null

curl -LO 'https://github.com/ninja-build/ninja/releases/download/v1.11.0/ninja-mac.zip'
unzip ninja-mac.zip
mkdir -p "${HOME}/gtk/inst/bin"
mv ninja "${HOME}/gtk/inst/bin"

mkdir -p "${HOME}/gtk/inst/lib/pkgconfig"
cat << EOF > "${HOME}/gtk/inst/lib/pkgconfig/zlib.pc"
Name: zlib
Description: zlib compression library
Version: 1.2.11

Requires:
Libs: -lz
Cflags:
EOF

cp -a ~/.config/jhbuildrc-custom ~/.config/jhbuildrc-custom.bak
cat << EOF > ~/.config/jhbuildrc-custom
use_local_modulesets = True
modulesets_dir = '${PWD}/gtk-osx/modulesets-stable'
setup_sdk(target="${MACOSX_DEPLOYMENT_TARGET}", architectures=["arm64"])
setup_release()
append_autogenargs("murrine-engine", 'LDFLAGS="\$LDFLAGS -lpixman-1" CFLAGS="\$CFLAGS -Wno-implicit-function-declaration"')
EOF

jhbuild bootstrap
jhbuild build -s python2,python3,python,xz,gettext,autoconf,libtool,automake,bison,pkg-config,m4-common,cmake,intltool,libxml2,libxslt,gtk-osx-docbook,libffi,libpng,expat,dbus,pixman,libtasn1,libjpeg,sqlite,zlib,freetype2,fontconfig,itstool,xorg-macros gtk+-2.0
jhbuild build openssl
cp -a "${SOURCE_DIR}/modulesets/gtk-osx-obsolete.modules" "${HOME}/.cache/jhbuild/gtk-osx-obsolete-custom.modules"
cp -a "${SOURCE_DIR}/modulesets/gtk-osx-obsolete.modules" "${HOME}/Source/jhbuild/modulesets/gtk-osx-obsolete-custom.modules"
sed -i '' 's|\(<include href="gtk-osx-random.modules"/>\)|\1<include href="gtk-osx-obsolete-custom.modules"/>|' "${HOME}/.cache/jhbuild/gtk-osx.modules"
jhbuild build tango-icon-theme
jhbuild build gtk-engines
jhbuild build murrine-engine
jhbuild build gtk-mac-integration

curl -LO https://sylpheed.sraoss.jp/sylpheed/v3.7/sylpheed-3.7.0.tar.bz2
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
mv "${HOME}/Desktop/Sylpheed.app" "${HOME}/Desktop/Sylpheed_arm64.app"

rm -rf \
    "${HOME}/.cache/g-ir-scanner" \
    "${HOME}/.cache/jhbuild" \
    "${HOME}/.local" \
    "${HOME}/.new_local" \
    "${HOME}/gtk" \
    "${HOME}/Source" \
    "sylpheed-3.7.0"

cd gtk-osx
arch -x86_64 ./gtk-osx-setup.sh
cd ..

cd gtk-mac-bundler
arch -x86_64 make install
cd ..

pushd "${HOME}/Source/jhbuild" >/dev/null
git checkout 30ef98f32c357ed3f2290a466c94bc728279cd1e
popd >/dev/null

unzip ninja-mac.zip
mkdir -p "${HOME}/gtk/inst/bin"
mv ninja "${HOME}/gtk/inst/bin"

mkdir -p "${HOME}/gtk/inst/lib/pkgconfig"
cat << EOF > "${HOME}/gtk/inst/lib/pkgconfig/zlib.pc"
Name: zlib
Description: zlib compression library
Version: 1.2.11

Requires:
Libs: -lz
Cflags:
EOF

cat << EOF > ~/.config/jhbuildrc-custom
use_local_modulesets = True
modulesets_dir = '${PWD}/gtk-osx/modulesets-stable'
setup_sdk(target="${MACOSX_DEPLOYMENT_TARGET}", architectures=["x86_64"])
setup_release()
append_autogenargs("murrine-engine", 'LDFLAGS="\$LDFLAGS -lpixman-1" CFLAGS="\$CFLAGS -Wno-implicit-function-declaration"')
EOF

arch -x86_64 jhbuild bootstrap
arch -x86_64 jhbuild build -s python2,python3,python,xz,gettext,autoconf,libtool,automake,bison,pkg-config,m4-common,cmake,intltool,libxml2,libxslt,gtk-osx-docbook,libffi,libpng,expat,dbus,pixman,libtasn1,libjpeg,sqlite,zlib,freetype2,fontconfig,itstool,xorg-macros gtk+-2.0
arch -x86_64 jhbuild build openssl
cp -a "${SOURCE_DIR}/modulesets/gtk-osx-obsolete.modules" "${HOME}/.cache/jhbuild/gtk-osx-obsolete-custom.modules"
cp -a "${SOURCE_DIR}/modulesets/gtk-osx-obsolete.modules" "${HOME}/Source/jhbuild/modulesets/gtk-osx-obsolete-custom.modules"
sed -i '' 's|\(<include href="gtk-osx-random.modules"/>\)|\1<include href="gtk-osx-obsolete-custom.modules"/>|' "${HOME}/.cache/jhbuild/gtk-osx.modules"
arch -x86_64 jhbuild build tango-icon-theme
arch -x86_64 jhbuild build gtk-engines
arch -x86_64 jhbuild build murrine-engine
arch -x86_64 jhbuild build gtk-mac-integration

tar -xvpf sylpheed-3.7.0.tar.bz2
cd sylpheed-3.7.0
patch -p1 -i "${SOURCE_DIR}/patches_sylpheed/0001-Update-macos-bundle-project-for-latest-GTK.patch"
patch -p1 -i "${SOURCE_DIR}/patches_sylpheed/0002-Fix-warning-on-macOS-10.15.patch"
patch -p1 -i "${SOURCE_DIR}/patches_sylpheed/0003-Update-sylpheed-3.4.1-osx-test1.patch-for-3.7.0.patch"
patch -p1 -i "${SOURCE_DIR}/patches_sylpheed/0004-Fix-linking-with-modern-gtkmacintegration.patch"
patch -p1 -i "${SOURCE_DIR}/patches_sylpheed/0005-Update-Info.plist-strings.patch"
arch -x86_64 jhbuild run ./makeosx.sh
cd macosx/bundle
arch -x86_64 jhbuild run gtk-mac-bundler sylpheed.bundle
cd ../../..

BUNDLE_EXECUTABLE="$(plutil -extract CFBundleExecutable xml1 -o - "${HOME}/Desktop/Sylpheed.app/Contents/Info.plist" | sed -n 's|.*<string>\(.*\)<\/string>.*|\1|p')"
find "${HOME}/Desktop/Sylpheed.app/Contents/Resources/lib" -type f \( -name '*.so' -or -name '*.dylib' \) -print0 | while IFS= read -r -d '' item
do
    lipo "${item}" "$(echo "${item}" | sed "s|^${HOME}/Desktop/Sylpheed.app|${HOME}/Desktop/Sylpheed_arm64.app|")"  -create -output "${item##*/}"
    mv "${item##*/}" "${item}"
done
find "${HOME}/Desktop/Sylpheed.app/Contents/MacOS" -type f -print0 | while IFS= read -r -d '' item
do
    if [ "${item##*/}_" != "${BUNDLE_EXECUTABLE}_" ]; then
        lipo "${item}" "$(echo "${item}" | sed "s|^${HOME}/Desktop/Sylpheed.app|${HOME}/Desktop/Sylpheed_arm64.app|")"  -create -output "${item##*/}"
        mv "${item##*/}" "${item}"
    fi
done

rm -rf \
    "${HOME}/.cache/g-ir-scanner" \
    "${HOME}/.cache/jhbuild" \
    "${HOME}/.local" \
    "${HOME}/.new_local" \
    "${HOME}/gtk" \
    "${HOME}/Source" \
    "sylpheed-3.7.0" \
    "gtk-osx" \
    "gtk-mac-bundler" \
    "ninja-mac.zip" \
    "sylpheed-3.7.0.tar.bz2" \
    "${HOME}/.config/jhbuildrc" \
    "${HOME}/.config/jhbuildrc-custom" \
    "${HOME}/.config/pip" \
    "${HOME}/.rustup" \
    "${HOME}/Desktop/Sylpheed_arm64.app"

echo 'gtk-theme-name = "Clearlooks"' >> "${HOME}/Desktop/Sylpheed.app/Contents/Resources/etc/gtk-2.0/gtkrc"
clang "${SOURCE_DIR}/launcher/launcher.m" -o "${HOME}/Desktop/Sylpheed.app/Contents/MacOS/${BUNDLE_EXECUTABLE}" -framework Foundation -O2 -Weverything -fobjc-arc -mmacos-version-min=${MACOSX_DEPLOYMENT_TARGET} -arch x86_64 -arch arm64
plutil -replace LSMinimumSystemVersion -string "${MACOSX_DEPLOYMENT_TARGET}" "${HOME}/Desktop/Sylpheed.app/Contents/Info.plist"
plutil -replace LSArchitecturePriority -json '["arm64","x86_64"]' "${HOME}/Desktop/Sylpheed.app/Contents/Info.plist"

BUNDLE_IDENTIFIER="$(plutil -extract CFBundleIdentifier xml1 -o - "${HOME}/Desktop/Sylpheed.app/Contents/Info.plist" | sed -n 's|.*<string>\(.*\)<\/string>.*|\1|p')"
BUNDLE_VERSION="$(plutil -extract CFBundleVersion xml1 -o - "${HOME}/Desktop/Sylpheed.app/Contents/Info.plist" | sed -n 's|.*<string>\(.*\)<\/string>.*|\1|p')"
INSTALL_DIR="${PWD}/Sylpheed"
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
ditto --norsrc --noextattr --noqtn "${HOME}/Desktop/Sylpheed.app" "${INSTALL_DIR}/Sylpheed.app"
ln -s "/Applications" "${INSTALL_DIR}/Applications"

function sign() {
    local max_retry=10
    local last_retry=$((${max_retry}-1))
    for ((i=0; i<${max_retry}; i++)) ; do
        if /usr/bin/codesign \
                --sign "${APP_CERT}" \
                --deep \
                --force \
                --timestamp \
                --options runtime \
                --entitlements "${SOURCE_DIR}/entitlements/entitlements.entitlements" \
                --verbose \
                --strict \
                "${1}" ; then
            if [ ${i} != 0 ] ; then
                echo "Sign completed at ${i} retry"
            fi
            break
        else
            if [ ${i} != ${last_retry} ] ; then
                echo "Signing failed, retry ..."
                sleep 5
            else
                exit 2
            fi
        fi
    done
}
function notarize() {
    /usr/bin/python3 "${SOURCE_DIR}/scripts/MacNotarizer.py" \
        --application "${1}" \
        --primary-bundle-id "${2}" \
        --username "${NOTARIZE_USERNAME}" \
        --password "${NOTARIZE_PASSWORD}" \
        --asc-provider "${NOTARIZE_ASC_PROVIDER}"
}
find "${INSTALL_DIR}/Sylpheed.app/Contents/Resources/lib" \( -name '*.so' -or -name '*.dylib' \) -print0 | while IFS= read -r -d '' item ; do sign "${item}" ; done
find "${INSTALL_DIR}/Sylpheed.app/Contents/MacOS" -type f -print0 | while IFS= read -r -d '' item ; do sign "${item}" ; done
sign "${INSTALL_DIR}/Sylpheed.app"
notarize "${INSTALL_DIR}/Sylpheed.app" "${BUNDLE_IDENTIFIER}"

hdiutil create -format UDBZ -fs HFS+ -srcfolder "Sylpheed" -volname "Sylpheed" "Sylpheed_${BUNDLE_VERSION}.dmg"
sign "Sylpheed_${BUNDLE_VERSION}.dmg"
notarize "Sylpheed_${BUNDLE_VERSION}.dmg" "${BUNDLE_IDENTIFIER}"
