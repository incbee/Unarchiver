#import <XADMaster/XADSimpleUnarchiver.h>

#import "TUArchiveTaskView.h"


@class TUController,TUEncodingPopUp;

@interface TUArchiveController:NSObject
{
	TUController *maincontroller;
	TUArchiveTaskView *view;
	XADSimpleUnarchiver *unarchiver;
	NSString *archivename,*destination,*tmpdest;
	NSStringEncoding selected_encoding;

	id finishtarget;
	SEL finishselector;

	BOOL cancelled,ignoreall;
}

+(void)clearGlobalPassword;

-(id)initWithFilename:(NSString *)filename destination:(NSString *)destpath
taskView:(TUArchiveTaskView *)taskview;
-(void)dealloc;

-(NSString *)filename;
-(NSArray *)allFilenames;
-(TUArchiveTaskView *)taskView;

-(void)runWithFinishAction:(SEL)selector target:(id)target;

-(void)extract;
-(void)extractFinished;
-(void)extractFailed;
-(void)rememberTempDirectory:(NSString *)tmpdir;
-(void)forgetTempDirectory:(NSString *)tmpdir;

-(void)archiveTaskViewCancelled:(TUArchiveTaskView *)taskview;

@end
