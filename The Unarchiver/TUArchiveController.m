#import "TUArchiveController.h"
#import "TUController.h"
#import "TUTaskListView.h"
#import "TUEncodingPopUp.h"
#import <XADMaster/XADRegex.h>



static BOOL GetCatalogInfoForFilename(NSString *filename,FSCatalogInfoBitmap bitmap,FSCatalogInfo *info);
static BOOL SetCatalogInfoForFilename(NSString *filename,FSCatalogInfoBitmap bitmap,FSCatalogInfo *info);


static NSString *globalpassword=nil;


@implementation TUArchiveController

+(void)clearGlobalPassword
{
	[globalpassword release];
	globalpassword=nil;
}

-(id)initWithFilename:(NSString *)filename destination:(NSString *)destpath
taskView:(TUArchiveTaskView *)taskview
{
	if((self=[super init]))
	{
		maincontroller=nil;

		view=[taskview retain];
		unarchiver=nil;

		archivename=[filename retain];
		destination=[destpath retain];
		tmpdest=nil;

		selected_encoding=0;

		finishtarget=nil;
		finishselector=NULL;

		cancelled=NO;
		ignoreall=NO;
	}
	return self;
}

-(void)dealloc
{
	[view release];
	[unarchiver release];
	[archivename release];
	[destination release];
	[tmpdest release];

	[super dealloc];
}



// TODO: Rather than change the value, this should use unarchiver when available
-(NSString *)filename { return archivename; }

-(NSArray *)allFilenames { return [[unarchiver archiveParser] allFilenames]; }

-(TUArchiveTaskView *)taskView { return view; }



-(void)runWithFinishAction:(SEL)selector target:(id)target
{
	finishtarget=target;
	finishselector=selector;
	[self retain];

	[view setCancelAction:@selector(archiveTaskViewCancelled:) target:self];

	//[view setupProgressViewInPreparingMode];

	static int tmpcounter=0;
	NSString *tmpdir=[NSString stringWithFormat:@".TheUnarchiverTemp%d",tmpcounter++];
	tmpdest=[[destination stringByAppendingPathComponent:tmpdir] retain];

	[self rememberTempDirectory:tmpdest];

	[NSThread detachNewThreadSelector:@selector(extract) toTarget:self withObject:nil];
}

-(void)extract
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

	unarchiver=[[XADSimpleUnarchiver simpleUnarchiverForPath:archivename error:NULL] retain];
	if(!unarchiver)
	{
		[view displayOpenError:[NSString stringWithFormat:
		NSLocalizedString(@"The contents of the file \"%@\" can not be extracted with this program.",@"Error message for files not extractable by The Unarchiver"),
		[archivename lastPathComponent]]];

		[self performSelectorOnMainThread:@selector(extractFailed) withObject:nil waitUntilDone:NO];
		goto exit;
	}

	// TODO: remove this.
	[archivename release];
	archivename=[[[unarchiver archiveParser] filename] retain];

	BOOL alwayscreatepref=[[NSUserDefaults standardUserDefaults] integerForKey:@"createFolder"]==2;
	BOOL copydatepref=[[NSUserDefaults standardUserDefaults] integerForKey:@"folderModifiedDate"]==2;
	BOOL changefilespref=[[NSUserDefaults standardUserDefaults] boolForKey:@"changeDateOfFiles"];

	[unarchiver setDelegate:self];
	[unarchiver setDestination:tmpdest];
	[unarchiver setPropagatesRelevantMetadata:YES];
	[unarchiver setAlwaysRenamesFiles:YES];
	[unarchiver setRemovesEnclosingDirectoryForSoloItems:!alwayscreatepref];
	[unarchiver setCopiesArchiveModificationTimeToEnclosingDirectory:copydatepref];
	[unarchiver setCopiesArchiveModificationTimeToSoloItems:copydatepref && changefilespref];
	[unarchiver setResetsDateForSoloItems:!copydatepref && changefilespref];

	XADError error=[unarchiver parseAndUnarchive];
	if(error)
	{
		[self performSelectorOnMainThread:@selector(extractFailed) withObject:nil waitUntilDone:NO];
		goto exit;
	}

	[self performSelectorOnMainThread:@selector(extractFinished) withObject:nil waitUntilDone:NO];

	exit:
	[pool release];
}

