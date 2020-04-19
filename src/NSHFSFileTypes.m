#import <Foundation/NSHFSFileTypes.h>
#import <Foundation/NSString.h>

NSString* NSFileTypeForHFSTypeCode(OSType hfsFileTypeCode)
{
	char type[7];
	int pos = 0;

	type[pos++] = '\'';
	while (hfsFileTypeCode)
	{
		char c = (hfsFileTypeCode >> 24) & 0xff;
		type[pos++] = c;
		hfsFileTypeCode <<= 8;
	}
	type[pos++] = '\'';
	type[pos++] = '\0';

	return [NSString stringWithCString: type encoding: NSASCIIStringEncoding];
}

OSType NSHFSTypeCodeFromFileType(NSString* fileType)
{
	char type[7];

	if (![fileType getCString: type maxLength: sizeof(type) encoding: NSASCIIStringEncoding])
		return 0;
	if (type[0] != '\'' || type[5] != '\'')
		return 0;

	OSType rv = 0;
	for (int i = 1; i <= 4; i++)
	{
		rv <<= 8;
		rv |= ((OSType) type[i]) & 0xff;
	}

	return rv;
}

NSString* NSHFSTypeOfFile(NSString* filePath)
{
	return nil;
}
