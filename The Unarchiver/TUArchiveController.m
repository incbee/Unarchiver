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
	if(self=[super init])
	{
		cancelled=NO;
		ignoreall=NO;
		hasstopped=NO;

		view=[taskview retain];
		archivename=[filename retain];

		destination=[destpath retain];
		tmpdest=nil;
	}
	return self;
}

-(void)dealloc
{
	[view release];
	[archive release];
	[archivename release];
	[destination release];
	[tmpdest release];

	[super dealloc];
}



-(NSString *)filename { return archivename; }

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

	@try
	{
		archive=[[XADArchive alloc] initWithFile:archivename delegate:self error:NULL];

		if(!archive)
		{
			[view displayOpenError:[NSString stringWithFormat:
			NSLocalizedString(@"The contents of the file \"%@\" can not be extracted with this program.",@"Error message for files not extractable by The Unarchiver"),
			[archivename lastPathComponent]]];
			@throw @"Failed to open archive";
		}

		[archivename release];
		archivename=[[archive filename] retain];

		//[archive setDelegate:self];

		BOOL res=[archive extractTo:tmpdest subArchives:YES];
		if(!res) @throw @"Archive extraction failed or was cancelled";

		[self performSelectorOnMainThread:@selector(extractFinished) withObject:nil waitUntilDone:NO];
	}
	@catch(id e)
	{
		[self performSelectorOnMainThread:@selector(extractFailed) withObject:nil waitUntilDone:NO];
	}

	[pool release];
}

-(void)extractFinished
{
	NSFileManager *fm=[NSFileManager defaultManager];
	NSArray *files=[fm directoryContentsAtPath:tmpdest];

	if(files)
	{
		BOOL alwayscreatepref=[[NSUserDefaults standardUserDefaults] integerForKey:@"createFolder"]==2;
		BOOL copydatepref=[[NSUserDefaults standardUserDefaults] integerForKey:@"folderModifiedDate"]==2;
		BOOL changefilespref=[[NSUserDefaults standardUserDefaults] boolForKey:@"changeDateOfFiles"];
		BOOL deletearchivepref=[[NSUserDefaults standardUserDefaults] boolForKey:@"deleteExtractedArchive"];
		BOOL openfolderpref=[[NSUserDefaults standardUserDefaults] boolForKey:@"openExtractedFolder"];

		BOOL singlefile=[files count]==1;

		BOOL makefolder=!singlefile || alwayscreatepref;
		BOOL copydate=(makefolder&&copydatepref)||(!makefolder&&changefilespref&&copydatepref);
		BOOL resetdate=!makefolder&&changefilespref&&!copydatepref;

		NSString *finaldest;

		// Propagate quarantine
		if(LSSetItemAttribute)
		{
			FSRef src,dest;
			if(CFURLGetFSRef((CFURLRef)[NSURL fileURLWithPath:archivename],&src))
			if(CFURLGetFSRef((CFURLRef)[NSURL fileURLWithPath:tmpdest],&dest))
			{
				CFDictionaryRef dicref;
				if(LSCopyItemAttribute(&src,kLSRolesAll,kLSItemQuarantineProperties,(CFTypeRef*)&dicref)==noErr)
				if(dicref)
				{
					[self setQuarantineAttributes:dicref forDirectoryRef:&dest];
					CFRelease(dicref);
				}
			}
		}

		// Move files into place
		if(makefolder)
		{
			NSString *defaultname;
			if([archivename matchedByPattern:@"\\.(part[0-9]+\\.rar|tar\\.gz|tar\\.bz2|tar\\.lzma|sit\\.hqx)$" options:REG_ICASE])
			defaultname=[[[archivename lastPathComponent] stringByDeletingPathExtension] stringByDeletingPathExtension];
			else
			defaultname=[[archivename lastPathComponent] stringByDeletingPathExtension];

			finaldest=[self findUniqueDestinationWithDirectory:destination andFilename:defaultname];
			[fm movePath:tmpdest toPath:finaldest handler:nil];
		}
		else
		{
			NSString *filename=[files objectAtIndex:0];
			NSString *src=[tmpdest stringByAppendingPathComponent:filename];
			finaldest=[self findUniqueDestinationWithDirectory:destination andFilename:filename];
			[fm movePath:src toPath:finaldest handler:nil];
			[fm removeFileAtPath:tmpdest handler:nil];
		}

		// Remove temporary directory from crash recovery list
		[self forgetTempDirectory:tmpdest];

		// Set correct date for extracted directory
		if(copydate)
		{
			FSCatalogInfo archiveinfo,newinfo;

			GetCatalogInfoForFilename(archivename,kFSCatInfoContentMod,&archiveinfo);
			newinfo.contentModDate=archiveinfo.contentModDate;
			SetCatalogInfoForFilename(finaldest,kFSCatInfoContentMod,&newinfo);
		}
		else if(resetdate)
		{
			FSCatalogInfo newinfo;

			UCConvertCFAbsoluteTimeToUTCDateTime(CFAbsoluteTimeGetCurrent(),&newinfo.contentModDate);
			SetCatalogInfoForFilename(finaldest,kFSCatInfoContentMod,&newinfo);
		}

		// Delete archive if requested
		if(deletearchivepref)
		{
			NSString *directory=[archivename stringByDeletingLastPathComponent];
			NSArray *allpaths=[archive allFilenames];
			NSMutableArray *allfiles=[NSMutableArray arrayWithCapacity:[allpaths count]];
			NSEnumerator *enumerator=[allpaths objectEnumerator];
			NSString *path;
			while(path=[enumerator nextObject])
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
			[[NSFileManager defaultManager] fileExistsAtPath:finaldest isDirectory:&isdir];
			if(isdir&&![[NSWorkspace sharedWorkspace] isFilePackageAtPath:finaldest])
			{
				[[NSWorkspace sharedWorkspace] openFile:finaldest];
			}
			else [[NSWorkspace sharedWorkspace] selectFile:finaldest inFileViewerRootedAtPath:@""];
		}
	}

	[finishtarget performSelector:finishselector withObject:self];
	[self release];
}

