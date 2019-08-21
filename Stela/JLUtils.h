//
//  JLUtils.h
//
//  Created by Justin Loew on 3/13/15.
//  Copyright (c) 2015-2019 Justin Loew. All rights reserved.
//

#ifndef JLUtils_h
#define JLUtils_h


#ifndef JL_DEBUG_DEFINED
#define JL_DEBUG_DEFINED

// Enable or disable this whole system.
#define JL_DEBUG_ENABLED 1

// What to add to the logging messages.
#define JL_ADD_FILE_TO_LOGS			0
#define JL_ADD_FUNC_TO_LOGS			1
#define JL_ADD_LINE_TO_LOGS			1
#define JL_ADD_LOG_LEVEL_TO_LOGS	0

// Select log levels to enable.
#define JL_ENABLE_LOG_LEVEL_ALL			1
#define JL_ENABLE_LOG_LEVEL_ERROR		(1 && JL_ENABLE_LOG_LEVEL_ALL)
#define JL_ENABLE_LOG_LEVEL_WARNING		(1 && JL_ENABLE_LOG_LEVEL_ERROR)
#define JL_ENABLE_LOG_LEVEL_INFO		(1 && JL_ENABLE_LOG_LEVEL_WARNING)
#define JL_ENABLE_LOG_LEVEL_DEBUG		(1 && JL_ENABLE_LOG_LEVEL_INFO)
#define JL_ENABLE_LOG_LEVEL_VERBOSE		(1 && JL_ENABLE_LOG_LEVEL_DEBUG)

#define JL_IF_DEBUG if (JL_DEBUG_ENABLED)

// Define the logging verbosity levels.
#define JL_LOG_LEVEL_ERROR		1
#define JL_LOG_LEVEL_WARNING	2
#define JL_LOG_LEVEL_INFO		3
#define JL_LOG_LEVEL_DEBUG		4
#define JL_LOG_LEVEL_VERBOSE	5

