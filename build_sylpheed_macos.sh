#!/bin/bash -e

SOURCE_DIR="$(cd "$(dirname "${0}")" && pwd)"
#SOURCE_DIR="${HOME}/Desktop/sylpheed-macos"
APP_CERT="Developer ID Application: Petr Zhigalov (48535TNTA7)"
NOTARIZE_USERNAME="peter.zhigalov@gmail.com"
NOTARIZE_PASSWORD="@keychain:Notarize: ${NOTARIZE_USERNAME}"
NOTARIZE_ASC_PROVIDER="${APP_CERT: -11:10}"

# @note Override HOME dir because it is too hard to override ALL paths in gtk-osx and other scripts
HOME_DEV="${PWD}/devroot"
HOME_PREV="${HOME}"
export HOME="${HOME_DEV}"
rm -rf "${HOME_DEV}"
mkdir -p "${HOME_DEV}"

export MACOSX_DEPLOYMENT_TARGET="10.10"
export PYTHON_VERSION="3.11.11"
export PATH="${HOME}/gtk/inst/bin:${HOME}/.new_local/bin:${HOME}/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin:"
export PKG_CONFIG_PATH="${HOME}/gtk/inst/lib/pkgconfig:${HOME}/.new_local/share/pyenv/versions/${PYTHON_VERSION:=3.10.2}/lib/pkgconfig:"
export CFLAGS="-Wno-int-conversion -Wno-incompatible-function-pointer-types -Wno-implicit-int"
CFLAGS_TARGET="-Werror=unguarded-availability-new"

function copy_bash {
    # @note Workaround for SIP workaround in gtk-osx
    mkdir -p "${HOME}/.new_local/bin"
    rm -rf "${HOME}/.new_local/bin/bash"
    cat << EOF > "${HOME}/.new_local/bin/bash"
#!/bin/bash -e
/bin/bash "\${@}"
EOF
    chmod 755 "${HOME}/.new_local/bin/bash"
}

git clone https://gitlab.gnome.org/GNOME/gtk-osx.git
cd gtk-osx
git checkout e9fc8c35ea404420d5bf700e835f7d48d2d38ac2
copy_bash
# @note Lock Rust version because 10.7-10.11 support is dropped since 1.74.0
sed -i '' 's|\(.*sh\.rustup\.rs.*--profile minimal\)|\1 --default-toolchain 1.73.0|' ./gtk-osx-setup.sh
# @note Lock some Python packages to avoid error "ImportError: cannot import name 'LegacySpecifier' from 'packaging.specifiers'"
sed -i '' 's|\($PIPENV install\)|\1 "packaging<21.3" "setuptools<69.5"|' ./gtk-osx-setup.sh
# @note Enable error handling
sed -i '' 's|\(#!/usr/bin/env bash\)|\1 -e -x|' ./gtk-osx-setup.sh
sed -i '' 's/\(.*=`which [^`]*`\)/\1 || true/g' ./gtk-osx-setup.sh
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
Version: 1.3.1

Requires:
Libs: -lz
Cflags:
EOF

mkdir -p "${HOME}/gtk/inst/lib/pkgconfig" "${HOME}/gtk/inst/include/enchant-2"
cp -a "${SOURCE_DIR}/enchant/enchant.h" "${HOME}/gtk/inst/include/enchant-2/"
clang "${SOURCE_DIR}/enchant/enchant.m" -O3 -DNDEBUG -dynamiclib -fPIC -current_version 11.2.0 -compatibility_version 11.0.0 \
    -mmacos-version-min=${MACOSX_DEPLOYMENT_TARGET} -arch arm64 -framework AppKit -framework Foundation \
    -Weverything -Wno-gnu-zero-variadic-macro-arguments -Wno-documentation-unknown-command -Wno-poison-system-directories \
    -Wno-declaration-after-statement ${CFLAGS_TARGET} \
    -o "${HOME}/gtk/inst/lib/libenchant-2.dylib" -install_name "${HOME}/gtk/inst/lib/libenchant-2.dylib"
cat << EOF > "${HOME}/gtk/inst/lib/pkgconfig/enchant-2.pc"
prefix=${HOME}/gtk/inst
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libenchant
Description: A spell checking library
Version: 2.8.2
Libs: -L\${libdir} -lenchant-2
Cflags: -I\${includedir}/enchant-2
EOF