-(void)extractFailed
{
	NSFileManager *fm=[NSFileManager defaultManager];
	[fm removeFileAtPath:tmpdest handler:nil];
	[self forgetTempDirectory:tmpdest];

	[finishtarget performSelector:finishselector withObject:self];
	[self release];
}

-(void)setQuarantineAttributes:(CFDictionaryRef)dicref forDirectoryRef:(FSRef *)dirref
{
	FSIterator iterator;
	if(FSOpenIterator(dirref,kFSIterateFlat,&iterator)!=noErr) return;

	for(;;)
	{
		FSRef ref;
		ItemCount num;
		OSErr err=FSGetCatalogInfoBulk(iterator,1,&num,NULL,kFSCatInfoNone,NULL,&ref,NULL,NULL);

		if(err==errFSNoMoreItems) break;

		LSSetItemAttribute(&ref,kLSRolesAll,kLSItemQuarantineProperties,dicref);

		FSCatalogInfo catinfo={0};
		FSGetCatalogInfo(&ref,kFSCatInfoNodeFlags,&catinfo,NULL,NULL,NULL);
		if(catinfo.nodeFlags&kFSNodeIsDirectoryMask)
		[self setQuarantineAttributes:dicref forDirectoryRef:&ref];
	}

	FSCloseIterator(iterator);
}

-(NSString *)findUniqueDestinationWithDirectory:(NSString *)directory andFilename:(NSString *)filename
{
	NSString *basename=[filename stringByDeletingPathExtension];
	NSString *extension=[filename pathExtension];
	if([extension length]) extension=[@"." stringByAppendingString:extension];

	NSString *dest=[directory stringByAppendingPathComponent:filename];
	int n=1;

	while([[NSFileManager defaultManager] fileExistsAtPath:dest])
	{
		dest=[directory stringByAppendingPathComponent:
		[NSString stringWithFormat:@"%@-%d%@",basename,n++,extension]];
	}

	return dest;
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



-(BOOL)archiveExtractionShouldStop:(XADArchive *)sender { return cancelled; }

-(NSStringEncoding)archive:(XADArchive *)sender encodingForData:(NSData *)data guess:(NSStringEncoding)guess confidence:(float)confidence
{
	NSStringEncoding encoding=[[NSUserDefaults standardUserDefaults] integerForKey:@"filenameEncoding"];
	int threshold=[[NSUserDefaults standardUserDefaults] integerForKey:@"autoDetectionThreshold"];

	if(cancelled) return guess;
	else if(encoding) return encoding;
	else if(selected_encoding) return selected_encoding;
	else if(confidence*100<threshold)
	{
		selected_encoding=[view displayEncodingSelectorForData:data encoding:guess];
		if(!selected_encoding)
		{
			cancelled=YES;
			return guess;
		}
		return selected_encoding;
	}
	else return guess;
}

-(void)archiveNeedsPassword:(XADArchive *)sender
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

-(void)archive:(XADArchive *)sender extractionOfEntryWillStart:(int)n
{
	NSString *name=[sender nameOfEntry:n];
	if(name) [view setName:name];
}

-(void)archive:(XADArchive *)sender extractionProgressBytes:(off_t)bytes of:(off_t)total
{
	[view setProgress:(double)bytes/(double)total];
}


-(XADAction)archive:(XADArchive *)archive nameDecodingDidFailForEntry:(int)n data:(NSData *)data
{
	return [view displayEncodingSelectorForData:data encoding:0];
}

-(XADAction)archive:(XADArchive *)archive creatingDirectoryDidFailForEntry:(int)n
{
	[view displayOpenError:[NSString stringWithFormat:
		NSLocalizedString(@"Could not write to the destination directory.",@"Error message string when writing is impossible.")]
	];
	return XADAbort;
}

-(XADAction)archive:(XADArchive *)sender extractionOfEntryDidFail:(int)n error:(XADError)error
{
	if(ignoreall) return XADSkip;
	if(hasstopped) return XADAbort;

	NSString *errstr=[archive describeError:error];
	XADAction action=[view displayError:
		[NSString stringWithFormat:
		NSLocalizedString(@"Could not extract the file \"%@\": %@",@"Error message string. The first %@ is the file name, the second the error message"),
		[sender nameOfEntry:n],[[NSBundle mainBundle] localizedStringForKey:errstr value:errstr table:nil]]
	ignoreAll:&ignoreall];

	if(action==XADAbort) hasstopped=YES;

	return action;
}

-(XADAction)archive:(XADArchive *)sender extractionOfResourceForkForEntryDidFail:(int)n error:(XADError)error
{
	if(ignoreall) return XADSkip;

	NSString *errstr=[archive describeError:error];
	return [view displayError:
		[NSString stringWithFormat:
		NSLocalizedString(@"Could not extract the resource fork for the file \"%@\":\n%@",@"Error message for resource forks. The first %@ is the file name, the second the error message"),
		[sender nameOfEntry:n],[[NSBundle mainBundle] localizedStringForKey:errstr value:errstr table:nil]]
	ignoreAll:&ignoreall];
}


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
