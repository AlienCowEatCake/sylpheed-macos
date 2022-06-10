// Original file: https://gitlab.gnome.org/GNOME/gtk-mac-bundler/-/blob/3770bb6c27a913dc39dbcc98fe175a53df92700c/examples/launcher.sh
// Build: clang launcher.m -o "launcher" -framework Foundation -O2 -Weverything -fobjc-arc -mmacos-version-min=10.7

#include <stdlib.h>
#import <Foundation/Foundation.h>

static NSString * substr(NSString * str, NSUInteger from, NSUInteger len) {
    if([str length] <= from)
        return @"";
    NSString * tmp = [str substringFromIndex:from];
    if([tmp length] <= len)
        return tmp;
    return [tmp substringToIndex:len];
}

static BOOL exist(NSString * path) {
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSBundle * bundle = [NSBundle mainBundle];
        NSString * bundleRes = [bundle resourcePath];
        NSString * bundleLib = [bundleRes stringByAppendingPathComponent:@"lib"];
        NSString * bundleData = [bundleRes stringByAppendingPathComponent:@"share"];
        NSString * bundleEtc = [bundleRes stringByAppendingPathComponent:@"etc"];

        setenv("XDG_CONFIG_DIRS", [[bundleEtc stringByAppendingPathComponent:@"xdg"] UTF8String], 0);
        setenv("XDG_DATA_DIRS", [bundleData UTF8String], 0);
        setenv("GTK_DATA_PREFIX", [bundleRes UTF8String], 0);
        setenv("GTK_EXE_PREFIX", [bundleRes UTF8String], 0);
        setenv("GTK_PATH", [bundleRes UTF8String], 0);

        setenv("GTK2_RC_FILES", [[NSString pathWithComponents:@[bundleEtc, @"gtk-2.0/gtkrc"]] UTF8String], 0);
        setenv("GTK_IM_MODULE_FILE", [[NSString pathWithComponents:@[bundleEtc, @"gtk-2.0/gtk.immodules"]] UTF8String], 0);
        // N.B. When gdk-pixbuf was separated from Gtk+ the location of the
        // loaders cache changed as well. Depending on the version of Gtk+ that
        // you built with you may still need to use the old location:
        //setenv("GDK_PIXBUF_MODULE_FILE", [[NSString pathWithComponents:@[bundleEtc, @"gtk-2.0/gdk-pixbuf.loaders"]] UTF8String], 0);
        setenv("GDK_PIXBUF_MODULE_FILE", [[NSString pathWithComponents:@[bundleLib, @"gdk-pixbuf-2.0/2.10.0/loaders.cache"]] UTF8String], 0);
        setenv("PANGO_LIBDIR", [bundleLib UTF8String], 0);
        setenv("PANGO_SYSCONFDIR", [bundleEtc UTF8String], 0);

        NSString * app = [[bundle executablePath] lastPathComponent];
        NSString * i18nDir = [bundleData stringByAppendingPathComponent:@"locale"];
        // Set the locale-related variables appropriately:
        unsetenv("LANG");
        unsetenv("LC_MESSAGES");
        unsetenv("LC_MONETARY");
        unsetenv("LC_COLLATE");
        NSString * env_LANG = nil;
        NSString * env_LC_MESSAGES = nil;
        NSString * env_LC_MONETARY = nil;
        NSString * env_LC_COLLATE = nil;

        // Has a language ordering been set?
        // If so, set LC_MESSAGES and LANG accordingly; otherwise skip it.
        NSArray * appleLanguages = [[NSUserDefaults standardUserDefaults] arrayForKey:@"AppleLanguages"];
        if(appleLanguages) {
            // A language ordering exists.
            // Test, item per item, to see whether there is an corresponding locale.
            for(NSString * appleLanguageTmp in appleLanguages) {
                NSString * appleLanguage = appleLanguageTmp;
                // First step uses sed to clean off the quotes and commas, to change - to _,
                // and change the names for the chinese scripts from "Hans" to CN and "Hant" to TW.
                appleLanguage = [appleLanguage stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
                appleLanguage = [appleLanguage stringByReplacingOccurrencesOfString:@"Hans" withString:@"CN"];
                appleLanguage = [appleLanguage stringByReplacingOccurrencesOfString:@"Hant" withString:@"TW"];
                NSMutableCharacterSet * allowedSymbols = [NSMutableCharacterSet alphanumericCharacterSet];
                [allowedSymbols addCharactersInString:@"_"];
                appleLanguage = [[appleLanguage componentsSeparatedByCharactersInSet:[allowedSymbols invertedSet]] componentsJoinedByString:@""];
                if([appleLanguage length] < 2)
                    continue;

                // test for exact matches:
                if(exist([NSString stringWithFormat:@"%@/%@/LC_MESSAGES/%@.mo", i18nDir, appleLanguage, app])) {
                    env_LANG = appleLanguage;
                    break;
                }

                // This is a special case, because often the original strings are in US
                // English and there is no translation file.
                if([appleLanguage isEqualToString:@"en_US"]) {
                    env_LANG = appleLanguage;
                    break;
                }

                // OK, now test for just the first two letters:
                if(exist([NSString stringWithFormat:@"%@/%@/LC_MESSAGES/%@.mo", i18nDir, substr(appleLanguage, 0, 2), app])) {
                    env_LANG = substr(appleLanguage, 0, 2);
                    break;
                }

                // Same thing, but checking for any english variant.
                if([substr(appleLanguage, 0, 2) isEqualToString:@"en"]) {
                    env_LANG = appleLanguage;
                    break;
                }
            }
        }

        // If we didn't get a language from the language list, try the Collation preference, in case it's the only setting that exists.
        NSString * appleCollation = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleCollationOrder"];
        if(appleCollation && [appleCollation length] >= 2) {
            if(!env_LANG)
                env_LANG = substr(appleCollation, 0, 2);
            env_LC_COLLATE = appleCollation;
        }

        // Continue by attempting to find the Locale preference.
        NSString * appleLocale = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleLocale"];
        if(appleLocale && !env_LANG) {
            if(exist([NSString stringWithFormat:@"%@/%@/LC_MESSAGES/%@.mo", i18nDir, substr(appleLocale, 0, 5), app]))
                env_LANG = substr(appleLocale, 0, 5);
            else if(exist([NSString stringWithFormat:@"%@/%@/LC_MESSAGES/%@.mo", i18nDir, substr(appleLocale, 0, 2), app]))
                env_LANG = substr(appleLocale, 0, 2);
        }

        // Next we need to set LC_MESSAGES. If at all possible, we want a full
        // 5-character locale to avoid the "Locale not supported by C library"
        // warning from Gtk -- even though Gtk will translate with a
        // two-character code.
        if(env_LANG) {
            // If the language code matches the applelocale, then that's the message
            // locale; otherwise, if it's longer than two characters, then it's
            // probably a good message locale and we'll go with it.
            if([env_LANG isEqualToString: substr(appleLocale, 0, 5)] || [env_LANG length] > 2) {
                env_LC_MESSAGES = env_LANG;
            }
            // Next try if the Applelocale is longer than 2 chars and the language
            // bit matches $LANG
            else if([env_LANG isEqualToString: substr(appleLocale, 0, 2)] && [appleLocale length] > 2) {
                env_LC_MESSAGES = substr(appleLocale, 0, 5);
            }
            // Fail. Get a list of the locales in $PREFIX/share/locale that match
            // our two letter language code and pick the first one, special casing
            // english to set en_US
            else if([env_LANG isEqualToString:@"en"]) {
                env_LC_MESSAGES = @"en_US";
            }
            else {
                NSArray * locales = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[bundleData stringByAppendingPathComponent:@"locale"] error:nil];
                if(locales) {
                    for(NSString * locale in locales) {
                        if([substr(locale, 0, [env_LANG length]) isEqualToString:env_LANG])
                            env_LC_MESSAGES = locale;
                    }
                }
            }
        }
        else {
            // All efforts have failed, so default to US english
            env_LANG = @"en_US";
            env_LC_MESSAGES = @"en_US";
        }

        NSString * currencyPattern = @".*currency=([[:alpha:]]+).*";
        NSRegularExpression * currencyRegex = [NSRegularExpression regularExpressionWithPattern:currencyPattern options:0 error:nil];
        NSTextCheckingResult * currencyTextCheckingResult = [currencyRegex firstMatchInString:appleLocale options:0 range:NSMakeRange(0, [appleLocale length])];
        if([currencyTextCheckingResult numberOfRanges] >= 1) {
            NSString * currency = [appleLocale substringWithRange:[currencyTextCheckingResult rangeAtIndex:1]];
            if(currency) {
                // The user has set a special currency. Gtk doesn't install LC_MONETARY files, but Apple does in /usr/share/locale, so we're going to look there for a locale to set LC_CURRENCY to.
                if(exist([NSString stringWithFormat:@"/usr/local/share/%@/LC_MONETARY", env_LC_MESSAGES])) {
                    NSString * content = [NSString stringWithContentsOfFile:[NSString stringWithFormat:@"/usr/local/share/%@/LC_MONETARY", env_LC_MESSAGES] encoding:NSUTF8StringEncoding error:nil];
                    if(content && [content isEqualToString:currency])
                        env_LC_MONETARY = env_LC_MESSAGES;
                }
                if(!env_LC_MONETARY) {
                    NSArray * locales = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/usr/share/locale" error:nil];
                    if(locales) {
                        for(NSString * locale in locales) {
                            if(!exist([NSString stringWithFormat:@"/usr/share/locale/%@/LC_MONETARY", locale]))
                                continue;
                            NSString * content = [NSString stringWithContentsOfFile:[NSString stringWithFormat:@"/usr/share/locale/%@/LC_MONETARY", locale] encoding:NSUTF8StringEncoding error:nil];
                            if(!content || [content rangeOfString:currency].location == NSNotFound)
                                continue;
                            NSRegularExpression * monetaryRegex = [NSRegularExpression regularExpressionWithPattern:@"^([[:alpha:]_]+)$" options:0 error:nil];
                            NSTextCheckingResult * monetaryTextCheckingResult = [monetaryRegex firstMatchInString:locale options:0 range:NSMakeRange(0, [locale length])];
                            if([monetaryTextCheckingResult numberOfRanges] < 1)
                                continue;
                            NSString * monetary = [locale substringWithRange:[monetaryTextCheckingResult rangeAtIndex:1]];
                            if(!monetary)
                                continue;
                            env_LC_MONETARY = monetary;
                            break;
                        }
                    }
                }
            }
        }
        // No currency value means that the AppleLocale governs:
        if(!env_LC_MONETARY)
            env_LC_MONETARY = substr(appleLocale, 0, 5);

        // For Gtk, which only looks at LC_ALL:
        if(env_LC_MESSAGES)
            setenv("LC_ALL", [env_LC_MESSAGES UTF8String], 0);

        if(exist([bundleLib stringByAppendingPathComponent:@"charset.alias"]))
            setenv("CHARSETALIASDIR", [bundleLib UTF8String], 0);

        if(env_LANG)
            setenv("LANG", [env_LANG UTF8String], 0);
        if(env_LC_MESSAGES)
            setenv("LC_MESSAGES", [env_LC_MESSAGES UTF8String], 0);
        if(env_LC_MONETARY)
            setenv("LC_MONETARY", [env_LC_MONETARY UTF8String], 0);
        if(env_LC_COLLATE)
            setenv("LC_COLLATE", [env_LC_COLLATE UTF8String], 0);
    }

    @autoreleasepool {
        const NSUInteger argumentsCount = (NSUInteger)(argc);
        NSMutableArray * arguments = [[NSMutableArray alloc] initWithCapacity:(argumentsCount - 1)];
        for(NSUInteger i = 1; i < argumentsCount; ++i) {
            NSString * argument = [NSString stringWithUTF8String:argv[i]];
            if(argument)
                [arguments addObject:argument];
        }

        NSTask * task = [[NSTask alloc] init];
        task.launchPath = [[[NSBundle mainBundle] executablePath] stringByAppendingString:@"-bin"];
        task.arguments = arguments;
        [task launch];
        [task waitUntilExit];
        return [task terminationStatus];
    }
}
