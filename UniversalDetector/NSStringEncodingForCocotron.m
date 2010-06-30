#import "NSStringEncodingForCocotron.h"

#import <objc/objc.h>

void Swizzle(Class class,SEL old,SEL new)
{
	Method oldmethod=class_getInstanceMethod(class,old);
	Method newmethod=class_getInstanceMethod(class,new);

	if(class_addMethod(class,old,method_getImplementation(newmethod),
	method_getTypeEncoding(newmethod)))
	{
		class_replaceMethod(class,new,method_getImplementation(oldmethod),
		method_getTypeEncoding(oldmethod));
	}
	else
	{
		method_exchangeImplementations(oldmethod,newmethod);
	}
}



@interface NSString (WindowsCodepage)
@end

@implementation NSString (WindowsCodepage)

#ifndef MB_ERR_INVALID_CHARS
#define MB_ERR_INVALID_CHARS 0x8
#endif

-(id)swizzledInitWithBytes:(const void *)bytes length:(NSUInteger)length
encoding:(NSStringEncoding)encoding
{
	if(IsNSStringEncodingWindowsCodePage(encoding))
	{
		int codepage=NSStringEncodingToWindowsCodePage(encoding);
		int numchars=MultiByteToWideChar(codepage,MB_ERR_INVALID_CHARS,bytes,length,NULL,0);
		if(numchars==0)
		{
			[self release];
			return nil;
		}

		unichar *buffer=malloc(sizeof(unichar)*numchars);
		MultiByteToWideChar(codepage,MB_ERR_INVALID_CHARS,bytes,length,buffer,numchars);

		return [self initWithCharactersNoCopy:buffer length:numchars freeWhenDone:YES];
	}
	else return [self swizzledInitWithBytes:bytes length:length encoding:encoding];
}




