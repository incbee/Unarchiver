#import <XADMaster/XADSimpleUnarchiver.h>

#import "TUArchiveTaskView.h"


@class TUController,TUEncodingPopUp;

@interface TUArchiveController:NSObject
{
	TUArchiveTaskView *view;
	XADSimpleUnarchiver *unarchiver;
	NSString *archivename,*destination,*tmpdest;
	NSStringEncoding selected_encoding;

	id finishtarget;
	SEL finishselector;

	BOOL cancelled,ignoreall;

	#if MAC_OS_X_VERSION_MIN_REQUIRED>=1060
	BOOL isapp;
	#endif
}

+(void)clearGlobalPassword;

-(id)initWithFilename:(NSString *)filename taskView:(TUArchiveTaskView *)taskview;
-(void)dealloc;

-(BOOL)isCancelled;
-(NSString *)filename;
-(NSArray *)allFilenames;
-(BOOL)caresAboutPasswordEncoding;
-(TUArchiveTaskView *)taskView;

-(void)setIsCancelled:(BOOL)iscancelled;
-(void)setDestination:(NSString *)destination;

-(NSString *)currentArchiveName;
-(NSString *)localizedDescriptionOfError:(XADError)error;
-(NSString *)stringForXADPath:(XADPath *)path;

-(void)runWithFinishAction:(SEL)selector target:(id)target;

-(void)extractThreadEntry;
-(void)extract;
-(void)extractFinished;
-(void)extractFailed;
-(void)rememberTempDirectory:(NSString *)tmpdir;
-(void)forgetTempDirectory:(NSString *)tmpdir;

-(void)archiveTaskViewCancelled:(TUArchiveTaskView *)taskview;

@end
