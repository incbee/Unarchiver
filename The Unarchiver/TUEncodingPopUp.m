//
//  TUEncodingPopUp.m
//  The Unarchiver
//
//  Created by Dag Ågren on 2006-07-08.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "TUEncodingPopUp.h"


@implementation TUEncodingPopUp

-(id)initWithFrame:(NSRect)frame
{
	if(self=[super initWithFrame:frame])
	{
		//[self buildEncodingList];
	}
	return self;
}

-(id)initWithCoder:(NSCoder *)coder
{
	if(self=[super initWithCoder:coder])
	{
		//[self buildEncodingList];
	}
	return self;
}

-(void)buildEncodingList
{
	[self buildEncodingListMatchingData:nil];
}

-(void)buildEncodingListWithAutoDetect
{
	[self buildEncodingListMatchingData:nil];

	[[self menu] addItem:[NSMenuItem separatorItem]];

	NSMenuItem *item=[[NSMenuItem alloc] init];
	[item setTitle:NSLocalizedString(@"Detect automatically",@"Option in the encoding pop-up to detect the encoding automatically")];
	[item setTag:0];
	[[self menu] addItem:item];
	[item release];
}

-(void)buildEncodingListMatchingData:(NSData *)data
{
	[self removeAllItems];

	NSMutableDictionary *normalattrs,*smallattrs;
	if(data)
	{
		normalattrs=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			[NSFont menuFontOfSize:[NSFont systemFontSize]],NSFontAttributeName,
		nil];
		smallattrs=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			[NSFont menuFontOfSize:[NSFont smallSystemFontSize]],NSFontAttributeName,
		nil];

		float maxwidth=[[self class] maximumEncodingNameWidthWithAttributes:normalattrs];

		NSMutableParagraphStyle *parastyle=[[NSMutableParagraphStyle new] autorelease];
		[parastyle setTabStops:[NSArray arrayWithObjects:
			[[[NSTextTab alloc] initWithType:NSLeftTabStopType location:maxwidth+10] autorelease],
		nil]];

		[normalattrs setObject:parastyle forKey:NSParagraphStyleAttributeName];
		[smallattrs setObject:parastyle forKey:NSParagraphStyleAttributeName];
	}

	NSArray *encodings=[[self class] encodings];
	NSEnumerator *enumerator=[encodings objectEnumerator];
	NSDictionary *encdict;
	while(encdict=[enumerator nextObject])
	{
		NSStringEncoding encoding=[[encdict objectForKey:@"Encoding"] longValue];

		NSString *str=nil;
		if(data)
		{
			str=[[NSString alloc] initWithData:data encoding:encoding];
			if(!str) continue;
		}

		NSString *encname=[encdict objectForKey:@"Name"];
		NSMenuItem *item=[[NSMenuItem alloc] init];

		if(str)
		{
			NSMutableAttributedString *attrstr=[[[NSMutableAttributedString alloc]
			initWithString:[NSString stringWithFormat:@"%@\t%C %@",encname,0x27a4,str]
			attributes:normalattrs] autorelease];
			[attrstr setAttributes:smallattrs range:NSMakeRange([encname length],[str length]+3)];

			[item setAttributedTitle:attrstr];
		}
		else
		{
			[item setTitle:encname];
		}

		[item setTag:encoding];
		[[self menu] addItem:item];

		[item release];
		[str release];
	}
}


NSComparisonResult encoding_sort(NSDictionary *enc1,NSDictionary *enc2,void *dummy)
{
	NSString *name1=[enc1 objectForKey:@"Name"];
	NSString *name2=[enc2 objectForKey:@"Name"];
	/*BOOL isunicode1=[name1 hasPrefix:@"Unicode"];
	BOOL isunicode2=[name2 hasPrefix:@"Unicode"];

	if(isunicode1&&!isunicode2) return NSOrderedAscending;
	else if(!isunicode1&&isunicode2) return NSOrderedDescending;
	else*/ return [name1 compare:name2 options:NSCaseInsensitiveSearch|NSNumericSearch];
}

