project(filecoordinationd)

include_directories(
	../../internal_include
)

add_darling_executable(filecoordinationd
	daemon.m
	XPCObject.m
	FileAccessRequest.m
	logging.m
)

target_link_libraries(filecoordinationd
	Foundation
)

install(TARGETS filecoordinationd DESTINATION libexec/darling/usr/sbin)
install(FILES com.apple.FileCoordination.plist DESTINATION libexec/darling/System/Library/LaunchDaemons)