cp -a "${HOME}/.config/jhbuildrc-custom" "${HOME}/.config/jhbuildrc-custom.bak"
cat << EOF > "${HOME}/.config/jhbuildrc-custom"
use_local_modulesets = True
modulesets_dir = '${SOURCE_DIR}/modulesets'
setup_sdk(target="${MACOSX_DEPLOYMENT_TARGET}", architectures=["arm64"])
setup_release()
EOF

CFLAGS="${CFLAGS} ${CFLAGS_TARGET}" jhbuild bootstrap

curl -LO https://sylpheed.sraoss.jp/sylpheed/v3.8beta/sylpheed-3.8.0beta1.tar.bz2
tar -xvpf sylpheed-3.8.0beta1.tar.bz2
cd sylpheed-3.8.0beta1
find "${SOURCE_DIR}/patches_sylpheed" -name '*.patch' | sort | while IFS= read -r item ; do patch -p1 -i "${item}" ; done
CFLAGS="${CFLAGS} ${CFLAGS_TARGET}" jhbuild run ./makeosx.sh --disable-dependency-tracking --enable-oniguruma --build=aarch64-apple-darwin
cd ..

curl -Lo qdbm-1.8.78.tar.gz https://snapshot.debian.org/archive/debian/20111016T212433Z/pool/main/q/qdbm/qdbm_1.8.78.orig.tar.gz
tar -xvpf qdbm-1.8.78.tar.gz
cd qdbm-1.8.78
jhbuild run ./configure --prefix="${HOME}/gtk/inst" --enable-stable --enable-pthread --enable-zlib --enable-iconv
for i in $(cat Makefile.in | grep -E '^MYLIBOBJS = ' | sed 's|MYLIBOBJS = || ; s|\.o||g') ; do
    jhbuild run clang -c -O3 -DQDBM_STATIC -I. -DMYPTHREAD -DMYZLIB -DMYICONV -DNDEBUG -fPIC ${CFLAGS_TARGET} "${i}.c" -o "${i}.o"
done
jhbuild run ar rcs "${HOME}/gtk/inst/lib/libqdbm.a" *.o
for i in $(cat Makefile.in | grep -E '^MYHEADS = ' | sed 's|MYHEADS = ||') ; do
    cp -a "${i}" "${HOME}/gtk/inst/include/"
done
cat << EOF > "${HOME}/gtk/inst/lib/pkgconfig/qdbm.pc"
Name: QDBM
Description: a high performance embedded database library
Version: 1.8.78
Libs: -L${HOME}/gtk/inst/lib ${HOME}/gtk/inst/lib/libqdbm.a -lz -lpthread -liconv
Cflags: -I${HOME}/gtk/inst/include -DQDBM_STATIC
EOF
cd ..

