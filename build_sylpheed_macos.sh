#!/bin/bash -e

SOURCE_DIR="$(cd "$(dirname "${0}")" && pwd)"
#SOURCE_DIR="${HOME}/Desktop/sylpheed-macos"
APP_CERT="Developer ID Application: Petr Zhigalov (48535TNTA7)"
NOTARIZE_USERNAME="peter.zhigalov@gmail.com"
NOTARIZE_PASSWORD="@keychain:Notarize: ${NOTARIZE_USERNAME}"
NOTARIZE_ASC_PROVIDER="${APP_CERT: -11:10}"

export MACOSX_DEPLOYMENT_TARGET="10.9"
export PATH="${HOME}/gtk/inst/bin:${HOME}/.new_local/bin:${HOME}/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin"
export PKG_CONFIG_PATH="${HOME}/gtk/inst/lib/pkgconfig"

git clone https://gitlab.gnome.org/GNOME/gtk-osx.git
cd gtk-osx
git checkout e9fc8c35ea404420d5bf700e835f7d48d2d38ac2
./gtk-osx-setup.sh
cd ..

git clone https://gitlab.gnome.org/GNOME/gtk-mac-bundler.git
cd gtk-mac-bundler
git checkout b01203ec8073637e0c0909f598eded9a260d19cd
make install
cd ..

pushd "${HOME}/Source/jhbuild" >/dev/null
git checkout c23ed55f46054b505389c5b6c261c335328cdd5d
popd >/dev/null

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
modulesets_dir = '${SOURCE_DIR}/modulesets'
setup_sdk(target="${MACOSX_DEPLOYMENT_TARGET}", architectures=["arm64"])
setup_release()
EOF

jhbuild bootstrap

curl -LO https://sylpheed.sraoss.jp/sylpheed/v3.7/sylpheed-3.7.0.tar.bz2
tar -xvpf sylpheed-3.7.0.tar.bz2
cd sylpheed-3.7.0
find "${SOURCE_DIR}/patches_sylpheed" -name '*.patch' | sort | while IFS= read -r item ; do patch -p1 -i "${item}" ; done
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
git checkout c23ed55f46054b505389c5b6c261c335328cdd5d
popd >/dev/null

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
modulesets_dir = '${SOURCE_DIR}/modulesets'
setup_sdk(target="${MACOSX_DEPLOYMENT_TARGET}", architectures=["x86_64"])
setup_release()
EOF

arch -x86_64 jhbuild bootstrap

tar -xvpf sylpheed-3.7.0.tar.bz2
cd sylpheed-3.7.0
find "${SOURCE_DIR}/patches_sylpheed" -name '*.patch' | sort | while IFS= read -r item ; do patch -p1 -i "${item}" ; done
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

cd sylpheed-3.7.0
for i in en $(find po -name '*.po' | sed 's|.*/|| ; s|\..*|| ; s|@.*||' | sort | uniq)
do
    mkdir -p "${HOME}/Desktop/Sylpheed.app/Contents/Resources/${i}.lproj"
done
cd ..

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

pushd "${INSTALL_DIR}" >/dev/null
cp "${SOURCE_DIR}/misc/README.rtf" ./
/usr/bin/python3 "${SOURCE_DIR}/scripts/DMGCustomizer.py"
popd >/dev/null

hdiutil create -format UDBZ -fs HFS+ -srcfolder "Sylpheed" -volname "Sylpheed" "Sylpheed_${BUNDLE_VERSION}.dmg"
sign "Sylpheed_${BUNDLE_VERSION}.dmg"
notarize "Sylpheed_${BUNDLE_VERSION}.dmg" "${BUNDLE_IDENTIFIER}"