int IANACharSetNameToWindowsCodePage(NSString *name)
{
	static NSDictionary *encodingdictionary=nil;
	if(!encodingdictionary) encodingdictionary=[[NSDictionary alloc] initWithObjectsAndKeys:
	[NSNumber numberWithInt:037],@"ibm037", // IBM EBCDIC US-Canada
	[NSNumber numberWithInt:437],@"ibm437", // OEM United States
	[NSNumber numberWithInt:500],@"ibm500", // IBM EBCDIC International
	[NSNumber numberWithInt:708],@"asmo-708", // Arabic (ASMO 708)
	//[NSNumber numberWithInt:709],@"", // Arabic (ASMO-449+, BCON V4)
	//[NSNumber numberWithInt:710],@"", // Arabic - Transparent Arabic
	[NSNumber numberWithInt:720],@"dos-720", // Arabic (Transparent ASMO); Arabic (DOS)
	[NSNumber numberWithInt:737],@"ibm737", // OEM Greek (formerly 437G); Greek (DOS)
	[NSNumber numberWithInt:775],@"ibm775", // OEM Baltic; Baltic (DOS)
	[NSNumber numberWithInt:850],@"ibm850", // OEM Multilingual Latin 1; Western European (DOS)
	[NSNumber numberWithInt:852],@"ibm852", // OEM Latin 2; Central European (DOS)
	[NSNumber numberWithInt:855],@"ibm855", // OEM Cyrillic (primarily Russian)
	[NSNumber numberWithInt:857],@"ibm857", // OEM Turkish; Turkish (DOS)
	[NSNumber numberWithInt:858],@"ibm00858", // OEM Multilingual Latin 1 + Euro symbol
	[NSNumber numberWithInt:860],@"ibm860", // OEM Portuguese; Portuguese (DOS)
	[NSNumber numberWithInt:861],@"ibm861", // OEM Icelandic; Icelandic (DOS)
	[NSNumber numberWithInt:862],@"dos-862", // OEM Hebrew; Hebrew (DOS)
	[NSNumber numberWithInt:863],@"ibm863", // OEM French Canadian; French Canadian (DOS)
	[NSNumber numberWithInt:864],@"ibm864", // OEM Arabic; Arabic (864)
	[NSNumber numberWithInt:865],@"ibm865", // OEM Nordic; Nordic (DOS)
	[NSNumber numberWithInt:866],@"cp866", // OEM Russian; Cyrillic (DOS)
	[NSNumber numberWithInt:869],@"ibm869", // OEM Modern Greek; Greek, Modern (DOS)
	[NSNumber numberWithInt:870],@"ibm870", // IBM EBCDIC Multilingual/ROECE (Latin 2); IBM EBCDIC Multilingual Latin 2
	[NSNumber numberWithInt:874],@"windows-874", // ANSI/OEM Thai (same as 28605, ISO 8859-15); Thai (Windows)
	[NSNumber numberWithInt:875],@"cp875", // IBM EBCDIC Greek Modern
	[NSNumber numberWithInt:932],@"shift_jis", // ANSI/OEM Japanese; Japanese (Shift-JIS)
	[NSNumber numberWithInt:936],@"gb2312", // ANSI/OEM Simplified Chinese (PRC, Singapore); Chinese Simplified (GB2312)
	[NSNumber numberWithInt:949],@"ks_c_5601-1987", // ANSI/OEM Korean (Unified Hangul Code)
	[NSNumber numberWithInt:950],@"big5", // ANSI/OEM Traditional Chinese (Taiwan; Hong Kong SAR, PRC); Chinese Traditional (Big5)
	[NSNumber numberWithInt:1026],@"ibm1026", // IBM EBCDIC Turkish (Latin 5)
	[NSNumber numberWithInt:1047],@"ibm01047", // IBM EBCDIC Latin 1/Open System
	[NSNumber numberWithInt:1140],@"ibm01140", // IBM EBCDIC US-Canada (037 + Euro symbol); IBM EBCDIC (US-Canada-Euro)
	[NSNumber numberWithInt:1141],@"ibm01141", // IBM EBCDIC Germany (20273 + Euro symbol); IBM EBCDIC (Germany-Euro)
	[NSNumber numberWithInt:1142],@"ibm01142", // IBM EBCDIC Denmark-Norway (20277 + Euro symbol); IBM EBCDIC (Denmark-Norway-Euro)
	[NSNumber numberWithInt:1143],@"ibm01143", // IBM EBCDIC Finland-Sweden (20278 + Euro symbol); IBM EBCDIC (Finland-Sweden-Euro)
	[NSNumber numberWithInt:1144],@"ibm01144", // IBM EBCDIC Italy (20280 + Euro symbol); IBM EBCDIC (Italy-Euro)
	[NSNumber numberWithInt:1145],@"ibm01145", // IBM EBCDIC Latin America-Spain (20284 + Euro symbol); IBM EBCDIC (Spain-Euro)
	[NSNumber numberWithInt:1146],@"ibm01146", // IBM EBCDIC United Kingdom (20285 + Euro symbol); IBM EBCDIC (UK-Euro)
	[NSNumber numberWithInt:1147],@"ibm01147", // IBM EBCDIC France (20297 + Euro symbol); IBM EBCDIC (France-Euro)
	[NSNumber numberWithInt:1148],@"ibm01148", // IBM EBCDIC International (500 + Euro symbol); IBM EBCDIC (International-Euro)
	[NSNumber numberWithInt:1149],@"ibm01149", // IBM EBCDIC Icelandic (20871 + Euro symbol); IBM EBCDIC (Icelandic-Euro)
	[NSNumber numberWithInt:1200],@"utf-16", // Unicode UTF-16, little endian byte order (BMP of ISO 10646); available only to managed applications
	[NSNumber numberWithInt:1201],@"unicodefffe", // Unicode UTF-16, big endian byte order; available only to managed applications
	[NSNumber numberWithInt:1250],@"windows-1250", // ANSI Central European; Central European (Windows)
	[NSNumber numberWithInt:1251],@"windows-1251", // ANSI Cyrillic; Cyrillic (Windows)
	[NSNumber numberWithInt:1252],@"windows-1252", // ANSI Latin 1; Western European (Windows)
	[NSNumber numberWithInt:1253],@"windows-1253", // ANSI Greek; Greek (Windows)
	[NSNumber numberWithInt:1254],@"windows-1254", // ANSI Turkish; Turkish (Windows)
	[NSNumber numberWithInt:1255],@"windows-1255", // ANSI Hebrew; Hebrew (Windows)
	[NSNumber numberWithInt:1256],@"windows-1256", // ANSI Arabic; Arabic (Windows)
	[NSNumber numberWithInt:1257],@"windows-1257", // ANSI Baltic; Baltic (Windows)
	[NSNumber numberWithInt:1258],@"windows-1258", // ANSI/OEM Vietnamese; Vietnamese (Windows)
	[NSNumber numberWithInt:1361],@"johab", // Korean (Johab)
	[NSNumber numberWithInt:10000],@"macintosh", // MAC Roman; Western European (Mac)
	[NSNumber numberWithInt:10001],@"x-mac-japanese", // Japanese (Mac)
	[NSNumber numberWithInt:10002],@"x-mac-chinesetrad", // MAC Traditional Chinese (Big5); Chinese Traditional (Mac)
	[NSNumber numberWithInt:10003],@"x-mac-korean", // Korean (Mac)
	[NSNumber numberWithInt:10004],@"x-mac-arabic", // Arabic (Mac)
	[NSNumber numberWithInt:10005],@"x-mac-hebrew", // Hebrew (Mac)
	[NSNumber numberWithInt:10006],@"x-mac-greek", // Greek (Mac)
	[NSNumber numberWithInt:10007],@"x-mac-cyrillic", // Cyrillic (Mac)
	[NSNumber numberWithInt:10008],@"x-mac-chinesesimp", // MAC Simplified Chinese (GB 2312); Chinese Simplified (Mac)
	[NSNumber numberWithInt:10010],@"x-mac-romanian", // Romanian (Mac)
	[NSNumber numberWithInt:10017],@"x-mac-ukrainian", // Ukrainian (Mac)
	[NSNumber numberWithInt:10021],@"x-mac-thai", // Thai (Mac)
	[NSNumber numberWithInt:10029],@"x-mac-ce", // MAC Latin 2; Central European (Mac)
	[NSNumber numberWithInt:10079],@"x-mac-icelandic", // Icelandic (Mac)
	[NSNumber numberWithInt:10081],@"x-mac-turkish", // Turkish (Mac)
	[NSNumber numberWithInt:10082],@"x-mac-croatian", // Croatian (Mac)
	[NSNumber numberWithInt:12000],@"utf-32", // Unicode UTF-32, little endian byte order; available only to managed applications
	[NSNumber numberWithInt:12001],@"utf-32be", // Unicode UTF-32, big endian byte order; available only to managed applications
	[NSNumber numberWithInt:20000],@"x-chinese_cns", // CNS Taiwan; Chinese Traditional (CNS)
	[NSNumber numberWithInt:20001],@"x-cp20001", // TCA Taiwan
	[NSNumber numberWithInt:20002],@"x_chinese-eten", // Eten Taiwan; Chinese Traditional (Eten)
	[NSNumber numberWithInt:20003],@"x-cp20003", // IBM5550 Taiwan
	[NSNumber numberWithInt:20004],@"x-cp20004", // TeleText Taiwan
	[NSNumber numberWithInt:20005],@"x-cp20005", // Wang Taiwan
	[NSNumber numberWithInt:20105],@"x-ia5", // IA5 (IRV International Alphabet No. 5, 7-bit); Western European (IA5)
	[NSNumber numberWithInt:20106],@"x-ia5-german", // IA5 German (7-bit)
	[NSNumber numberWithInt:20107],@"x-ia5-swedish", // IA5 Swedish (7-bit)
	[NSNumber numberWithInt:20108],@"x-ia5-norwegian", // IA5 Norwegian (7-bit)
	[NSNumber numberWithInt:20127],@"us-ascii", // US-ASCII (7-bit)
	[NSNumber numberWithInt:20261],@"x-cp20261", // T.61
	[NSNumber numberWithInt:20269],@"x-cp20269", // ISO 6937 Non-Spacing Accent
	[NSNumber numberWithInt:20273],@"ibm273", // IBM EBCDIC Germany
	[NSNumber numberWithInt:20277],@"ibm277", // IBM EBCDIC Denmark-Norway
	[NSNumber numberWithInt:20278],@"ibm278", // IBM EBCDIC Finland-Sweden
	[NSNumber numberWithInt:20280],@"ibm280", // IBM EBCDIC Italy
	[NSNumber numberWithInt:20284],@"ibm284", // IBM EBCDIC Latin America-Spain
	[NSNumber numberWithInt:20285],@"ibm285", // IBM EBCDIC United Kingdom
	[NSNumber numberWithInt:20290],@"ibm290", // IBM EBCDIC Japanese Katakana Extended
	[NSNumber numberWithInt:20297],@"ibm297", // IBM EBCDIC France
	[NSNumber numberWithInt:20420],@"ibm420", // IBM EBCDIC Arabic
	[NSNumber numberWithInt:20423],@"ibm423", // IBM EBCDIC Greek
	[NSNumber numberWithInt:20424],@"ibm424", // IBM EBCDIC Hebrew
	[NSNumber numberWithInt:20833],@"x-ebcdic-koreanextended", // IBM EBCDIC Korean Extended
	[NSNumber numberWithInt:20838],@"ibm-thai", // IBM EBCDIC Thai
	[NSNumber numberWithInt:20866],@"koi8-r", // Russian (KOI8-R); Cyrillic (KOI8-R)
	[NSNumber numberWithInt:20871],@"ibm871", // IBM EBCDIC Icelandic
	[NSNumber numberWithInt:20880],@"ibm880", // IBM EBCDIC Cyrillic Russian
	[NSNumber numberWithInt:20905],@"ibm905", // IBM EBCDIC Turkish
	[NSNumber numberWithInt:20924],@"ibm00924", // IBM EBCDIC Latin 1/Open System (1047 + Euro symbol)
	[NSNumber numberWithInt:20932],@"euc-jp", // Japanese (JIS 0208-1990 and 0121-1990)
	[NSNumber numberWithInt:20936],@"x-cp20936", // Simplified Chinese (GB2312); Chinese Simplified (GB2312-80)
	[NSNumber numberWithInt:20949],@"x-cp20949", // Korean Wansung
	[NSNumber numberWithInt:21025],@"cp1025", // IBM EBCDIC Cyrillic Serbian-Bulgarian
	//[NSNumber numberWithInt:21027],@"", // (deprecated)
	[NSNumber numberWithInt:21866],@"koi8-u", // Ukrainian (KOI8-U); Cyrillic (KOI8-U)
	[NSNumber numberWithInt:28591],@"iso-8859-1", // ISO 8859-1 Latin 1; Western European (ISO)
	[NSNumber numberWithInt:28592],@"iso-8859-2", // ISO 8859-2 Central European; Central European (ISO)
	[NSNumber numberWithInt:28593],@"iso-8859-3", // ISO 8859-3 Latin 3
	[NSNumber numberWithInt:28594],@"iso-8859-4", // ISO 8859-4 Baltic
	[NSNumber numberWithInt:28595],@"iso-8859-5", // ISO 8859-5 Cyrillic
	[NSNumber numberWithInt:28596],@"iso-8859-6", // ISO 8859-6 Arabic
	[NSNumber numberWithInt:28597],@"iso-8859-7", // ISO 8859-7 Greek
	[NSNumber numberWithInt:28598],@"iso-8859-8", // ISO 8859-8 Hebrew; Hebrew (ISO-Visual)
	[NSNumber numberWithInt:28599],@"iso-8859-9", // ISO 8859-9 Turkish
	[NSNumber numberWithInt:28603],@"iso-8859-13", // ISO 8859-13 Estonian
	[NSNumber numberWithInt:28605],@"iso-8859-15", // ISO 8859-15 Latin 9
	[NSNumber numberWithInt:29001],@"x-europa", // Europa 3
	[NSNumber numberWithInt:38598],@"iso-8859-8-i", // ISO 8859-8 Hebrew; Hebrew (ISO-Logical)
	[NSNumber numberWithInt:50220],@"iso-2022-jp", // ISO 2022 Japanese with no halfwidth Katakana; Japanese (JIS)
	[NSNumber numberWithInt:50221],@"csiso2022jp", // ISO 2022 Japanese with halfwidth Katakana; Japanese (JIS-Allow 1 byte Kana)
	[NSNumber numberWithInt:50222],@"iso-2022-jp", // ISO 2022 Japanese JIS X 0201-1989; Japanese (JIS-Allow 1 byte Kana - SO/SI)
	[NSNumber numberWithInt:50225],@"iso-2022-kr", // ISO 2022 Korean
	[NSNumber numberWithInt:50227],@"x-cp50227", // ISO 2022 Simplified Chinese; Chinese Simplified (ISO 2022)
	//[NSNumber numberWithInt:50229],@"", // ISO 2022 Traditional Chinese
	//[NSNumber numberWithInt:50930],@"", // EBCDIC Japanese (Katakana) Extended
	//[NSNumber numberWithInt:50931],@"", // EBCDIC US-Canada and Japanese
	//[NSNumber numberWithInt:50933],@"", // EBCDIC Korean Extended and Korean
	//[NSNumber numberWithInt:50935],@"", // EBCDIC Simplified Chinese Extended and Simplified Chinese
	//[NSNumber numberWithInt:50936],@"", // EBCDIC Simplified Chinese
	//[NSNumber numberWithInt:50937],@"", // EBCDIC US-Canada and Traditional Chinese
	//[NSNumber numberWithInt:50939],@"", // EBCDIC Japanese (Latin) Extended and Japanese
	[NSNumber numberWithInt:51932],@"euc-jp", // EUC Japanese
	[NSNumber numberWithInt:51936],@"euc-cn", // EUC Simplified Chinese; Chinese Simplified (EUC)
	[NSNumber numberWithInt:51949],@"euc-kr", // EUC Korean
	//[NSNumber numberWithInt:51950],@"", // EUC Traditional Chinese
	[NSNumber numberWithInt:52936],@"hz-gb-2312", // HZ-GB2312 Simplified Chinese; Chinese Simplified (HZ)
	[NSNumber numberWithInt:54936],@"gb18030", // Windows XP and later: GB18030 Simplified Chinese (4 byte); Chinese Simplified (GB18030)
	[NSNumber numberWithInt:57002],@"x-iscii-de", // ISCII Devanagari
	[NSNumber numberWithInt:57003],@"x-iscii-be", // ISCII Bengali
	[NSNumber numberWithInt:57004],@"x-iscii-ta", // ISCII Tamil
	[NSNumber numberWithInt:57005],@"x-iscii-te", // ISCII Telugu
	[NSNumber numberWithInt:57006],@"x-iscii-as", // ISCII Assamese
	[NSNumber numberWithInt:57007],@"x-iscii-or", // ISCII Oriya
	[NSNumber numberWithInt:57008],@"x-iscii-ka", // ISCII Kannada
	[NSNumber numberWithInt:57009],@"x-iscii-ma", // ISCII Malayalam
	[NSNumber numberWithInt:57010],@"x-iscii-gu", // ISCII Gujarati
	[NSNumber numberWithInt:57011],@"x-iscii-pa", // ISCII Punjabi
	[NSNumber numberWithInt:65000],@"utf-7", // Unicode (UTF-7)
	[NSNumber numberWithInt:65001],@"utf-8", // Unicode (UTF-8)
	nil];

	NSNumber *encoding=[encodingdictionary objectForKey:[name lowercaseString]];
	if(!encoding) return 0;

	return [encoding unsignedIntValue];
}