curl -LO http://sylpheed.sraoss.jp/sylfilter/src/sylfilter-0.8.tar.gz
tar -xvpf sylfilter-0.8.tar.gz
cd sylfilter-0.8
find "${SOURCE_DIR}/patches_sylfilter" -name '*.patch' | sort | while IFS= read -r item ; do patch -p1 -i "${item}" ; done
jhbuild run ./configure --prefix="${HOME}/gtk/inst" --disable-dependency-tracking --enable-shared --disable-static --enable-sqlite --enable-qdbm --disable-gdbm --with-libsylph=sylpheed --with-pic
jhbuild run clang \
    -O3 -DNDEBUG -mmacos-version-min=${MACOSX_DEPLOYMENT_TARGET} \
    lib/*.c lib/filters/*.c src/*.c ${CFLAGS_TARGET} \
    -I. -I./lib -I./lib/filters -I${HOME}/gtk/inst/include/sylpheed -lsylph-0 \
    $(pkg-config --cflags glib-2.0 qdbm sqlite3) $(pkg-config --libs glib-2.0 qdbm sqlite3) \
    -o "${HOME}/gtk/inst/bin/sylfilter"
strip "${HOME}/gtk/inst/bin/sylfilter"
cd ..

cd sylpheed-3.8.0beta1
cd macosx/bundle
sed -i '' 's|\(</main-binary>\)|\1\n  <binary>${prefix}/bin/sylfilter</binary>|' sylpheed.bundle
jhbuild run gtk-mac-bundler sylpheed.bundle
mv "${HOME}/Desktop/Sylpheed.app/Contents/Resources/bin/sylfilter" "${HOME}/Desktop/Sylpheed.app/Contents/MacOS/"
mv "${HOME}/Desktop/Sylpheed.app/Contents/Resources/bin/syl-auth-helper" "${HOME}/Desktop/Sylpheed.app/Contents/MacOS/"
if [ ! "$(ls -A "${HOME}/Desktop/Sylpheed.app/Contents/Resources/bin")" ] ; then
    rm -rf "${HOME}/Desktop/Sylpheed.app/Contents/Resources/bin"
fi
cd ../../..
mv "${HOME}/Desktop/Sylpheed.app" "${HOME}/Desktop/Sylpheed_arm64.app"

rm -rf \
    "${HOME}/.cache/g-ir-scanner" \
    "${HOME}/.cache/jhbuild" \
    "${HOME}/.local" \
    "${HOME}/.new_local" \
    "${HOME}/gtk" \
    "${HOME}/Source" \
    "qdbm-1.8.78" \
    "sylfilter-0.8" \
    "sylpheed-3.8.0beta1"

cd gtk-osx
copy_bash
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
Version: 1.3.1

Requires:
Libs: -lz
Cflags:
EOF

mkdir -p "${HOME}/gtk/inst/lib/pkgconfig" "${HOME}/gtk/inst/include/enchant-2"
cp -a "${SOURCE_DIR}/enchant/enchant.h" "${HOME}/gtk/inst/include/enchant-2/"
clang "${SOURCE_DIR}/enchant/enchant.m" -O3 -DNDEBUG -dynamiclib -fPIC -current_version 11.2.0 -compatibility_version 11.0.0 \
    -mmacos-version-min=${MACOSX_DEPLOYMENT_TARGET} -arch x86_64 -framework AppKit -framework Foundation \
    -Weverything -Wno-gnu-zero-variadic-macro-arguments -Wno-documentation-unknown-command -Wno-poison-system-directories \
    -Wno-declaration-after-statement ${CFLAGS_TARGET} \
    -o "${HOME}/gtk/inst/lib/libenchant-2.dylib" -install_name "${HOME}/gtk/inst/lib/libenchant-2.dylib"
cat << EOF > "${HOME}/gtk/inst/lib/pkgconfig/enchant-2.pc"
prefix=${HOME}/gtk/inst
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libenchant
Description: A spell checking library
Version: 2.8.2
Libs: -L\${libdir} -lenchant-2
Cflags: -I\${includedir}/enchant-2
EOF

cat << EOF > "${HOME}/.config/jhbuildrc-custom"
use_local_modulesets = True
modulesets_dir = '${SOURCE_DIR}/modulesets'
setup_sdk(target="${MACOSX_DEPLOYMENT_TARGET}", architectures=["x86_64"])
setup_release()
EOF

CFLAGS="${CFLAGS} ${CFLAGS_TARGET}" arch -x86_64 jhbuild bootstrap

tar -xvpf sylpheed-3.8.0beta1.tar.bz2
cd sylpheed-3.8.0beta1
find "${SOURCE_DIR}/patches_sylpheed" -name '*.patch' | sort | while IFS= read -r item ; do patch -p1 -i "${item}" ; done
CFLAGS="${CFLAGS} ${CFLAGS_TARGET}" arch -x86_64 jhbuild run ./makeosx.sh --disable-dependency-tracking --enable-oniguruma --build=x86_64-apple-darwin
cd ..

tar -xvpf qdbm-1.8.78.tar.gz
cd qdbm-1.8.78
arch -x86_64 jhbuild run ./configure --prefix="${HOME}/gtk/inst" --enable-stable --enable-pthread --enable-zlib --enable-iconv
for i in $(cat Makefile.in | grep -E '^MYLIBOBJS = ' | sed 's|MYLIBOBJS = || ; s|\.o||g') ; do
    arch -x86_64 jhbuild run clang -c -O3 -DQDBM_STATIC -I. -DMYPTHREAD -DMYZLIB -DMYICONV -DNDEBUG -fPIC ${CFLAGS_TARGET} "${i}.c" -o "${i}.o"
done
arch -x86_64 jhbuild run ar rcs "${HOME}/gtk/inst/lib/libqdbm.a" *.o
for i in $(cat Makefile.in | grep -E '^MYHEADS = ' | sed 's|MYHEADS = ||') ; do
    cp -a "${i}" "${HOME}/gtk/inst/include/"
done
cat << EOF > "${HOME}/gtk/inst/lib/pkgconfig/qdbm.pc"
Name: QDBM
Description: a high performance embedded database library
Version: 1.8.78
Libs: -L${HOME}/gtk/inst/lib ${HOME}/gtk/inst/lib/libqdbm.a -lz -lpthread -liconv
Cflags: -I${HOME}/gtk/inst/include -DQDBM_STATIC
EOF
cd ..

tar -xvpf sylfilter-0.8.tar.gz
cd sylfilter-0.8
find "${SOURCE_DIR}/patches_sylfilter" -name '*.patch' | sort | while IFS= read -r item ; do patch -p1 -i "${item}" ; done
arch -x86_64 jhbuild run ./configure --prefix="${HOME}/gtk/inst" --disable-dependency-tracking --enable-shared --disable-static --enable-sqlite --enable-qdbm --disable-gdbm --with-libsylph=sylpheed --with-pic
arch -x86_64 jhbuild run clang \
    -O3 -DNDEBUG -mmacos-version-min=${MACOSX_DEPLOYMENT_TARGET} \
    lib/*.c lib/filters/*.c src/*.c ${CFLAGS_TARGET} \
    -I. -I./lib -I./lib/filters -I${HOME}/gtk/inst/include/sylpheed -lsylph-0 \
    $(pkg-config --cflags glib-2.0 qdbm sqlite3) $(pkg-config --libs glib-2.0 qdbm sqlite3) \
    -o "${HOME}/gtk/inst/bin/sylfilter"
arch -x86_64 strip "${HOME}/gtk/inst/bin/sylfilter"
cd ..

cd sylpheed-3.8.0beta1
cd macosx/bundle
sed -i '' 's|\(</main-binary>\)|\1\n  <binary>${prefix}/bin/sylfilter</binary>|' sylpheed.bundle
arch -x86_64 jhbuild run gtk-mac-bundler sylpheed.bundle
mv "${HOME}/Desktop/Sylpheed.app/Contents/Resources/bin/sylfilter" "${HOME}/Desktop/Sylpheed.app/Contents/MacOS/"
mv "${HOME}/Desktop/Sylpheed.app/Contents/Resources/bin/syl-auth-helper" "${HOME}/Desktop/Sylpheed.app/Contents/MacOS/"
if [ ! "$(ls -A "${HOME}/Desktop/Sylpheed.app/Contents/Resources/bin")" ] ; then
    rm -rf "${HOME}/Desktop/Sylpheed.app/Contents/Resources/bin"
fi
cd ../../..

BUNDLE_EXECUTABLE="$(plutil -extract CFBundleExecutable xml1 -o - "${HOME}/Desktop/Sylpheed.app/Contents/Info.plist" | sed -n 's|.*<string>\(.*\)<\/string>.*|\1|p')"
find "${HOME}/Desktop/Sylpheed.app/Contents/Resources/lib" -type f \( -name '*.so' -or -name '*.dylib' \) -print0 | while IFS= read -r -d '' item
do
    lipo "${item}" "$(echo "${item}" | sed "s|^${HOME}/Desktop/Sylpheed.app|${HOME}/Desktop/Sylpheed_arm64.app|")"  -create -output "${item##*/}"
    mv "${item##*/}" "${item}"
    chmod 755 "${item}"
