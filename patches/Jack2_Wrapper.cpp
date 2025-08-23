/*
#216 2.139 ../common/JackEngineProfiling.cpp: In constructor 'Jack::JackEngineProfiling::JackEngineProfiling()':
#216 2.139 ../common/JackEngineProfiling.cpp:39:11: warning: 'void* memset(void*, int, size_t)' clearing an object of non-trivial type 'struct Jack::JackTimingMeasure'; use assignment or value-initialization instead [-Wclass-memaccess]
#216 2.139    39 |     memset(fProfileTable, 0, sizeof(fProfileTable));
#216 2.139       |     ~~~~~~^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#216 2.139 In file included from ../common/JackEngineProfiling.cpp:20:
#216 2.139 ../common/JackEngineProfiling.h:84:8: note: 'struct Jack::JackTimingMeasure' declared here
#216 2.139    84 | struct JackTimingMeasure
#216 2.139       |        ^~~~~~~~~~~~~~~~~
#216 2.139 
#216 2.139 [ 27/182] Compiling posix/JackPosixProcessSync.cpp
#216 2.186 ../common/JackDebugClient.cpp: In member function 'virtual int Jack::JackDebugClient::Open(const char*, const char*, jack_uuid_t, jack_options_t, jack_status_t*)':
#216 2.186 ../common/JackDebugClient.cpp:94:60: warning: '%s' directive output may be truncated writing up to 255 bytes into a region of size 239 [-Wformat-truncation=]
#216 2.186    94 |     snprintf(provstr, sizeof(provstr), "JackClientDebug-%s-%s.log", name, buffer);
#216 2.186       |                                                            ^~             ~~~~~~
#216 2.186 ../common/JackDebugClient.cpp:94:13: note: 'snprintf' output 22 or more bytes (assuming 277) into a destination of size 256
#216 2.186    94 |     snprintf(provstr, sizeof(provstr), "JackClientDebug-%s-%s.log", name, buffer);
#216 2.186       |     ~~~~~~~~^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#216 2.186 
*/