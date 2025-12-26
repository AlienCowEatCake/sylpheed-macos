/*
clang enchant.m -O3 \
    -dynamiclib -fPIC \
    -current_version 11.14.0 \
    -compatibility_version 11.0.0 \
    -mmacos-version-min=10.9 \
    -framework AppKit \
    -framework Foundation \
    -Wall -Wextra \
    -o libenchant-2.dylib \
    -install_name "${PWD}/libenchant-2.dylib"
*/

#include "enchant.h"

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* gtkspell-2.0.16:
enchant_broker_free
enchant_broker_free_dict
enchant_broker_init
enchant_broker_list_dicts
enchant_broker_request_dict
enchant_dict_add_to_pwl => enchant_dict_add
enchant_dict_add_to_session
enchant_dict_check
enchant_dict_describe
enchant_dict_free_string_list
enchant_dict_store_replacement
enchant_dict_suggest
*/

static BOOL ENCHANT_DEBUG = NO;

#define dprintf(fmt, ...) do { \
    if(ENCHANT_DEBUG) { \
        @autoreleasepool { \
            fprintf(stderr, "[ENCHANT_DEBUG] %s:%d: " fmt "\n", __FUNCTION__, __LINE__, ##__VA_ARGS__); \
            fflush(stderr); \
        } \
    } \
} while (0)

struct _EnchantBroker
{
    NSSpellChecker *checker;
};

struct _EnchantDict
{
    NSSpellChecker *checker;
    NSArray<NSString*> *languages;
    NSMutableSet<NSString*> *ignores;
};

EnchantBroker *enchant_broker_init(void)
{
    ENCHANT_DEBUG = !!getenv("ENCHANT_DEBUG");
    dprintf();
    EnchantBroker *broker = (EnchantBroker*)malloc(sizeof(EnchantBroker));
    broker->checker = [NSSpellChecker sharedSpellChecker];
    return broker;
}

void enchant_broker_free(EnchantBroker *broker)
{
    dprintf();
    if(!broker)
        return;
    free(broker);
}