+(NSArray *)encodings
{
	NSMutableArray *encodingarray=[NSMutableArray array];
	const CFStringEncoding *encodings=CFStringGetListOfAvailableEncodings();

	while(*encodings!=kCFStringEncodingInvalidId)
	{
		CFStringEncoding cfencoding=*encodings++;
		NSString *name=[NSString localizedNameOfStringEncoding:CFStringConvertEncodingToNSStringEncoding(cfencoding)];
		NSStringEncoding encoding=CFStringConvertEncodingToNSStringEncoding(cfencoding);

		if(!name) continue;
		if(encoding==10) continue;

		[encodingarray addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			name,@"Name",
			[NSNumber numberWithLong:encoding],@"Encoding",
		nil]];
	}

	return [encodingarray sortedArrayUsingFunction:encoding_sort context:nil];
}

+(float)maximumEncodingNameWidthWithAttributes:(NSDictionary *)attrs
{
	float maxwidth=0;

	NSArray *encodings=[[self class] encodings];
	NSEnumerator *enumerator=[encodings objectEnumerator];
	NSDictionary *encdict;
	while(encdict=[enumerator nextObject])
	{
		NSString *name=[encdict objectForKey:@"Name"];
		float width=[name sizeWithAttributes:attrs].width;
		if(width>maxwidth) maxwidth=width;
	}
	return maxwidth;
}

@end

/*+(NSDictionary *)encodingDictionary
{
	static NSDictionary *encodingdict=nil;
	if(!encodingdict) encodingdict=[[NSDictionary alloc] initWithObjectsAndKeys:
		[NSNumber numberWithUnsignedInt:NSASCIIStringEncoding],@"US-ASCII",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)],@"Big5",
		[NSNumber numberWithUnsignedInt:NSJapaneseEUCStringEncoding],@"EUC-JP",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_KR)],@"EUC-KR",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)],@"GB18030",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_2312_80)],@"GB2312",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingHZ_GB_2312)],@"HZ-GB-2312",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSCyrillic)],@"IBM855",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSRussian)],@"IBM866",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISO_2022_CN)],@"ISO-2022-CN",
		[NSNumber numberWithUnsignedInt:NSISO2022JPStringEncoding],@"ISO-2022-JP",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISO_2022_KR)],@"ISO-2022-KR",
		[NSNumber numberWithUnsignedInt:NSISOLatin2StringEncoding],@"ISO-8859-2",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinCyrillic)],@"ISO-8859-5",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinGreek)],@"ISO-8859-7",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinHebrew)],@"ISO-8859-8",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinHebrew)],@"ISO-8859-8-I", // not sure about this!
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingKOI8_R)],@"KOI8-R",
		[NSNumber numberWithUnsignedInt:NSShiftJISStringEncoding],@"Shift_JIS",
		// TIS-620 - missing
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF16BE)],@"UTF-16BE",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF16LE)],@"UTF-16LE",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF32BE)],@"UTF-32BE",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF32LE)],@"UTF-32LE",
		[NSNumber numberWithUnsignedInt:NSUTF8StringEncoding],@"UTF-8",
		// X-ISO-10646-UCS-4-2143 - missing
		// X-ISO-10646-UCS-4-3412 - missing
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)],@"gb18030",
		[NSNumber numberWithUnsignedInt:NSWindowsCP1250StringEncoding],@"windows-1250",
		[NSNumber numberWithUnsignedInt:NSWindowsCP1251StringEncoding],@"windows-1251",
		[NSNumber numberWithUnsignedInt:NSWindowsCP1252StringEncoding],@"windows-1252",
		[NSNumber numberWithUnsignedInt:NSWindowsCP1253StringEncoding],@"windows-1253",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsHebrew)],@"windows-1255",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_TW)],@"x-euc-tw",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacCyrillic)],@"x-mac-cyrillic",
		[NSNumber numberWithUnsignedInt:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacHebrew)],@"x-mac-hebrew",
	nil];
	return encodingdict;
}*/
