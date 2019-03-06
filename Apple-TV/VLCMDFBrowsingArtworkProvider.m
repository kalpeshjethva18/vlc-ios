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

- (NSString*)cacheDirectory {
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

    NSString *cacheFile = [[self cacheDirectory] stringByAppendingPathComponent:cacheFileBase];
    
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
    NSString *cacheFile = [self pathForCachedFile:string];
    NSURL *cacheFileURL = [NSURL fileURLWithPath:cacheFile];

    // If a cached thumbnail exists for the name, load it in the background.
    if ([[NSFileManager defaultManager] fileExistsAtPath:cacheFile]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            // Load from disk
            NSData *data = [NSData dataWithContentsOfURL:cacheFileURL];

            // Load image data
            UIImage *image = [UIImage imageWithData: data];
            
            // Assign artwork thumbnail on main thread.
            dispatch_async(dispatch_get_main_queue(), ^{
                self.artworkReceiver.thumbnailImage = image;
            });
        });
        return;
    }

    [_tmdbFetcher searchForMovie:string];
}

- (void)downloadAndCacheFile:(NSString*)thumbnailUrl forSearchQuery:(NSString*)searchRequest
{
    // In the background, download the file, and convert to UIImage.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        // Download File
        NSURL *url = [NSURL URLWithString:thumbnailUrl];
        NSData *data = [NSData dataWithContentsOfURL:url];
        
        if (data != nil) {
            // Save data to cache
            [self saveDataToCache:data named:searchRequest];
            
            // Convert to UIImage
            UIImage *image = [UIImage imageWithData:data];
            
            // Assign artwork thumbnail on main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                self.artworkReceiver.thumbnailImage = image;
            });
        }
    });
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
    
    [self downloadAndCacheFile:thumbnailURLString forSearchQuery:searchRequest];
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

    [self downloadAndCacheFile:thumbnailURLString forSearchQuery:searchRequest];
}

- (void)MDFMovieDBFetcher:(MDFMovieDBFetcher *)aFetcher didFailToFindTVShowForSearchRequest:(NSString *)searchRequest
{
    APLog(@"failed to find TV show");
}

@end
