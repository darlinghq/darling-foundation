#include <stddef.h>
#import <Foundation/NSString.h>
#include <xpc/xpc.h>

void _FCDLog(const char* file, size_t line, NSString* format, ...);
#define FCDLog(...) do {\
		_FCDLog(__FILE__, __LINE__, ## __VA_ARGS__); \
	} while (0);

void _FCDLogv(const char* file, size_t line, NSString* format, va_list args);
#define FCDLogv(...) do {\
		_FCDLogv(__FILE__, __LINE__, ## __VA_ARGS__); \
	} while (0);

void _FCDAssertionFailed(const char* expression, const char* file, size_t line);
#define FCDAssert(expression) do {\
		if (!(expression)) _FCDAssertionFailed(#expression, __FILE__, __LINE__); \
	} while (0);

BOOL _FCDDebugLogEnabled(void);
#define FCDDebug(...) do {\
		if (_FCDDebugLogEnabled()) FCDLog(__VA_ARGS__); \
	} while(0);\

#define FCDUnimplementedFunction() FCDLog(@"%s: Unimplemented function", __PRETTY_FUNCTION__)
#define FCDUnimplementedMethod()   FCDLog(@"%s: Unimplemented method", __PRETTY_FUNCTION__)