EnchantDict *enchant_broker_request_dict(EnchantBroker *broker, const char *const tag)
{
    dprintf("tag=%s", (tag ? tag : "NULL"));
    if(!broker || !tag)
        return NULL;
    EnchantDict *dict = (EnchantDict*)malloc(sizeof(EnchantDict));
    dict->checker = broker->checker;
    @autoreleasepool {
        NSMutableArray<NSString*> *languages = [NSMutableArray array];
        NSArray<NSString*> *subtags = [[NSString stringWithUTF8String:tag] componentsSeparatedByString:@","];
        for(NSString *subtag in subtags)
        {
            [dict->checker setAutomaticallyIdentifiesLanguages:NO];
            BOOL ok = [dict->checker setLanguage:[subtag stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
            if(ok)
                [languages addObject:[dict->checker language]];
        }
        if([languages count] == 0)
        {
            free(dict);
            return NULL;
        }
        dict->languages = [[NSArray alloc] initWithArray:languages];
        dict->ignores = [[NSMutableSet alloc] init];
    }
    return dict;
}

void enchant_broker_free_dict(EnchantBroker *broker, EnchantDict *dict)
{
    dprintf();
    if(!broker || !dict)
        return;
    [dict->languages release];
    [dict->ignores release];
    free(dict);
}

int enchant_dict_check(EnchantDict *dict, const char *const word, ssize_t len)
{
    dprintf("lang=%s, word=%s", (dict ? [[dict->languages componentsJoinedByString:@","] UTF8String] : "NULL"), (word ? word : "NULL"));
    if(!dict || !word)
        return -1;
    @autoreleasepool {
        if(len < 0)
            len = (ssize_t)strlen(word);
        NSString *str = [[NSString alloc] initWithBytes:word length:(NSUInteger)len encoding:NSUTF8StringEncoding];
        if(!str)
            return -1;
        if([dict->ignores containsObject:str])
        {
            [str release];
            dprintf("lang=%s, result=%s", [[dict->languages componentsJoinedByString:@","] UTF8String], "IGNORED");
            return 0;
        }
        BOOL check_ok = NO;
        for(NSString *language in dict->languages)
        {
            [dict->checker setAutomaticallyIdentifiesLanguages:NO];
            [dict->checker setLanguage:language];
            NSRange result = [dict->checker checkSpellingOfString:str startingAt:0];
            dprintf("lang=%s, result=%s", [language UTF8String], (result.length ? "BAD" : "GOOD"));
            if(result.length)
                continue;
            check_ok = YES;
            break;
        }
        [str release];
        if(!check_ok)
            return 1;
    }
    return 0;
}

char **enchant_dict_suggest(EnchantDict *dict, const char *const word, ssize_t len, size_t *out_n_suggs)
{
    dprintf("lang=%s, word=%s", (dict ? [[dict->languages componentsJoinedByString:@","] UTF8String] : "NULL"), (word ? word : "NULL"));
    if(!dict || !word || !out_n_suggs)
        return NULL;
    *out_n_suggs = 0;
    @autoreleasepool {
        if(len < 0)
            len = (ssize_t)strlen(word);
        NSString *str = [[NSString alloc] initWithBytes:word length:(NSUInteger)len encoding:NSUTF8StringEncoding];
        if(!str)
            return NULL;
        NSRange range = NSMakeRange(0, [str length]);
        NSMutableArray<NSString*> *guesses = [NSMutableArray array];
        for(NSString *language in dict->languages)
        {
            [dict->checker setAutomaticallyIdentifiesLanguages:NO];
            [dict->checker setLanguage:language];
            NSArray<NSString*> *suggestions = [dict->checker guessesForWordRange:range inString:str language:language inSpellDocumentWithTag:0];
            [guesses addObjectsFromArray:suggestions];
            for(NSString* suggestion in suggestions)
                dprintf("lang=%s, suggest=%s", [language UTF8String], [suggestion UTF8String]);
        }
        [str release];
        *out_n_suggs = [guesses count];
        char **result = (char**)malloc((*out_n_suggs + 1) * sizeof(char*));
        char **curr = result;
        for(NSString *guess in guesses)
        {
            const NSUInteger guess_len = [guess lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1;
            *curr = (char*)malloc(sizeof(char) * guess_len);
            [guess getCString:(*curr) maxLength:guess_len encoding:NSUTF8StringEncoding];
            dprintf("lang=%s, guess_len=%lu, result=%s", [[dict->languages componentsJoinedByString:@","] UTF8String], (unsigned long)guess_len, *curr);
            ++curr;
        }
        *curr = NULL;
        return result;
    }
    return NULL;
}

void enchant_dict_add(EnchantDict *dict, const char *const word, ssize_t len)
{
    dprintf("lang=%s, word=%s", (dict ? [[dict->languages componentsJoinedByString:@","] UTF8String] : "NULL"), (word ? word : "NULL"));
    if(!dict || !word)
        return;
    @autoreleasepool {
        if(len < 0)
            len = (ssize_t)strlen(word);
        NSString *str = [[NSString alloc] initWithBytes:word length:(NSUInteger)len encoding:NSUTF8StringEncoding];
        if(!str)
            return;
        NSString *language = dict->languages[0];
        [dict->checker setAutomaticallyIdentifiesLanguages:NO];
        [dict->checker setLanguage:language];
        [dict->checker learnWord:str];
        [str release];
    }
}

void enchant_dict_add_to_session(EnchantDict *dict, const char *const word, ssize_t len)
{
    dprintf("lang=%s, word=%s", (dict ? [[dict->languages componentsJoinedByString:@","] UTF8String] : "NULL"), (word ? word : "NULL"));
    if(!dict || !word)
        return;
    @autoreleasepool {
        if(len < 0)
            len = (ssize_t)strlen(word);
        NSString *str = [[NSString alloc] initWithBytes:word length:(NSUInteger)len encoding:NSUTF8StringEncoding];
        if(!str)
            return;
        [dict->ignores addObject:str];
        [str release];
    }
}

void enchant_dict_store_replacement(EnchantDict *dict, const char *const mis, ssize_t mis_len, const char *const cor, ssize_t cor_len)
{
    dprintf("lang=%s, mis=%s, cor=%s", (dict ? [[dict->languages componentsJoinedByString:@","] UTF8String] : "NULL"), (mis ? mis : "NULL"), (cor ? cor : "NULL"));
    dprintf("NOT_IMPLEMENTED");
    (void)(dict);
    (void)(mis);
    (void)(mis_len);
    (void)(cor);
    (void)(cor_len);
}

void enchant_dict_free_string_list(EnchantDict *dict, char **string_list)
{
    dprintf();
    if(!dict || !string_list)
        return;
    for(char **curr = string_list; *curr; ++curr)
        free(*curr);
    free(string_list);
}

void enchant_dict_describe(EnchantDict *dict, EnchantDictDescribeFn fn, void *user_data)
{
    dprintf();
    if(!dict || !fn)
        return;
    @autoreleasepool {
        NSString *language = dict->languages[0];
        dprintf("lang=%s", [language UTF8String]);
        fn([language UTF8String], "AppleSpell", "AppleSpell Provider", "enchant_applespell.so", user_data);
    }
}

void enchant_broker_list_dicts(EnchantBroker *broker, EnchantDictDescribeFn fn, void *user_data)
{
    dprintf();
    if(!broker || !fn)
        return;
    @autoreleasepool {
        for(NSString *lang in [broker->checker availableLanguages])
        {
            dprintf("lang=%s", [lang UTF8String]);
            fn([lang UTF8String], "AppleSpell", "AppleSpell Provider", "enchant_applespell.so", user_data);
        }
    }
}
