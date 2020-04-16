project(foundation)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -nostdinc -mmacosx-version-min=10.10 \
	-include ${CMAKE_SOURCE_DIR}/src/external/corefoundation/CoreFoundation_Prefix.h \
	-include ${CMAKE_SOURCE_DIR}/src/external/corefoundation/macros.h")

include(darling_framework)

include_directories(
	${CMAKE_SOURCE_DIR}/src/external/corefoundation
	${CMAKE_CURRENT_SOURCE_DIR}/include/Foundation
	${CMAKE_CURRENT_SOURCE_DIR}/src
)

add_definitions(
	-DNSBUILDINGFOUNDATION=1
	-DINCLUDE_OBJC
	-DDEPLOYMENT_TARGET_MACOSX=1
	-D__CONSTANT_CFSTRINGS__=1
	-D__CONSTANT_STRINGS__=1
)

set(foundation_sources
	src/_DebugUtils.m
	src/NSAppleScript.m
	src/NSAddressCheckingResult.m
	src/NSAffineTransform.m
	src/NSAggregateExpression.m
	src/NSAnyKeyExpression.m
	src/NSArchiver.m
	src/NSArray.m
	src/NSAttributedString.m
	src/NSAutoreleasePool.m
	src/NSBetweenPredicateOperator.m
	src/NSBlockExpression.m
	src/NSBlockPredicate.m
	src/NSBOMEncoding.m
	src/NSBundle.m
	src/NSByteCountFormatter.m
	src/NSCalendar.m
	src/NSCheapMutableString.m
	src/NSClassDescription.m
	src/NSCoder.m
	src/NSComparisonPredicate.m
	src/NSComparisonPredicateOperator.m
	src/NSCompoundPredicate.m
	src/NSCompoundPredicateOperator.m
	src/NSConstantValueExpression.m
	src/NSCustomPredicateOperator.m
	src/NSDataDetector.m
	src/NSData.m
	src/NSDateFormatter.m
	src/NSDateCheckingResult.m
	src/NSDate.m
	src/NSDebug.m
	src/NSDecimal.m
	src/NSDecimalNumber.m
	src/NSDictionary.m
	src/NSDirectoryEnumerator.m
	src/NSDistributedNotificationCenter.m
	src/NSEqualityPredicateOperator.m
	src/NSException.m
	src/NSExpression.m
	src/NSExternals.m
	src/NSFalsePredicate.m
	src/NSFileAttributes.m
	src/NSFileCoordinator.m
	src/NSFileHandle.m
	src/_NSFileIO.m
	src/NSFileManager.m
	src/NSFilesystemItemRemoveOperation.m
	src/NSFormatter.m
	src/NSFunctionExpression.m
	src/NSGeometry.m
	src/NSGrammarCheckingResult.m
	src/NSHashTable.m
	src/NSHost.m
	src/NSHTTPCookie.m
	src/NSHTTPCookieStorage.m
	src/NSIndexPath.m
	src/NSIndexSet.m
	src/NSInPredicateOperator.m
	src/NSJSONSerialization.m
	src/NSKeyedArchiver.m
	src/_NSKeyedCoderOldStyleArray.m
	src/NSKeyedUnarchiver.m
	src/NSKeyPathExpression.m
	src/NSKeyPathSpecifierExpression.m
	src/NSKeyValueAccessor.m
	src/NSKeyValueCodingInternal.m
	src/NSKeyValueCoding.m
	src/NSKeyValueCollectionProxies.m
	src/NSKeyValueComputedProperty.m
	src/NSKeyValueContainerClass.m
	src/NSKeyValueChangeDictionary.m
	src/NSKeyValueNestedProperty.m
	src/NSKeyValueObservance.m
	src/NSKeyValueObservationInfo.m
	src/NSKeyValueObserving.m
	src/NSKeyValueProperty.m
	src/NSKeyValueUnnestedProperty.m
	src/NSLikePredicateOperator.m
	src/NSLinguisticTagger.m
	src/NSLinkCheckingResult.m
	src/NSLocale.m
	src/NSLocalizableString.m
	src/NSLock.m
	src/NSLog.m
	src/NSMapTable.m
	src/NSMatchingPredicateOperator.m
	src/NSMutableStringProxy.m
	#src/NSMutableStringProxyForMutableAttributedString.m # duplicate?!
	src/NSNestedDictionary.m
	src/NSNetServices.m
	src/NSNotificationCenter.m
	src/NSNotification.m
	src/NSNotificationQueue.m
	src/NSNumberFormatter.m
	src/NSNumber.m
	src/NSObjCRuntime.m
	src/NSObjectInternal.m
	src/NSObject+NSComparisonMethods.m
	src/NSObject+NSScriptClassDescription.m
	src/NSOperation.m
	src/NSOrthographyCheckingResult.m
	src/NSOrthography.m
	src/NSPathStore.m
	src/NSPathUtilities.m
	src/NSPhoneNumberCheckingResult.m

	src/NSPlatform_Apportable.m  # unrelated
	src/NSPlatform.m
	src/NSPlatform_posix.m
	src/NSPlatform_darwin.m

	src/NSPort.m
	src/NSSocketPort.m
	src/NSPortCoder.m
	src/NSPortMessage.m
	src/NSConcretePortCoder.m
	src/NSUnkeyedPortCoder.m
	src/NSKeyedPortCoder.m
	src/NSConnection.m
	src/NSDistantObject.m
	src/NSDistantObjectRequest.m
	src/NSConcreteDistantObjectRequest.m
	src/NSProtocolChecker.m
	src/NSConcreteProtocolChecker.m
	src/NSPortNameServer.m
	src/NSMachBootstrapServer.m

	src/NSPointerArray.m
	src/NSPointerFunctions.m
	src/NSPredicateLexer.m
	src/NSPredicate.m
	src/NSPredicateOperator.m
	src/NSPredicateParser.tab.c
	src/_NSPredicateOperatorUtilities.m
	src/_NSPredicateUtilities.m
	src/NSProcessInfo.m
	src/NSProgress.m
	src/NSProxy.m
	src/NSRange.m
	src/NSRangeEntries.m
	src/NSRaise.m
	src/NSRegularExpressionCheckingResult.m
	src/NSRegularExpression.m
	src/NSRunLoop.m
	src/NSScanner.m
	src/NSSelfExpression.m
	src/NSSetExpression.m
	src/NSSet.m
	src/NSSortDescriptor.m
	src/NSSpellCheckingResult.m
	src/NSString.m
	src/NSStringPredicateOperator.m
	src/NSSubqueryExpression.m
	src/NSSubstitutionCheckingResult.m
	src/NSSubstringPredicateOperator.m
	src/NSSymbolicExpression.m
	src/NSTask.m
	src/NSTernaryExpression.m
	src/NSTextCheckingResult.m
	src/NSThread.m
	src/NSTimer.m
	src/NSTimeZone.m
	src/NSTokenMatchingPredicateOperator.m
	src/NSTransitInformationCheckingResult.m
	src/NSTruePredicate.m
	src/NSUbiquitousKeyValueStore.m
	src/NSUndoGroup.m
	src/NSUndoManager.m
	src/NSUserDefaults.m
	src/NSURLAuthenticationChallenge.m
	src/NSURLCache.m
	src/NSURLComponents.m
	src/NSURLConnection.m
	src/NSURLCredential.m
	src/NSURLCredentialStorage.m
	src/NSURLError.m
	# src/NSURLHandle.m # deprecated since 10.4, from GNUstep
	src/NSURL.m
	src/NSURLProtectionSpace.m
	src/NSURLProtocol.m
	src/NSURLRequest.m
	src/NSURLResponse.m
	src/NSURLSession.m
	src/NSUUID.m
	src/NSValue.m
	src/NSValueTransformer.m
	src/NSVariableAssignmentExpression.m
	src/NSVariableExpression.m
	src/NSXMLDocument.m
	src/NSXMLDTD.m
	src/NSXMLDTDNode.m
	src/NSXMLElement.m
	src/NSXMLNode.m
	src/NSXMLParser.m
	src/NSXPCCoder.m
	src/NSZone.m

	src/NSConcreteHashTable.m
	src/NSConcreteMapTable.m
	src/NSCallBacks.m

	src/NSSpellServer.m
	src/NSSpellEngine.m
	src/stub.m
	src/NSFileWrapper.m
	src/NSAppleEventDescriptor.m
	src/NSXPCInterface.m

	src/NSURLDownload.m
	src/NSXPCConnection.m
	src/NSAppleEventManager.m
	src/NSDateComponentsFormatter.m
	src/NSMeasurementFormatter.m
	src/NSAppleScript.m
	src/NSMetadata.m
	src/NSLayoutConstraint.m
	src/NSExtensionContext.m
	src/NSISO8601DateFormatter.m
	src/NSScriptObjectSpecifiers.m
	src/NSScriptCommand.m
	src/NSScriptCommandDescription.m
	src/NSScriptClassDescription.m
	src/NSUserNotification.m
	src/NSDateInterval.m
	src/NSGarbageCollector.m
	src/NSUnarchiver.m
	src/NSDeserializer.m
	src/NSPortNameServer.m
)

# Includes ObjC headers -> must be compiled as ObjC
set_source_files_properties(src/NSPredicateParser.tab.c PROPERTIES COMPILE_FLAGS "-x objective-c -fblocks")

set(DYLIB_COMPAT_VERSION "300.0.0")
set(DYLIB_CURRENT_VERSION "1349.0.0")

add_framework(Foundation
    FAT
	CURRENT_VERSION
	SOURCES
		${foundation_sources}
	VERSION "C"
	DEPENDENCIES
		objc
		system
		CoreFoundation
		CFNetwork
		xml2
	LINK_FLAGS " -Wl,-reexport_library,${CMAKE_BINARY_DIR}/src/external/corefoundation/CoreFoundation \
				-Wl,-reexport_library,${CMAKE_BINARY_DIR}/src/external/objc4/runtime/libobjc.A.dylib"
)

add_darling_executable(defaults tools/defaults.m)
target_link_libraries(defaults Foundation)
install(TARGETS defaults DESTINATION libexec/darling/usr/bin)
install(FILES tools/defaults.1 DESTINATION libexec/darling/usr/share/man/man1)