done
find "${HOME}/Desktop/Sylpheed.app/Contents/MacOS" -type f -print0 | while IFS= read -r -d '' item
do
    if [ "${item##*/}_" != "${BUNDLE_EXECUTABLE}_" ]; then
        lipo "${item}" "$(echo "${item}" | sed "s|^${HOME}/Desktop/Sylpheed.app|${HOME}/Desktop/Sylpheed_arm64.app|")"  -create -output "${item##*/}"
        mv "${item##*/}" "${item}"
        chmod 755 "${item}"
    fi
done

cd sylpheed-3.8.0beta1
for i in en $(find po -name '*.po' | sed 's|.*/|| ; s|\..*|| ; s|@.*||' | sort | uniq)
do
    mkdir -p "${HOME}/Desktop/Sylpheed.app/Contents/Resources/${i}.lproj"
done
cd ..

echo 'gtk-theme-name = "Clearlooks"' >> "${HOME}/Desktop/Sylpheed.app/Contents/Resources/etc/gtk-2.0/gtkrc"
clang "${SOURCE_DIR}/launcher/launcher.m" -o "${HOME}/Desktop/Sylpheed.app/Contents/MacOS/${BUNDLE_EXECUTABLE}" -framework Foundation -O2 -Weverything -mmacos-version-min=${MACOSX_DEPLOYMENT_TARGET} -arch x86_64 -arch arm64
cp "${SOURCE_DIR}/misc/sylpheed.icns" "${HOME}/Desktop/Sylpheed.app/Contents/Resources/sylpheed.icns"
base64 -d -i "${SOURCE_DIR}/misc/oauth2.ini.b64" -o "${HOME}/Desktop/Sylpheed.app/Contents/Resources/oauth2.ini"
plutil -replace LSMinimumSystemVersion -string "${MACOSX_DEPLOYMENT_TARGET}" "${HOME}/Desktop/Sylpheed.app/Contents/Info.plist"
plutil -replace LSArchitecturePriority -json '["arm64","x86_64"]' "${HOME}/Desktop/Sylpheed.app/Contents/Info.plist"

