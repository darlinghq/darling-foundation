project(libfoundation)

cmake_minimum_required(VERSION 2.4.0)

if(COMMAND cmake_policy)
	cmake_policy(SET CMP0003 NEW)
	cmake_policy(SET CMP0005 NEW)
endif(COMMAND cmake_policy)

add_definitions(-D__APPLE__ -D__MACH__)
add_definitions(-DTARGET_OS_MAC=1)
add_definitions(-DHAVE_STDINT_H=1)
add_definitions(-D__APPLE__ -D__DYNAMIC__)
add_definitions(-D__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__=1080)
add_definitions(-DOBJC_ZEROCOST_EXCEPTIONS=1 -DGNUSTEP -DPRIxPTR=\"lx\" -DPRIuPTR=\"lu\" -DPRIdPTR=\"ld\" -DPRIu64=\"ull\")
add_definitions(-U__linux__) # Because of broken ifdef in NSPage.m
add_definitions(-DGNUSTEP_BASE_LIBRARY)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -nostdinc -D__DARWIN_UNIX03 -fPIC -w -fconstant-string-class=NSConstantString -fobjc-nonfragile-abi -include ${CMAKE_CURRENT_BINARY_DIR}/config.h -ggdb -O0")
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -nostdlib -Wl,--version-script=${DARLING_TOP_DIRECTORY}/darwin.map")

SET(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib${SUFFIX}/darling")
SET(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE) 
SET(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)

include_directories(${CMAKE_CURRENT_SOURCE_DIR})
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/Headers)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/Source)
include_directories(${CMAKE_CURRENT_BINARY_DIR})
include_directories(${CMAKE_CURRENT_BINARY_DIR}/Headers)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../libobjc2)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../libdispatch)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../icu/icuSources/common)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../icu/icuSources/i18n)
include_directories(${DARLING_TOP_DIRECTORY}/src/libffi/include)
include_directories(${DARLING_TOP_DIRECTORY}/src/libc/stdtime/FreeBSD)
include_directories(${DARLING_TOP_DIRECTORY}/src/libmalloc/include/malloc)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../openssl/src/include)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../libxml2/include)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../libxslt/include)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../zlib)

set(OBJC2RUNTIME 1)
set(BASE_NATIVE_OBJC_EXCEPTIONS 1)
set(GS_SINT8 "signed char")
set(GS_UINT8 "unsigned char")
set(GS_SINT16 "signed short")
set(GS_UINT16 "unsigned short")
set(GS_SINT64 "signed long long")
set(GS_UINT64 "unsigned long long")
set(GS_SADDR "signed long")
set(GS_UADDR "unsigned long")
set(GS_FLT32 "float")
set(GS_FLT64 "double")
set(GS_HAVE_I64 1)
set(ac_cv_sizeof_short 2)
set(ac_cv_sizeof_int 4)
set(ac_cv_sizeof_long_long 8)
set(ac_cv_sizeof_float 4)
set(ac_cv_sizeof_double 8)
set(_GSC_S_SHT "_GSC_I16")
set(_GSC_S_INT "_GSC_I32")
set(_GSC_S_LNG "_GSC_I64")
set(_GSC_S_LNG_LNG "_GSC_I64")

if (BITS EQUAL 64)
	set(GS_SINT32 "signed int")
	set(GS_UINT32 "unsigned int")
	set(ac_cv_sizeof_long 8)
	set(ac_cv_sizeof_voidp 8)
	set(GS_SIZEOF_COND_T 48)
	set(GS_SIZEOF_MUTEX_T 64)
	set(GS_ALIGNOF_COND_T 8)
	set(GS_ALIGNOF_MUTEX_T 8)
	set(_GSC_S_LNG "_GSC_I64")
	set(SIZEOF_VOIDP 8)
	set(GS_HAVE_I128 1)
	set(GS_SINT128 "__int128_t")
	set(GS_UINT128 "__uint128_t")
else (BITS EQUAL 64)
	set(GS_SINT32 "signed long")
	set(GS_UINT32 "unsigned long")
	set(ac_cv_sizeof_long 4)
	set(ac_cv_sizeof_voidp 4)
	set(GS_SIZEOF_COND_T 28)
	set(GS_SIZEOF_MUTEX_T 44)
	set(GS_ALIGNOF_COND_T 4)
	set(GS_ALIGNOF_MUTEX_T 4)
	set(_GSC_S_LNG "_GSC_I32")
	set(SIZEOF_VOIDP 4)
	set(GS_SINT128 "struct { gsu8 a[16]; }")
	set(GS_UINT128 "struct { gsu8 a[16]; }")
	set(GS_HAVE_I128 0)
endif (BITS EQUAL 64)

