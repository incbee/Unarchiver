#import <XADMaster/XADSimpleUnarchiver.h>

#import "TUArchiveTaskView.h"
#import "TUDockTileView.h"

@class TUController,TUEncodingPopUp;

@interface TUArchiveController:NSObject
{
	TUArchiveTaskView *view;
	TUDockTileView *docktile;
	XADSimpleUnarchiver *unarchiver;
	NSString *archivename,*destination,*tmpdest;
	NSStringEncoding selected_encoding;

	id finishtarget;
	SEL finishselector;

	BOOL cancelled,ignoreall,haderrors;
}

+(void)clearGlobalPassword;

-(id)initWithFilename:(NSString *)filename taskView:(TUArchiveTaskView *)taskview;
-(void)dealloc;

-(BOOL)isCancelled;
-(void)setIsCancelled:(BOOL)iscancelled;
-(NSString *)destination;
-(void)setDestination:(NSString *)destination;
-(NSString *)filename;
-(NSArray *)allFilenames;
-(BOOL)volumeScanningFailed;
-(BOOL)caresAboutPasswordEncoding;
-(TUArchiveTaskView *)taskView;
-(void)setDockTileView:(TUDockTileView *)tileview;

-(NSString *)currentArchiveName;
-(NSString *)localizedDescriptionOfError:(XADError)error;
-(NSString *)stringForXADPath:(XADPath *)path;

-(void)prepare;
-(void)runWithFinishAction:(SEL)selector target:(id)target;

-(void)extractThreadEntry;
-(void)extract;
-(void)extractFinished;
-(void)extractFailed;
-(void)rememberTempDirectory:(NSString *)tmpdir;
-(void)forgetTempDirectory:(NSString *)tmpdir;

-(void)archiveTaskViewCancelled:(TUArchiveTaskView *)taskview;

@end
