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

	int foldermodeoverride,copydateoverride,changefilesoverride;
	int deletearchiveoverride,openextractedoverride;

	BOOL cancelled,ignoreall,haderrors;

	#ifndef IsLegacyVersion
	NSURL *scopedurl;
	#endif
}

+(void)clearGlobalPassword;

-(id)initWithFilename:(NSString *)filename;
-(void)dealloc;

-(TUArchiveTaskView *)taskView;
-(void)setTaskView:(TUArchiveTaskView *)taskview;
-(TUDockTileView *)dockTileView;
-(void)setDockTileView:(TUDockTileView *)tileview;
-(NSString *)destination;
-(void)setDestination:(NSString *)destination;
-(int)folderCreationMode;
-(void)setFolderCreationMode:(int)mode;
-(BOOL)copyArchiveDateToExtractedFolder;
-(void)setCopyArchiveDateToExtractedFolder:(BOOL)copydate;
-(BOOL)changeDateOfExtractedSingleItems;
-(void)setChangeDateOfExtractedSingleItems:(BOOL)changefiles;
-(BOOL)deleteArchive;
-(void)setDeleteArchive:(BOOL)delete;
-(BOOL)openExtractedItem;
-(void)setOpenExctractedItem:(BOOL)open;

-(BOOL)isCancelled;
-(void)setIsCancelled:(BOOL)iscancelled;

#ifndef IsLegacyVersion
-(void)useSecurityScopedURL:(NSURL *)url;
#endif

-(NSString *)filename;
-(NSArray *)allFilenames;
-(BOOL)volumeScanningFailed;
-(BOOL)caresAboutPasswordEncoding;

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