-(void)extractFinished
{
	BOOL deletearchivepref=[[NSUserDefaults standardUserDefaults] boolForKey:@"deleteExtractedArchive"];
	BOOL openfolderpref=[[NSUserDefaults standardUserDefaults] boolForKey:@"openExtractedFolder"];

	BOOL soloitem=[unarchiver wasSoloItem];

	NSString *path=[unarchiver createdItem];
	NSString *filename=[path lastPathComponent];
	NSString *newpath=[destination stringByAppendingPathComponent:filename];

	// Check if we accidentally created a package.
	if(!soloitem)
	if([[NSWorkspace sharedWorkspace] isFilePackageAtPath:path])
	{
		newpath=[newpath stringByDeletingPathExtension];
	}

	// Avoid collisions.
	newpath=[unarchiver _findUniquePathForOriginalPath:newpath];

	// Move files into place
	[unarchiver _moveItemAtPath:path toPath:newpath];
	[unarchiver _removeItemAtPath:tmpdest];

	// Remove temporary directory from crash recovery list
	[self forgetTempDirectory:tmpdest];

	// Delete archive if requested
	if(deletearchivepref)
	{
		NSString *directory=[archivename stringByDeletingLastPathComponent];
		NSArray *allpaths=[[unarchiver archiveParser] allFilenames];
		NSMutableArray *allfiles=[NSMutableArray arrayWithCapacity:[allpaths count]];
		NSEnumerator *enumerator=[allpaths objectEnumerator];
		NSString *path;
		while((path=[enumerator nextObject]))
		{
			if([[path stringByDeletingLastPathComponent] isEqual:directory])
			[allfiles addObject:[path lastPathComponent]];
		}

		[[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
		source:directory destination:nil files:allfiles tag:nil];
		//[self playSound:@"/System/Library/Components/CoreAudio.component/Contents/Resources/SystemSounds/dock/drag to trash.aif"];
	}

	// Open folder if requested
	if(openfolderpref)
	{
		BOOL isdir;
		[[NSFileManager defaultManager] fileExistsAtPath:newpath isDirectory:&isdir];
		if(isdir&&![[NSWorkspace sharedWorkspace] isFilePackageAtPath:newpath])
		{
			[[NSWorkspace sharedWorkspace] openFile:newpath];
		}
		else
		{
			[[NSWorkspace sharedWorkspace] selectFile:newpath inFileViewerRootedAtPath:@""];
		}
	}

	[finishtarget performSelector:finishselector withObject:self];
	[self release];
}

-(void)extractFailed
{
	#if MAC_OS_X_VERSION_MIN_REQUIRED>=1050
	[[NSFileManager defaultManager] removeItemAtPath:tmpdest error:NULL];
	#else
	[[NSFileManager defaultManager] removeFileAtPath:tmpdest handler:nil];
	#endif

	[self forgetTempDirectory:tmpdest];

	[finishtarget performSelector:finishselector withObject:self];
	[self release];
}

-(void)rememberTempDirectory:(NSString *)tmpdir
{
	NSUserDefaults *defs=[NSUserDefaults standardUserDefaults];
	NSArray *tmpdirs=[defs arrayForKey:@"orphanedTempDirectories"];
	if(!tmpdirs) tmpdirs=[NSArray array];
	[defs setObject:[tmpdirs arrayByAddingObject:tmpdir] forKey:@"orphanedTempDirectories"];
	[defs synchronize];
}

-(void)forgetTempDirectory:(NSString *)tmpdir
{
	NSUserDefaults *defs=[NSUserDefaults standardUserDefaults];
	NSMutableArray *tmpdirs=[NSMutableArray arrayWithArray:[defs arrayForKey:@"orphanedTempDirectories"]];
	[tmpdirs removeObject:tmpdir];
	[defs setObject:tmpdirs forKey:@"orphanedTempDirectories"];
	[defs synchronize];
}




-(void)archiveTaskViewCancelled:(TUArchiveTaskView *)taskview
{
	cancelled=YES;
}




-(BOOL)extractionShouldStopForSimpleUnarchiver:(XADSimpleUnarchiver *)unarchiver
{
	return cancelled;
}

-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)sender encodingNameForXADString:(id <XADString>)string
{
	// TODO: Stop using NSStringEncoding.

	// If the user has set an encoding in the preferences, always use this.
	NSStringEncoding setencoding=[[NSUserDefaults standardUserDefaults] integerForKey:@"filenameEncoding"];
	if(setencoding) return [XADString encodingNameForEncoding:setencoding];

	XADStringSource *source=[[sender archiveParser] stringSource];
	NSStringEncoding guess=[source encoding];
	float confidence=[source confidence];

	int threshold=[[NSUserDefaults standardUserDefaults] integerForKey:@"autoDetectionThreshold"];

	// If the user has already been asked for an encoding, try to use it.
	// Otherwise, if the confidence in the guessed encoding is high enough, try that.
	NSStringEncoding encoding=0;
	if(selected_encoding) encoding=selected_encoding;
	else if(confidence*100<threshold) encoding=guess;

	// If we have an encoding we trust, and it can decode the string, use it.
	if(encoding && [string canDecodeWithEncoding:encoding])
	return [XADString encodingNameForEncoding:encoding];

	// Otherwise, ask the user for an encoding.
	selected_encoding=[view displayEncodingSelectorForXADString:string];
	if(!selected_encoding)
	{
		cancelled=YES;
		return nil;
	}
	return [XADString encodingNameForEncoding:selected_encoding];
}