@end







/*
  (CPID: 37; CPName: 'IBM037'),
    (CPID: 437; CPName: 'IBM437'),
    (CPID: 500; CPName: 'IBM500'),
    (CPID: 708; CPName: 'ASMO-708'),
    (CPID: 720; CPName: 'DOS-720'),
    (CPID: 737; CPName: 'ibm737'),
    (CPID: 775; CPName: 'ibm775'),
    (CPID: 850; CPName: 'ibm850'),
    (CPID: 852; CPName: 'ibm852'),
    (CPID: 855; CPName: 'IBM855'),
    (CPID: 857; CPName: 'ibm857'),
    (CPID: 858; CPName: 'IBM00858'),
    (CPID: 860; CPName: 'IBM860'),
    (CPID: 861; CPName: 'ibm861'),
    (CPID: 862; CPName: 'DOS-862'),
    (CPID: 863; CPName: 'IBM863'),
    (CPID: 864; CPName: 'IBM864'),
    (CPID: 865; CPName: 'IBM865'),
    (CPID: 866; CPName: 'cp866'),
    (CPID: 869; CPName: 'ibm869'),
    (CPID: 870; CPName: 'IBM870'),
    (CPID: 874; CPName: 'windows-874'),
    (CPID: 875; CPName: 'cp875'),
    (CPID: 932; CPName: 'shift_jis'),
    (CPID: 936; CPName: 'gb2312'),
    (CPID: 949; CPName: 'ks_c_5601-1987'),
    (CPID: 950; CPName: 'big5'),
    (CPID: 1026; CPName: 'IBM1026'),
    (CPID: 1047; CPName: 'IBM01047'),
    (CPID: 1140; CPName: 'IBM01140'),
    (CPID: 1141; CPName: 'IBM01141'),
    (CPID: 1142; CPName: 'IBM01142'),
    (CPID: 1143; CPName: 'IBM01143'),
    (CPID: 1144; CPName: 'IBM01144'),
    (CPID: 1145; CPName: 'IBM01145'),
    (CPID: 1146; CPName: 'IBM01146'),
    (CPID: 1147; CPName: 'IBM01147'),
    (CPID: 1148; CPName: 'IBM01148'),
    (CPID: 1149; CPName: 'IBM01149'),
    (CPID: 1200; CPName: 'utf-16'),
    (CPID: 1201; CPName: 'unicodeFFFE'),
    (CPID: 1250; CPName: 'windows-1250'),
    (CPID: 1251; CPName: 'windows-1251'),
    (CPID: 1252; CPName: 'Windows-1252'),
    (CPID: 1253; CPName: 'windows-1253'),
    (CPID: 1254; CPName: 'windows-1254'),
    (CPID: 1255; CPName: 'windows-1255'),
    (CPID: 1256; CPName: 'windows-1256'),
    (CPID: 1257; CPName: 'windows-1257'),
    (CPID: 1258; CPName: 'windows-1258'),
    (CPID: 1361; CPName: 'Johab'),
    (CPID: 10000; CPName: 'macintosh'),
    (CPID: 10001; CPName: 'x-mac-japanese'),
    (CPID: 10002; CPName: 'x-mac-chinesetrad'),
    (CPID: 10003; CPName: 'x-mac-korean'),
    (CPID: 10004; CPName: 'x-mac-arabic'),
    (CPID: 10005; CPName: 'x-mac-hebrew'),
    (CPID: 10006; CPName: 'x-mac-greek'),
    (CPID: 10007; CPName: 'x-mac-cyrillic'),
    (CPID: 10008; CPName: 'x-mac-chinesesimp'),
    (CPID: 10010; CPName: 'x-mac-romanian'),
    (CPID: 10017; CPName: 'x-mac-ukrainian'),
    (CPID: 10021; CPName: 'x-mac-thai'),
    (CPID: 10029; CPName: 'x-mac-ce'),
    (CPID: 10079; CPName: 'x-mac-icelandic'),
    (CPID: 10081; CPName: 'x-mac-turkish'),
    (CPID: 10082; CPName: 'x-mac-croatian'),
    (CPID: 12000; CPName: 'utf-32'),
    (CPID: 12001; CPName: 'utf-32BE'),
    (CPID: 20000; CPName: 'x-Chinese-CNS'),
    (CPID: 20001; CPName: 'x-cp20001'),
    (CPID: 20002; CPName: 'x-Chinese-Eten'),
    (CPID: 20003; CPName: 'x-cp20003'),
    (CPID: 20004; CPName: 'x-cp20004'),
    (CPID: 20005; CPName: 'x-cp20005'),
    (CPID: 20105; CPName: 'x-IA5'),
    (CPID: 20106; CPName: 'x-IA5-German'),
    (CPID: 20107; CPName: 'x-IA5-Swedish'),
    (CPID: 20108; CPName: 'x-IA5-Norwegian'),
    (CPID: 20127; CPName: 'us-ascii'),
    (CPID: 20261; CPName: 'x-cp20261'),
    (CPID: 20269; CPName: 'x-cp20269'),
    (CPID: 20273; CPName: 'IBM273'),
    (CPID: 20277; CPName: 'IBM277'),
    (CPID: 20278; CPName: 'IBM278'),
    (CPID: 20280; CPName: 'IBM280'),
    (CPID: 20284; CPName: 'IBM284'),
    (CPID: 20285; CPName: 'IBM285'),
    (CPID: 20290; CPName: 'IBM290'),
    (CPID: 20297; CPName: 'IBM297'),
    (CPID: 20420; CPName: 'IBM420'),
    (CPID: 20423; CPName: 'IBM423'),
    (CPID: 20424; CPName: 'IBM424'),
    (CPID: 20833; CPName: 'x-EBCDIC-KoreanExtended'),
    (CPID: 20838; CPName: 'IBM-Thai'),
    (CPID: 20866; CPName: 'koi8-r'),
    (CPID: 20871; CPName: 'IBM871'),
    (CPID: 20880; CPName: 'IBM880'),
    (CPID: 20905; CPName: 'IBM905'),
    (CPID: 20924; CPName: 'IBM00924'),
    (CPID: 20932; CPName: 'EUC-JP'),
    (CPID: 20936; CPName: 'x-cp20936'),
    (CPID: 20949; CPName: 'x-cp20949'),
    (CPID: 21025; CPName: 'cp1025'),
    (CPID: 21866; CPName: 'koi8-u'),
    (CPID: 28591; CPName: 'iso-8859-1'),
    (CPID: 28592; CPName: 'iso-8859-2'),
    (CPID: 28593; CPName: 'iso-8859-3'),
    (CPID: 28594; CPName: 'iso-8859-4'),
    (CPID: 28595; CPName: 'iso-8859-5'),
    (CPID: 28596; CPName: 'iso-8859-6'),
    (CPID: 28597; CPName: 'iso-8859-7'),
    (CPID: 28598; CPName: 'iso-8859-8'),
    (CPID: 28599; CPName: 'iso-8859-9'),
    (CPID: 28603; CPName: 'iso-8859-13'),
    (CPID: 28605; CPName: 'iso-8859-15'),
    (CPID: 29001; CPName: 'x-Europa'),
    (CPID: 38598; CPName: 'iso-8859-8-i'),
    (CPID: 50220; CPName: 'iso-2022-jp'),
    (CPID: 50221; CPName: 'csISO2022JP'),
    (CPID: 50222; CPName: 'iso-2022-jp'),
    (CPID: 50225; CPName: 'iso-2022-kr'),
    (CPID: 50227; CPName: 'x-cp50227'),
    (CPID: 51932; CPName: 'euc-jp'),
    (CPID: 51936; CPName: 'EUC-CN'),
    (CPID: 51949; CPName: 'euc-kr'),
    (CPID: 52936; CPName: 'hz-gb-2312'),
    (CPID: 54936; CPName: 'GB18030'),
    (CPID: 57002; CPName: 'x-iscii-de'),
    (CPID: 57003; CPName: 'x-iscii-be'),
    (CPID: 57004; CPName: 'x-iscii-ta'),
    (CPID: 57005; CPName: 'x-iscii-te'),
    (CPID: 57006; CPName: 'x-iscii-as'),
    (CPID: 57007; CPName: 'x-iscii-or'),
    (CPID: 57008; CPName: 'x-iscii-ka'),
    (CPID: 57009; CPName: 'x-iscii-ma'),
    (CPID: 57010; CPName: 'x-iscii-gu'),
    (CPID: 57011; CPName: 'x-iscii-pa'),
    (CPID: 65000; CPName: 'utf-7'),
    (CPID: 65001; CPName: 'utf-8')
*/

