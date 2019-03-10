/*****************************************************************************
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2015 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "VLCMDFBrowsingArtworkProvider.h"
#import "MetaDataFetcherKit.h"

@interface VLCMDFBrowsingArtworkProvider () <MDFMovieDBFetcherDataRecipient>
{
    MDFMovieDBFetcher *_tmdbFetcher;
}

@end

@implementation VLCMDFBrowsingArtworkProvider

- (void)reset
{
    if (_tmdbFetcher) {
        [_tmdbFetcher cancelAllRequests];
    } else {
        _tmdbFetcher = [[MDFMovieDBFetcher alloc] init];
        _tmdbFetcher.dataRecipient = self;
        _tmdbFetcher.shouldDecrapifyInputStrings = YES;
    }
}

+ (void)purgeCache {
    NSString *cacheDirectory = [VLCMDFBrowsingArtworkProvider cacheDirectory];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:cacheDirectory];
    NSString *file;
    
    while (file = [enumerator nextObject]) {
        NSError *error = nil;
        NSString *pathToRemove = [cacheDirectory stringByAppendingPathComponent:file];
        BOOL result = [fileManager removeItemAtPath:pathToRemove error:&error];
        
        if (!result && error) {
            NSLog(@"Error: %@", error);
        }
    }
}

+ (NSString*)cacheDirectory {
    NSString *cachesPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString *thumbnailCaches = [cachesPath stringByAppendingPathComponent:@"Thumbnails"];
    
    NSError * error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:thumbnailCaches
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    if (error != nil) {
        NSLog(@"Error creating thumbnail cache directory: %@", error);
    }
    
    return thumbnailCaches;
}

- (NSString*)pathForCachedFile:(NSString*)named
{
    // Set of disallowed file filename characters
    NSCharacterSet *trimSet = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>"];
    
    // Trim path extension and special characters from filenames.
    NSString *fileName = [named stringByDeletingPathExtension];
    NSString *trimmedName = [fileName stringByTrimmingCharactersInSet: trimSet];
    NSString *cacheFileBase = [NSString stringWithFormat:@"%@.jpg", trimmedName];

    NSString *cacheFile = [[VLCMDFBrowsingArtworkProvider cacheDirectory] stringByAppendingPathComponent:cacheFileBase];
    
    return cacheFile;
}

-(void)saveDataToCache:(NSData*)data named:(NSString*)name
{
    NSString *cacheFile = [self pathForCachedFile:name];
    [data writeToFile:cacheFile atomically:YES];
}

- (void)setSearchForAudioMetadata:(BOOL)searchForAudioMetadata
{
    NSLog(@"there is currently no audio metadata fetcher :-(");
}

- (void)searchForArtworkForVideoRelatedString:(NSString *)string
{
    // Replace match of regex with the year filters,
    // in order to match the format tmdb uses for search.
    //
    // Example: "Ghostbusters (1984)" -> "Ghostbusters y:1984"
    NSString *releaseYear = nil;
    NSError *err = nil;
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern: @"\\s\\((\\d{4})\\)$" options:NSRegularExpressionCaseInsensitive error:&err];
    
    // Search for matches
    NSString *basename = [string stringByDeletingPathExtension];
    NSArray *matches = [re matchesInString:string options:NSMatchingWithTransparentBounds range:NSMakeRange(0, [basename length])];
    
    // Parse capture groups
    for (NSTextCheckingResult *match in matches) {
        NSRange matchRange = [match rangeAtIndex:1];
        NSString *matchString = [string substringWithRange:matchRange];
        releaseYear = matchString;
    }

    // Remove extra data to prepare foe search
    NSString * searchString = string;
    if (err == nil) {
        searchString = [re stringByReplacingMatchesInString:searchString options:0 range:NSMakeRange(0, [basename length]) withTemplate:@""];
    } else {
        NSLog(@"Error: Could not initialize regex for artwork year annotations: %@", err);
    }
    
    [_tmdbFetcher searchForMovie:searchString releaseYear:releaseYear language:nil includeAdult:NO];
//    [_tmdbFetcher searchForMovie:string];
}

#pragma mark - MDFMovieDB

- (void)MDFMovieDBFetcher:(MDFMovieDBFetcher *)aFetcher didFindMovie:(MDFMovie *)details forSearchRequest:(NSString *)searchRequest
{
    if (details == nil) {
        return;
    }
    [aFetcher cancelAllRequests];
    MDFMovieDBSessionManager *sessionManager = [MDFMovieDBSessionManager sharedInstance];
    if (!sessionManager.hasFetchedProperties) {
        return;
    }

    if (details.movieDBID == 0) {
        /* we found nothing, let's see if it's a TV show */
        [_tmdbFetcher searchForTVShow:searchRequest];
        return;
    }

    NSString *imagePath = details.posterPath;
    NSArray *sizes = sessionManager.posterSizes;
    NSString *imageSize;

    if (sizes != nil) {
        NSUInteger count = sizes.count;
        if (count > 1) {
            imageSize = sizes[1];
        } else if (count > 0) {
            imageSize = sizes.firstObject;
        }
    }

    if (!imagePath) {
        imagePath = details.backdropPath;
        sizes = sessionManager.backdropSizes;
        if (sizes != nil && sizes.count > 0) {
            imageSize = sizes.firstObject;
        }
    }
    if (!imagePath) {
        return;
    }

    NSString *thumbnailURLString = [NSString stringWithFormat:@"%@%@%@",
                                    sessionManager.imageBaseURL,
                                    imageSize,
                                    imagePath];
    self.artworkReceiver.thumbnailURL = [NSURL URLWithString:thumbnailURLString];
}

- (void)MDFMovieDBFetcher:(MDFMovieDBFetcher *)aFetcher didFailToFindMovieForSearchRequest:(NSString *)searchRequest
{
    APLog(@"Failed to find a movie for '%@'", searchRequest);
}

- (void)MDFMovieDBFetcher:(MDFMovieDBFetcher *)aFetcher didFindTVShow:(MDFTVShow *)details forSearchRequest:(NSString *)searchRequest
{
    if (details == nil) {
        return;
    }

    [aFetcher cancelAllRequests];
    MDFMovieDBSessionManager *sessionManager = [MDFMovieDBSessionManager sharedInstance];
    if (!sessionManager.hasFetchedProperties)
        return;

    NSString *imagePath = details.posterPath;
    NSArray *sizes = sessionManager.posterSizes;
    NSString *imageSize;

    if (sizes != nil) {
        NSUInteger count = sizes.count;
        if (count > 1) {
            imageSize = sizes[1];
        } else if (count > 0) {
            imageSize = sizes.firstObject;
        }
    }

    if (!imagePath) {
        imagePath = details.backdropPath;
        sizes = sessionManager.backdropSizes;
        if (sizes != nil && sizes.count > 0) {
            imageSize = sizes.firstObject;
        }
    }
    if (!imagePath) {
        return;
    }

    NSString *thumbnailURLString = [NSString stringWithFormat:@"%@%@%@",
                                    sessionManager.imageBaseURL,
                                    imageSize,
                                    imagePath];
    self.artworkReceiver.thumbnailURL = [NSURL URLWithString:thumbnailURLString];
}

- (void)MDFMovieDBFetcher:(MDFMovieDBFetcher *)aFetcher didFailToFindTVShowForSearchRequest:(NSString *)searchRequest
{
    APLog(@"failed to find TV show");
}

@end