-(void)simpleUnarchiverNeedsPassword:(XADSimpleUnarchiver *)sender
{
	if(globalpassword)
	{
		[sender setPassword:globalpassword];
	}
	else
	{
		BOOL applytoall;
		NSString *password=[view displayPasswordInputWithApplyToAllPointer:&applytoall];

		if(password)
		{
			[sender setPassword:password];
			if(applytoall) globalpassword=[password retain];
		}
		else
		{
			cancelled=YES;
		}
	}
}

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)sender willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	XADPath *name=[dict objectForKey:XADFileNameKey];
	if(name) [view setName:[name string]]; // TODO: what about encodings?
	else [view setName:@""];
}

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)sender
extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileProgress:(off_t)fileprogress of:(off_t)filesize
totalProgress:(off_t)totalprogress of:(off_t)totalsize
{
	[view setProgress:(double)totalprogress/(double)totalsize];
}

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)sender
estimatedExtractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileProgress:(double)fileprogress totalProgress:(double)totalprogress
{
	[view setProgress:totalprogress];
}

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)sender didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error;
{
	if(ignoreall||cancelled) return;

	if(error)
	{
		NSString *errstr=[XADException describeXADError:error];
		XADPath *filename=[dict objectForKey:XADFileNameKey];
		NSNumber *isresfork=[dict objectForKey:XADIsResourceForkKey];

		if(isresfork&&[isresfork boolValue])
		{
			cancelled=![view displayError:
				[NSString stringWithFormat:
				NSLocalizedString(@"Could not extract the resource fork for the file \"%@\":\n%@",@"Error message for resource forks. The first %@ is the file name, the second the error message"),
				[filename string], // TODO: encodings
				[[NSBundle mainBundle] localizedStringForKey:errstr value:errstr table:nil]]
			ignoreAll:&ignoreall];
		}
		else
		{
			cancelled=![view displayError:
				[NSString stringWithFormat:
				NSLocalizedString(@"Could not extract the file \"%@\": %@",@"Error message string. The first %@ is the file name, the second the error message"),
				[filename string], // TODO: encodings
				[[NSBundle mainBundle] localizedStringForKey:errstr value:errstr table:nil]]
			ignoreAll:&ignoreall];
		}
	}
}

/*-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)sender replacementPathForEntryWithDictionary:(NSDictionary *)dict
originalPath:(NSString *)path suggestedPath:(NSString *)unique;
-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)sender deferredReplacementPathForOriginalPath:(NSString *)path
suggestedPath:(NSString *)unique;*/

@end




static BOOL GetCatalogInfoForFilename(NSString *filename,FSCatalogInfoBitmap bitmap,FSCatalogInfo *info)
{
	FSRef ref;
	if(FSPathMakeRefWithOptions((const UInt8 *)[filename fileSystemRepresentation],
	kFSPathMakeRefDoNotFollowLeafSymlink,&ref,NULL)!=noErr) return NO;
	if(FSGetCatalogInfo(&ref,bitmap,info,NULL,NULL,NULL)!=noErr) return NO;
	return YES;
}

static BOOL SetCatalogInfoForFilename(NSString *filename,FSCatalogInfoBitmap bitmap,FSCatalogInfo *info)
{
	FSRef ref;
	if(FSPathMakeRefWithOptions((const UInt8 *)[filename fileSystemRepresentation],
	kFSPathMakeRefDoNotFollowLeafSymlink,&ref,NULL)!=noErr) return NO;
	if(FSSetCatalogInfo(&ref,bitmap,info)!=noErr) return NO;
	return YES;
}
