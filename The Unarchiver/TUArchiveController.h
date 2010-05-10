#import <XADMaster/XADArchive.h>

#import "TUArchiveTaskView.h"


@class TUController,TUEncodingPopUp;

@interface TUArchiveController:NSObject
{
	TUController *maincontroller;
	TUArchiveTaskView *view;
	XADArchive *archive;
	NSString *archivename,*destination,*tmpdest;
	NSStringEncoding selected_encoding;

	id finishtarget;
	SEL finishselector;

	BOOL cancelled,hasstopped,ignoreall;
}

+(void)clearGlobalPassword;

-(id)initWithFilename:(NSString *)filename destination:(NSString *)destpath
taskView:(TUArchiveTaskView *)taskview;
-(void)dealloc;

-(NSString *)filename;
-(XADArchive *)archive;
-(TUArchiveTaskView *)taskView;

-(void)runWithFinishAction:(SEL)selector target:(id)target;

-(void)extract;
-(void)extractFinished;
-(void)extractFailed;
-(void)setQuarantineAttributes:(CFDictionaryRef)dicref forDirectoryRef:(FSRef *)dirref;
-(NSString *)findUniqueDestinationWithDirectory:(NSString *)directory andFilename:(NSString *)filename;
-(void)rememberTempDirectory:(NSString *)tmpdir;
-(void)forgetTempDirectory:(NSString *)tmpdir;

-(void)archiveTaskViewCancelled:(TUArchiveTaskView *)taskview;

-(BOOL)archiveExtractionShouldStop:(XADArchive *)archive;

-(NSStringEncoding)archive:(XADArchive *)archive encodingForData:(NSData *)data guess:(NSStringEncoding)guess confidence:(float)confidence;

-(void)archive:(XADArchive *)msgarchive extractionOfEntryWillStart:(int)n;
-(void)archive:(XADArchive *)sender extractionProgressBytes:(off_t)bytes of:(off_t)total;
-(XADAction)archive:(XADArchive *)archive nameDecodingDidFailForEntry:(int)n data:(NSData *)data;
-(XADAction)archive:(XADArchive *)archive creatingDirectoryDidFailForEntry:(int)n;
-(XADAction)archive:(XADArchive *)sender extractionOfEntryDidFail:(int)n error:(XADError)error;
-(XADAction)archive:(XADArchive *)sender extractionOfResourceForkForEntryDidFail:(int)n error:(XADError)error;

@end