/*
037	IBM037	IBM EBCDIC US-Canada
437	IBM437	OEM United States
500	IBM500	IBM EBCDIC International
708	ASMO-708	Arabic (ASMO 708)
709		Arabic (ASMO-449+, BCON V4)
710		Arabic - Transparent Arabic
720	DOS-720	Arabic (Transparent ASMO); Arabic (DOS)
737	ibm737	OEM Greek (formerly 437G); Greek (DOS)
775	ibm775	OEM Baltic; Baltic (DOS)
850	ibm850	OEM Multilingual Latin 1; Western European (DOS)
852	ibm852	OEM Latin 2; Central European (DOS)
855	IBM855	OEM Cyrillic (primarily Russian)
857	ibm857	OEM Turkish; Turkish (DOS)
858	IBM00858	OEM Multilingual Latin 1 + Euro symbol
860	IBM860	OEM Portuguese; Portuguese (DOS)
861	ibm861	OEM Icelandic; Icelandic (DOS)
862	DOS-862	OEM Hebrew; Hebrew (DOS)
863	IBM863	OEM French Canadian; French Canadian (DOS)
864	IBM864	OEM Arabic; Arabic (864)
865	IBM865	OEM Nordic; Nordic (DOS)
866	cp866	OEM Russian; Cyrillic (DOS)
869	ibm869	OEM Modern Greek; Greek, Modern (DOS)
870	IBM870	IBM EBCDIC Multilingual/ROECE (Latin 2); IBM EBCDIC Multilingual Latin 2
874	windows-874	ANSI/OEM Thai (same as 28605, ISO 8859-15); Thai (Windows)
875	cp875	IBM EBCDIC Greek Modern
932	shift_jis	ANSI/OEM Japanese; Japanese (Shift-JIS)
936	gb2312	ANSI/OEM Simplified Chinese (PRC, Singapore); Chinese Simplified (GB2312)
949	ks_c_5601-1987	ANSI/OEM Korean (Unified Hangul Code)
950	big5	ANSI/OEM Traditional Chinese (Taiwan; Hong Kong SAR, PRC); Chinese Traditional (Big5)
1026	IBM1026	IBM EBCDIC Turkish (Latin 5)
1047	IBM01047	IBM EBCDIC Latin 1/Open System
1140	IBM01140	IBM EBCDIC US-Canada (037 + Euro symbol); IBM EBCDIC (US-Canada-Euro)
1141	IBM01141	IBM EBCDIC Germany (20273 + Euro symbol); IBM EBCDIC (Germany-Euro)
1142	IBM01142	IBM EBCDIC Denmark-Norway (20277 + Euro symbol); IBM EBCDIC (Denmark-Norway-Euro)
1143	IBM01143	IBM EBCDIC Finland-Sweden (20278 + Euro symbol); IBM EBCDIC (Finland-Sweden-Euro)
1144	IBM01144	IBM EBCDIC Italy (20280 + Euro symbol); IBM EBCDIC (Italy-Euro)
1145	IBM01145	IBM EBCDIC Latin America-Spain (20284 + Euro symbol); IBM EBCDIC (Spain-Euro)
1146	IBM01146	IBM EBCDIC United Kingdom (20285 + Euro symbol); IBM EBCDIC (UK-Euro)
1147	IBM01147	IBM EBCDIC France (20297 + Euro symbol); IBM EBCDIC (France-Euro)
1148	IBM01148	IBM EBCDIC International (500 + Euro symbol); IBM EBCDIC (International-Euro)
1149	IBM01149	IBM EBCDIC Icelandic (20871 + Euro symbol); IBM EBCDIC (Icelandic-Euro)
1200	utf-16	Unicode UTF-16, little endian byte order (BMP of ISO 10646); available only to managed applications
1201	unicodeFFFE	Unicode UTF-16, big endian byte order; available only to managed applications
1250	windows-1250	ANSI Central European; Central European (Windows)
1251	windows-1251	ANSI Cyrillic; Cyrillic (Windows)
1252	windows-1252	ANSI Latin 1; Western European (Windows)
1253	windows-1253	ANSI Greek; Greek (Windows)
1254	windows-1254	ANSI Turkish; Turkish (Windows)
1255	windows-1255	ANSI Hebrew; Hebrew (Windows)
1256	windows-1256	ANSI Arabic; Arabic (Windows)
1257	windows-1257	ANSI Baltic; Baltic (Windows)
1258	windows-1258	ANSI/OEM Vietnamese; Vietnamese (Windows)
1361	Johab	Korean (Johab)
10000	macintosh	MAC Roman; Western European (Mac)
10001	x-mac-japanese	Japanese (Mac)
10002	x-mac-chinesetrad	MAC Traditional Chinese (Big5); Chinese Traditional (Mac)
10003	x-mac-korean	Korean (Mac)
10004	x-mac-arabic	Arabic (Mac)
10005	x-mac-hebrew	Hebrew (Mac)
10006	x-mac-greek	Greek (Mac)
10007	x-mac-cyrillic	Cyrillic (Mac)
10008	x-mac-chinesesimp	MAC Simplified Chinese (GB 2312); Chinese Simplified (Mac)
10010	x-mac-romanian	Romanian (Mac)
10017	x-mac-ukrainian	Ukrainian (Mac)
10021	x-mac-thai	Thai (Mac)
10029	x-mac-ce	MAC Latin 2; Central European (Mac)
10079	x-mac-icelandic	Icelandic (Mac)
10081	x-mac-turkish	Turkish (Mac)
10082	x-mac-croatian	Croatian (Mac)
12000	utf-32	Unicode UTF-32, little endian byte order; available only to managed applications
12001	utf-32BE	Unicode UTF-32, big endian byte order; available only to managed applications
20000	x-Chinese_CNS	CNS Taiwan; Chinese Traditional (CNS)
20001	x-cp20001	TCA Taiwan
20002	x_Chinese-Eten	Eten Taiwan; Chinese Traditional (Eten)
20003	x-cp20003	IBM5550 Taiwan
20004	x-cp20004	TeleText Taiwan
20005	x-cp20005	Wang Taiwan
20105	x-IA5	IA5 (IRV International Alphabet No. 5, 7-bit); Western European (IA5)
20106	x-IA5-German	IA5 German (7-bit)
20107	x-IA5-Swedish	IA5 Swedish (7-bit)
20108	x-IA5-Norwegian	IA5 Norwegian (7-bit)
20127	us-ascii	US-ASCII (7-bit)
20261	x-cp20261	T.61
20269	x-cp20269	ISO 6937 Non-Spacing Accent
20273	IBM273	IBM EBCDIC Germany
20277	IBM277	IBM EBCDIC Denmark-Norway
20278	IBM278	IBM EBCDIC Finland-Sweden
20280	IBM280	IBM EBCDIC Italy
20284	IBM284	IBM EBCDIC Latin America-Spain
20285	IBM285	IBM EBCDIC United Kingdom
20290	IBM290	IBM EBCDIC Japanese Katakana Extended
20297	IBM297	IBM EBCDIC France
20420	IBM420	IBM EBCDIC Arabic
20423	IBM423	IBM EBCDIC Greek
20424	IBM424	IBM EBCDIC Hebrew
20833	x-EBCDIC-KoreanExtended	IBM EBCDIC Korean Extended
20838	IBM-Thai	IBM EBCDIC Thai
20866	koi8-r	Russian (KOI8-R); Cyrillic (KOI8-R)
20871	IBM871	IBM EBCDIC Icelandic
20880	IBM880	IBM EBCDIC Cyrillic Russian
20905	IBM905	IBM EBCDIC Turkish
20924	IBM00924	IBM EBCDIC Latin 1/Open System (1047 + Euro symbol)
20932	EUC-JP	Japanese (JIS 0208-1990 and 0121-1990)
20936	x-cp20936	Simplified Chinese (GB2312); Chinese Simplified (GB2312-80)
20949	x-cp20949	Korean Wansung
21025	cp1025	IBM EBCDIC Cyrillic Serbian-Bulgarian
21027		(deprecated)
21866	koi8-u	Ukrainian (KOI8-U); Cyrillic (KOI8-U)
28591	iso-8859-1	ISO 8859-1 Latin 1; Western European (ISO)
28592	iso-8859-2	ISO 8859-2 Central European; Central European (ISO)
28593	iso-8859-3	ISO 8859-3 Latin 3
28594	iso-8859-4	ISO 8859-4 Baltic
28595	iso-8859-5	ISO 8859-5 Cyrillic
28596	iso-8859-6	ISO 8859-6 Arabic
28597	iso-8859-7	ISO 8859-7 Greek
28598	iso-8859-8	ISO 8859-8 Hebrew; Hebrew (ISO-Visual)
28599	iso-8859-9	ISO 8859-9 Turkish
28603	iso-8859-13	ISO 8859-13 Estonian
28605	iso-8859-15	ISO 8859-15 Latin 9
29001	x-Europa	Europa 3
38598	iso-8859-8-i	ISO 8859-8 Hebrew; Hebrew (ISO-Logical)
50220	iso-2022-jp	ISO 2022 Japanese with no halfwidth Katakana; Japanese (JIS)
50221	csISO2022JP	ISO 2022 Japanese with halfwidth Katakana; Japanese (JIS-Allow 1 byte Kana)
50222	iso-2022-jp	ISO 2022 Japanese JIS X 0201-1989; Japanese (JIS-Allow 1 byte Kana - SO/SI)
50225	iso-2022-kr	ISO 2022 Korean
50227	x-cp50227	ISO 2022 Simplified Chinese; Chinese Simplified (ISO 2022)
50229		ISO 2022 Traditional Chinese
50930		EBCDIC Japanese (Katakana) Extended
50931		EBCDIC US-Canada and Japanese
50933		EBCDIC Korean Extended and Korean
50935		EBCDIC Simplified Chinese Extended and Simplified Chinese
50936		EBCDIC Simplified Chinese
50937		EBCDIC US-Canada and Traditional Chinese
50939		EBCDIC Japanese (Latin) Extended and Japanese
51932	euc-jp	EUC Japanese
51936	EUC-CN	EUC Simplified Chinese; Chinese Simplified (EUC)
51949	euc-kr	EUC Korean
51950		EUC Traditional Chinese
52936	hz-gb-2312	HZ-GB2312 Simplified Chinese; Chinese Simplified (HZ)
54936	GB18030	Windows XP and later: GB18030 Simplified Chinese (4 byte); Chinese Simplified (GB18030)
57002	x-iscii-de	ISCII Devanagari
57003	x-iscii-be	ISCII Bengali
57004	x-iscii-ta	ISCII Tamil
57005	x-iscii-te	ISCII Telugu
57006	x-iscii-as	ISCII Assamese
57007	x-iscii-or	ISCII Oriya
57008	x-iscii-ka	ISCII Kannada
57009	x-iscii-ma	ISCII Malayalam
57010	x-iscii-gu	ISCII Gujarati
57011	x-iscii-pa	ISCII Punjabi
65000	utf-7	Unicode (UTF-7)
65001	utf-8	Unicode (UTF-8)
*/