set(HAVE_LIBXML 1)
set(HAVE_BLOCKS 1)
set(HAVE_GNUTLS 0)
set(HAVE_INET_PTON 1)
set(HAVE_INET_NTOP 1)
set(HAVE_LIBDISPATCH 1)
set(HAVE_ICU 1)
set(USE_ZLIB 1)
set(BUGGY_PTR_LIMITS 0)
set(NX_CONST_STRING_CLASS "NSConstantString")
set(GS_NONFRAGILE 1)
set(GS_MIXEDABI 0)
set(GS_FAKE_MAIN 0)
set(GS_PASS_ARGUMENTS 0)
set(HAVE_MDNS 0)
set(HAVE_AVAHI 0)
set(GS_HAVE_OBJC_ROOT_CLASS_ATTR 0)
set(GS_WORDS_BIGENDIAN 0)
set(INCLUDE_INTTYPES "#include <stdint.h>")

set(VERSION "1.24.8")
set(MAJOR_VERSION 1)
set(MINOR_VERSION 24)
set(SUBMINOR_VERSION 8)
set(GCC_VERSION "${CMAKE_CXX_COMPILER_VERSION}")

configure_file(Headers/GNUstepBase/GSConfig.h.in
	Headers/GNUstepBase/GSConfig.h)
configure_file(config.h.in config.h)

