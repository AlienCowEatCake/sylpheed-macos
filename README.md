# Sylpheed for macOS

## About Sylpheed
[Sylpheed](https://sylpheed.sraoss.jp/en/) is a simple, lightweight but featureful, and easy-to-use e-mail client.
Sylpheed is a free software distributed under the [GNU GPL](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html).

## About Sylpheed for macOS
This software works on macOS 10.10 (Yosemite) or later. It runs on any Mac with a 64-bit Intel processor or an Apple Silicon chip. It has been tested on 12.7.6 (Monterey) and 26.0.1 (Tahoe).
Though Sylpheed for macOS is stable, please note that it has various issues because it is still testing stage.

## Screenshots
![sylpheed-mac-integration](img/sylpheed-mac-integration.png)

## Building from Source
Prerequisites:
- Mac with Apple Silicon chip
- [Rosetta 2](https://support.apple.com/102527)
- [Xcode](https://developer.apple.com/xcode/)

If you want to build signed and notarized version, you need to relpace `APP_CERT`, `NOTARIZE_USERNAME` and `NOTARIZE_PASSWORD` in [build_sylpheed_macos.sh](build_sylpheed_macos.sh) with your values and run following command:
```sh
cd sylpheed-macos
./build_sylpheed_macos.sh
```

If you want to use ad hoc signing, you just need to run following command:
```sh
cd sylpheed-macos
ADHOC_SIGN=1 ./build_sylpheed_macos.sh
```

## See also
* https://sylpheed.sraoss.jp/en/
* https://sylpheed.sraoss.jp/sylpheed/macosx/
* https://github.com/sylpheed-mail/sylpheed
* https://github.com/AlienCowEatCake/sylpheed-windows