/*
37

IBM037

IBM EBCDIC (US-Canada)

437

IBM437

OEM United States

500

IBM500

IBM EBCDIC (International)

708

ASMO-708

Arabic (ASMO 708)

720

DOS-720

Arabic (DOS)

737

ibm737

Greek (DOS)

775

ibm775

Baltic (DOS)

850

ibm850

Western European (DOS)

852

ibm852

Central European (DOS)

855

IBM855

OEM Cyrillic

857

ibm857

Turkish (DOS)

858

IBM00858

OEM Multilingual Latin I

860

IBM860

Portuguese (DOS)

861

ibm861

Icelandic (DOS)

862

DOS-862

Hebrew (DOS)

863

IBM863

French Canadian (DOS)

864

IBM864

Arabic (864)

865

IBM865

Nordic (DOS)

866

cp866

Cyrillic (DOS)

869

ibm869

Greek, Modern (DOS)

870

IBM870

IBM EBCDIC (Multilingual Latin-2)

874

windows-874

Thai (Windows)

875

cp875

IBM EBCDIC (Greek Modern)

932

shift_jis

Japanese (Shift-JIS)

936

gb2312

Chinese Simplified (GB2312)

*

949

ks_c_5601-1987

Korean

950

big5

Chinese Traditional (Big5)

1026

IBM1026

IBM EBCDIC (Turkish Latin-5)

1047

IBM01047

IBM Latin-1

1140

IBM01140

IBM EBCDIC (US-Canada-Euro)

1141

IBM01141

IBM EBCDIC (Germany-Euro)

1142

IBM01142

IBM EBCDIC (Denmark-Norway-Euro)

1143

IBM01143

IBM EBCDIC (Finland-Sweden-Euro)

1144

IBM01144

IBM EBCDIC (Italy-Euro)

1145

IBM01145

IBM EBCDIC (Spain-Euro)

1146

IBM01146

IBM EBCDIC (UK-Euro)

1147

IBM01147

IBM EBCDIC (France-Euro)

1148

IBM01148

IBM EBCDIC (International-Euro)

1149

IBM01149

IBM EBCDIC (Icelandic-Euro)

1200

utf-16

Unicode

*

1201

unicodeFFFE

Unicode (Big endian)

*

1250

windows-1250

Central European (Windows)

1251

windows-1251

Cyrillic (Windows)

1252

Windows-1252

Western European (Windows)

*

1253

windows-1253

Greek (Windows)

1254

windows-1254

Turkish (Windows)

1255

windows-1255

Hebrew (Windows)

1256

windows-1256

Arabic (Windows)

1257

windows-1257

Baltic (Windows)

1258

windows-1258

Vietnamese (Windows)

1361

Johab

Korean (Johab)

10000

macintosh

Western European (Mac)

10001

x-mac-japanese

Japanese (Mac)

10002

x-mac-chinesetrad

Chinese Traditional (Mac)

10003

x-mac-korean

Korean (Mac)

*

10004

x-mac-arabic

Arabic (Mac)

10005

x-mac-hebrew

Hebrew (Mac)

10006

x-mac-greek

Greek (Mac)

10007

x-mac-cyrillic

Cyrillic (Mac)

10008

x-mac-chinesesimp

Chinese Simplified (Mac)

*

10010

x-mac-romanian

Romanian (Mac)

10017

x-mac-ukrainian

Ukrainian (Mac)

10021

x-mac-thai

Thai (Mac)

10029

x-mac-ce

Central European (Mac)

10079

x-mac-icelandic

Icelandic (Mac)

10081

x-mac-turkish

Turkish (Mac)

10082

x-mac-croatian

Croatian (Mac)

12000

utf-32

Unicode (UTF-32)

*

12001

utf-32BE

Unicode (UTF-32 Big endian)

*

20000

x-Chinese-CNS

Chinese Traditional (CNS)

20001

x-cp20001

TCA Taiwan

20002

x-Chinese-Eten

Chinese Traditional (Eten)

20003

x-cp20003

IBM5550 Taiwan

20004

x-cp20004

TeleText Taiwan

20005

x-cp20005

Wang Taiwan

20105

x-IA5

Western European (IA5)

20106

x-IA5-German

German (IA5)

20107

x-IA5-Swedish

Swedish (IA5)

20108

x-IA5-Norwegian

Norwegian (IA5)

20127

us-ascii

US-ASCII

*

20261

x-cp20261

T.61

20269

x-cp20269

ISO-6937

20273

IBM273

IBM EBCDIC (Germany)

20277

IBM277

IBM EBCDIC (Denmark-Norway)

20278

IBM278

IBM EBCDIC (Finland-Sweden)

20280

IBM280

IBM EBCDIC (Italy)

20284

IBM284

IBM EBCDIC (Spain)

20285

IBM285

IBM EBCDIC (UK)

20290

IBM290

IBM EBCDIC (Japanese katakana)

20297

IBM297

IBM EBCDIC (France)

20420

IBM420

IBM EBCDIC (Arabic)

20423

IBM423

IBM EBCDIC (Greek)

20424

IBM424

IBM EBCDIC (Hebrew)

20833

x-EBCDIC-KoreanExtended

IBM EBCDIC (Korean Extended)

20838

IBM-Thai

IBM EBCDIC (Thai)

20866

koi8-r

Cyrillic (KOI8-R)

20871

IBM871

IBM EBCDIC (Icelandic)

20880

IBM880

IBM EBCDIC (Cyrillic Russian)

20905

IBM905

IBM EBCDIC (Turkish)

20924

IBM00924

IBM Latin-1

20932

EUC-JP

Japanese (JIS 0208-1990 and 0212-1990)

20936

x-cp20936

Chinese Simplified (GB2312-80)

*

20949

x-cp20949

Korean Wansung

*

21025

cp1025

IBM EBCDIC (Cyrillic Serbian-Bulgarian)

21866

koi8-u

Cyrillic (KOI8-U)

28591

iso-8859-1

Western European (ISO)

*

28592

iso-8859-2

Central European (ISO)

28593

iso-8859-3

Latin 3 (ISO)

28594

iso-8859-4

Baltic (ISO)

28595

iso-8859-5

Cyrillic (ISO)

28596

iso-8859-6

Arabic (ISO)

28597

iso-8859-7

Greek (ISO)

28598

iso-8859-8

Hebrew (ISO-Visual)

*

28599

iso-8859-9

Turkish (ISO)

28603

iso-8859-13

Estonian (ISO)

28605

iso-8859-15

Latin 9 (ISO)

29001

x-Europa

Europa

38598

iso-8859-8-i

Hebrew (ISO-Logical)

*

50220

iso-2022-jp

Japanese (JIS)

*

50221

csISO2022JP

Japanese (JIS-Allow 1 byte Kana)

*

50222

iso-2022-jp

Japanese (JIS-Allow 1 byte Kana - SO/SI)

*

50225

iso-2022-kr

Korean (ISO)

*

50227

x-cp50227

Chinese Simplified (ISO-2022)

*

51932

euc-jp

Japanese (EUC)

*

51936

EUC-CN

Chinese Simplified (EUC)

*

51949

euc-kr

Korean (EUC)

*

52936

hz-gb-2312

Chinese Simplified (HZ)

*

54936

GB18030

Chinese Simplified (GB18030)

*

57002

x-iscii-de

ISCII Devanagari

*

57003

x-iscii-be

ISCII Bengali

*

57004

x-iscii-ta

ISCII Tamil

*

57005

x-iscii-te

ISCII Telugu

*

57006

x-iscii-as

ISCII Assamese

*

57007

x-iscii-or

ISCII Oriya

*

57008

x-iscii-ka

ISCII Kannada

*

57009

x-iscii-ma

ISCII Malayalam

*

57010

x-iscii-gu

ISCII Gujarati

*

57011

x-iscii-pa

ISCII Punjabi

*

65000

utf-7

Unicode (UTF-7)

*

65001

utf-8

Unicode (UTF-8)
*/