set(foundation_SRCS
	Source/Additions/GSTypeEncoding.c
	Source/NSConcreteMapTable.m
	Source/NSBundle.m
	Source/NSUserNotification.m
	Source/NSPortMessage.m
	Source/NSConnection.m
	Source/NSKeyValueCoding.m
	Source/NSURLConnection.m
	Source/NSDebug.m
	Source/NSDictionary.m
	Source/GSTimSort.m
	# Source/GSFFCallInvocation.m
	Source/NSScanner.m
	Source/NSPipe.m
	Source/NSNull.m
	Source/NSLog.m
	Source/NSSocketPortNameServer.m
	Source/NSPathUtilities.m
	Source/NSXMLDocument.m
	Source/NSMessagePort.m
	Source/unix/NSStream.m
	Source/unix/GSRunLoopCtxt.m
	Source/GSFormat.m
	Source/NSMapTable.m
	Source/NSNotificationQueue.m
	Source/GSString.m
	Source/NSInvocation.m
	Source/NSPropertyList.m
	Source/GSLocale.m
	Source/GSTLS.m
	Source/NSHTTPCookie.m
	Source/cifframe.m
	Source/NSDecimalNumber.m
	Source/NSURLAuthenticationChallenge.m
	Source/NSURLProtocol.m
	# Source/NSKeyValueMutableArray.m
	# Source/ObjectiveC2/NSBlocks.m
	# Source/ObjectiveC2/blocks_runtime.m
	# Source/ObjectiveC2/sync.m
	# Source/ObjectiveC2/properties.m
	Source/GSStream.m
	Source/NSPredicate.m
	Source/NSTimer.m
	Source/NSPort.m
	# Source/GSAvahiNetService.m
	Source/GSQuickSort.m
	Source/NSTimeZone.m
	Source/GSHTTPAuthentication.m
	Source/NSSet.m
	Source/NSPointerArray.m
	Source/NSFileManager.m
	Source/NSDistantObject.m
	Source/NSTask.m
	Source/Additions/NSNumber+GNUstepBase.m
	Source/Additions/GSLock.m
	Source/Additions/NSTask+GNUstepBase.m
	Source/Additions/Unicode.m
	Source/Additions/NSObject+GNUstepBase.m
	Source/Additions/NSArray+GNUstepBase.m
	Source/Additions/NSBundle+GNUstepBase.m
	Source/Additions/NSDebug+GNUstepBase.m
	Source/Additions/GCArray.m
	Source/Additions/GSXML.m
	Source/Additions/NSStream+GNUstepBase.m
	Source/Additions/NSPropertyList+GNUstepBase.m
	Source/Additions/NSFileHandle+GNUstepBase.m
	Source/Additions/NSMutableString+GNUstepBase.m
	Source/Additions/NSAttributedString+GNUstepBase.m
	Source/Additions/NSHashTable+GNUstepBase.m
	Source/Additions/NSError+GNUstepBase.m
	Source/Additions/GCDictionary.m
	Source/Additions/NSThread+GNUstepBase.m
	Source/Additions/GSInsensitiveDictionary.m
	Source/Additions/GSFunctions.m
	Source/Additions/NSCalendarDate+GNUstepBase.m
	Source/Additions/NSData+GNUstepBase.m
	Source/Additions/GCObject.m
	Source/Additions/NSString+GNUstepBase.m
	Source/Additions/NSProcessInfo+GNUstepBase.m
	Source/Additions/NSLock+GNUstepBase.m
	Source/Additions/GSObjCRuntime.m
	Source/Additions/GSMime.m
	Source/Additions/NSURL+GNUstepBase.m
	Source/NSValue.m
	Source/GSRunLoopWatcher.m
	Source/NSZone.m
	Source/NSClassDescription.m
	Source/NSRange.m
	Source/NSKeyValueObserving.m
	Source/NSLock.m
	Source/externs.m
	# Source/GSConcreteValueTemplate.m
	Source/NSGeometry.m
	Source/NSAttributedString.m
	Source/NSJSONSerialization.m
	Source/NSDate.m
	Source/NSNotification.m
	Source/NSNumberFormatter.m
	Source/NSTextCheckingResult.m
	Source/NSError.m
	Source/GSPrivateHash.m
	Source/NSConcreteHashTable.m
	Source/NSRunLoop.m
	Source/GSShellSort.m
	Source/NSProcessInfo.m
	Source/NSArray.m
	Source/NSURLRequest.m
	Source/NSRegularExpression.m
	Source/NSIndexSet.m
	Source/NSString.m
	Source/objc-load.m
	Source/NSDateFormatter.m
	Source/NSMetadata.m
	Source/NSFormatter.m
	Source/NSDecimal.m
	Source/NSURLCache.m
	Source/NSSocketPort.m
	Source/NSCache.m
	Source/NSArchiver.m
	Source/NSGarbageCollector.m
	Source/NSUnarchiver.m
	Source/NSURLCredentialStorage.m
	Source/GSFileHandle.m
	Source/NSCalendar.m
	Source/preface.m
	Source/NSKeyedUnarchiver.m
	Source/NSAssertionHandler.m
	Source/NSValueTransformer.m
	Source/GSSet.m
	Source/GSSocketStream.m
	Source/NSCharacterSet.m
	Source/callframe.m
	Source/NSXMLElement.m
	Source/NSUserDefaults.m
	Source/GSFFIInvocation.m
	Source/NSData.m
	# Source/GSAvahiClient.m
	Source/NSXMLNode.m
	Source/NSSpellServer.m
	Source/NSURLProtectionSpace.m
	Source/GSValue.m
	# Source/libgnustep-base-entry.m
	Source/NSFileHandle.m
	Source/NSLocale.m
	Source/GSArray.m
	Source/NSNotificationCenter.m
	Source/NSPage.m
	Source/NSOperation.m
	Source/NSUndoManager.m
	Source/NSPointerFunctions.m
	Source/GSSocksParser/GSSocksParserPrivate.m
	Source/GSSocksParser/GSSocksParser.m
	Source/GSSocksParser/GSSocks5Parser.m
	Source/GSSocksParser/GSSocks4Parser.m
	Source/NSException.m
	Source/NSNetServices.m
	Source/NSURLDownload.m
	Source/GSFTPURLHandle.m
	Source/NSNumber.m
	Source/NSMessagePortNameServer.m
	Source/NSURL.m
	Source/CXXException.m
	# Source/NSKeyValueMutableSet.m
	Source/NSAutoreleasePool.m
	Source/NSCallBacks.m
	Source/GSBlocks.m
	Source/GSICUString.m
	Source/GSAttributedString.m
	Source/NSKeyedArchiver.m
	Source/NSObject+NSComparisonMethods.m
	Source/NSThread.m
	Source/NSAffineTransform.m
	Source/GSConcreteValue.m
	Source/NSSerializer.m
	Source/NSPortNameServer.m
	Source/NSCountedSet.m
	Source/NSXMLParser.m
	Source/NSObject.m
	# Source/inet_ntop.m
	# Source/GSAvahiRunLoopIntegration.m
	Source/NSUUID.m
	Source/NSCalendarDate.m
	Source/NSCachedURLResponse.m
	Source/NSInvocationOperation.m
	Source/GSHTTPURLHandle.m
	Source/NSEnumerator.m
	Source/GSDictionary.m
	Source/NSObjCRuntime.m
	Source/NSProxy.m
	Source/NSHTTPCookieStorage.m
	Source/NSURLCredential.m
	Source/GSCountedSet.m
	Source/NSURLHandle.m
	Source/NSDistributedNotificationCenter.m
	# Source/inet_pton.m
	# Source/GSAvahiNetServiceBrowser.m
	Source/NSXMLDTDNode.m
	Source/NSCopyObject.m
	Source/NSURLResponse.m
	Source/NSCoder.m
	Source/NSMethodSignature.m
	Source/NSSortDescriptor.m
	Source/NSHashTable.m
	Source/NSPortCoder.m
	Source/NSXMLDTD.m
	Source/NSConcretePointerFunctions.m
	Source/GSMDNSNetServices.m
	Source/NSIndexPath.m
	Source/NSDistributedLock.m
	Source/NSHost.m
	Source/NSProtocolChecker.m
)

set_source_files_properties(${foundation_SRCS} PROPERTIES LANGUAGE C)

add_library(Foundation OBJECT ${foundation_SRCS})
# target_link_libraries(Foundation system icucore z ffi xml2 xslt)

# install(TARGETS Foundation DESTINATION lib${SUFFIX}/darling)