BUNDLE_IDENTIFIER="$(plutil -extract CFBundleIdentifier xml1 -o - "${HOME}/Desktop/Sylpheed.app/Contents/Info.plist" | sed -n 's|.*<string>\(.*\)<\/string>.*|\1|p')"
#BUNDLE_VERSION="$(plutil -extract CFBundleVersion xml1 -o - "${HOME}/Desktop/Sylpheed.app/Contents/Info.plist" | sed -n 's|.*<string>\(.*\)<\/string>.*|\1|p')"
BUNDLE_VERSION="$(plutil -extract CFBundleGetInfoString xml1 -o - "${HOME}/Desktop/Sylpheed.app/Contents/Info.plist" | sed -n 's|.*<string>\(.*\)<\/string>.*|\1|p' | sed 's|[, ].*||')"
INSTALL_DIR="${PWD}/Sylpheed"
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
ditto --norsrc --noextattr --noqtn "${HOME}/Desktop/Sylpheed.app" "${INSTALL_DIR}/Sylpheed.app"
ln -s "/Applications" "${INSTALL_DIR}/Applications"

rm -rf \
    "${HOME}/.cache/g-ir-scanner" \
    "${HOME}/.cache/jhbuild" \
    "${HOME}/.local" \
    "${HOME}/.new_local" \
    "${HOME}/gtk" \
    "${HOME}/Source" \
    "qdbm-1.8.78" \
    "sylfilter-0.8" \
    "sylpheed-3.8.0beta1" \
    "gtk-osx" \
    "gtk-mac-bundler" \
    "qdbm-1.8.78.tar.gz" \
    "sylfilter-0.8.tar.gz" \
    "sylpheed-3.8.0beta1.tar.bz2" \
    "${HOME}/.config/jhbuildrc" \
    "${HOME}/.config/jhbuildrc-custom" \
    "${HOME}/.config/pip" \
    "${HOME}/.rustup" \
    "${HOME}/Desktop/Sylpheed_arm64.app" \
    "${HOME}/Desktop/Sylpheed.app" \
    "${HOME_DEV}"

# @note Restore HOME dir because it is required for signing
export HOME="${HOME_PREV}"

function sign() {
    local max_retry=10
    local last_retry=$((${max_retry}-1))
    for ((i=0; i<${max_retry}; i++)) ; do
        if arch -x86_64 /usr/bin/codesign \
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

rm -rf "${INSTALL_DIR}"
echo "DONE"