// Output an actual log statement.
#define JL_FINALIZE_LOG(fmt, ...)										\
	do {																\
		JL_IF_DEBUG														\
			NSLog([NSString stringWithUTF8String:fmt] , ##__VA_ARGS__);	\
	} while (0)															\


// Prepend the file name.
#if JL_ADD_FILE_TO_LOGS
	#define JL_ADD_FILE2(fmt, ...) JL_FINALIZE_LOG("%s:" fmt, __FILE__ , ##__VA_ARGS__)
#else
	#define JL_ADD_FILE2(fmt, ...) JL_FINALIZE_LOG(fmt , ##__VA_ARGS__)
#endif
#define JL_ADD_FILE(fmt, ...) JL_ADD_FILE2(fmt , ##__VA_ARGS__)

// Prepend the function name.
#if JL_ADD_FUNC_TO_LOGS
	#define JL_ADD_FUNC2(fmt, ...) JL_ADD_FILE("%s:" fmt, __func__ , ##__VA_ARGS__)
#else
	#define JL_ADD_FUNC2(fmt, ...) JL_ADD_FILE(fmt , ##__VA_ARGS__)
#endif
#define JL_ADD_FUNC(fmt, ...) JL_ADD_FUNC2(fmt , ##__VA_ARGS__)

// Prepend the line number.
#if JL_ADD_LINE_TO_LOGS
	#define JL_ADD_LINE2(fmt, ...) JL_ADD_FUNC("%d:" fmt, __LINE__ , ##__VA_ARGS__)
#else
	#define JL_ADD_LINE2(fmt, ...) JL_ADD_FUNC(fmt , ##__VA_ARGS__)
#endif
#define JL_ADD_LINE(fmt, ...) JL_ADD_LINE2(fmt , ##__VA_ARGS__)

// Prepend the logging verbosity level.
#if JL_ADD_LOG_LEVEL_TO_LOGS
	#define JL_ADD_LOG_LEVEL2(level, fmt, ...)					\
		do {													\
			switch (level) {									\
			case JL_LOG_LEVEL_ERROR:							\
				JL_ADD_LINE("ERROR:" fmt , ##__VA_ARGS__);		\
				break;											\
			case JL_LOG_LEVEL_WARNING:							\
				JL_ADD_LINE("WARNING:" fmt , ##__VA_ARGS__);	\
				break;											\
			case JL_LOG_LEVEL_INFO:								\
				JL_ADD_LINE("INFO:" fmt , ##__VA_ARGS__);		\
				break;											\
			case JL_LOG_LEVEL_DEBUG:							\
				JL_ADD_LINE("DEBUG:" fmt , ##__VA_ARGS__);		\
				break;											\
			case JL_LOG_LEVEL_VERBOSE:							\
				JL_ADD_LINE("VERBOSE:" fmt , ##__VA_ARGS__);	\
				break;											\
			default:											\
				JL_ADD_LINE("UNKNOWN:" fmt , ##__VA_ARGS__);	\
				break;											\
			}													\
		} while (0)												\

#else
	#define JL_ADD_LOG_LEVEL2(level, fmt, ...) JL_ADD_LINE(fmt , ##__VA_ARGS__)
#endif
#define JL_ADD_LOG_LEVEL(level, fmt, ...) JL_ADD_LOG_LEVEL2(level, fmt , ##__VA_ARGS__)


// Add a space to the beginning of the format string if we're going to be adding any extra information.
#if JL_ADD_FILE_TO_LOGS || JL_ADD_FUNC_TO_LOGS || JL_ADD_LINE_TO_LOGS || JL_ADD_LOG_LEVEL_TO_LOGS
	#define JL_AUGMENT_FORMAT_STRING2(level, fmt, ...) JL_ADD_LOG_LEVEL(level, " " fmt , ##__VA_ARGS__)
#else
	#define JL_AUGMENT_FORMAT_STRING2(level, fmt, ...) JL_ADD_LOG_LEVEL(level, fmt , ##__VA_ARGS__)
#endif
#define JL_AUGMENT_FORMAT_STRING(level, fmt, ...) JL_AUGMENT_FORMAT_STRING2(level, fmt , ##__VA_ARGS__)

// Log errors.
#if JL_ENABLE_LOG_LEVEL_ERROR
	#define JL_ERROR2(fmt, ...) JL_AUGMENT_FORMAT_STRING(JL_LOG_LEVEL_ERROR, fmt , ##__VA_ARGS__)
#else
	#define JL_ERROR2(fmt, ...)
#endif
#define JLERROR(fmt, ...) JL_ERROR2(fmt , ##__VA_ARGS__)

// Log warnings.
#if JL_ENABLE_LOG_LEVEL_WARNING
	#define JL_WARNING2(fmt, ...) JL_AUGMENT_FORMAT_STRING(JL_LOG_LEVEL_WARNING, fmt , ##__VA_ARGS__)
#else
	#define JL_WARNING2(fmt, ...)
#endif
#define JLWARNING(fmt, ...) JL_WARNING2(fmt , ##__VA_ARGS__)

// Log information.
#if JL_ENABLE_LOG_LEVEL_INFO
	#define JL_INFO2(fmt, ...) JL_AUGMENT_FORMAT_STRING(JL_LOG_LEVEL_INFO, fmt , ##__VA_ARGS__)
#else
	#define JL_INFO2(fmt, ...)
#endif
#define JLINFO(fmt, ...) JL_INFO2(fmt , ##__VA_ARGS__)

// Log debug messages.
#if JL_ENABLE_LOG_LEVEL_DEBUG
	#define JL_DEBUG2(fmt, ...) JL_AUGMENT_FORMAT_STRING(JL_LOG_LEVEL_DEBUG, fmt , ##__VA_ARGS__)
#else
	#define JL_DEBUG2(fmt, ...)
#endif
#define JLDEBUG(fmt, ...) JL_DEBUG2(fmt , ##__VA_ARGS__)

// Log verbose debug messages.
#if JL_ENABLE_LOG_LEVEL_VERBOSE
	#define JL_VERBOSE2(fmt, ...) JL_AUGMENT_FORMAT_STRING(JL_LOG_LEVEL_VERBOSE, fmt , ##__VA_ARGS__)
#else
	#define JL_VERBOSE2(fmt, ...)
#endif
#define JLVERBOSE(fmt, ...) JL_VERBOSE2(fmt , ##__VA_ARGS__)


#endif // JL_DEBUG_DEFINED

#endif // JLUtils_h
