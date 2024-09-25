//
// This file was auto-generated using the following command:
//
// jai ./generate.jai
//



DC_BOOL :: s32;

DC_POINTER :: *void;

DC_TRUE :: 1;
DC_FALSE :: 0;

DC_CALL_C_DEFAULT :: 0;
DC_CALL_C_ELLIPSIS :: 100;
DC_CALL_C_ELLIPSIS_VARARGS :: 101;
DC_CALL_C_X86_CDECL :: 1;
DC_CALL_C_X86_WIN32_STD :: 2;
DC_CALL_C_X86_WIN32_FAST_MS :: 3;
DC_CALL_C_X86_WIN32_FAST_GNU :: 4;
DC_CALL_C_X86_WIN32_THIS_MS :: 5;
DC_CALL_C_X86_WIN32_THIS_GNU :: DC_CALL_C_X86_CDECL;
DC_CALL_C_X64_WIN64 :: 7;
DC_CALL_C_X64_SYSV :: 8;
DC_CALL_C_PPC32_DARWIN :: 9;
DC_CALL_C_PPC32_OSX :: DC_CALL_C_PPC32_DARWIN;
DC_CALL_C_ARM_ARM_EABI :: 10;
DC_CALL_C_ARM_THUMB_EABI :: 11;
DC_CALL_C_ARM_ARMHF :: 30;
DC_CALL_C_MIPS32_EABI :: 12;
DC_CALL_C_MIPS32_PSPSDK :: DC_CALL_C_MIPS32_EABI;
DC_CALL_C_PPC32_SYSV :: 13;
DC_CALL_C_PPC32_LINUX :: DC_CALL_C_PPC32_SYSV;
DC_CALL_C_ARM_ARM :: 14;
DC_CALL_C_ARM_THUMB :: 15;
DC_CALL_C_MIPS32_O32 :: 16;
DC_CALL_C_MIPS64_N32 :: 17;
DC_CALL_C_MIPS64_N64 :: 18;
DC_CALL_C_X86_PLAN9 :: 19;
DC_CALL_C_SPARC32 :: 20;
DC_CALL_C_SPARC64 :: 21;
DC_CALL_C_ARM64 :: 22;
DC_CALL_C_PPC64 :: 23;
DC_CALL_C_PPC64_LINUX :: DC_CALL_C_PPC64;
DC_CALL_SYS_DEFAULT :: 200;
DC_CALL_SYS_X86_INT80H_LINUX :: 201;
DC_CALL_SYS_X86_INT80H_BSD :: 202;
DC_CALL_SYS_X64_SYSCALL_SYSV :: 204;
DC_CALL_SYS_PPC32 :: 210;
DC_CALL_SYS_PPC64 :: 211;

DC_ERROR_NONE :: 0;
DC_ERROR_UNSUPPORTED_MODE :: -1;

DEFAULT_ALIGNMENT :: 0;

DCvoid :: void;
DCbool :: s32;
DCchar :: u8;
DCuchar :: u8;
DCshort :: s16;
DCushort :: u16;
DCint :: s32;
DCuint :: u32;
DClong :: s32;
DCulong :: u32;
DClonglong :: s64;
DCulonglong :: u64;
DCfloat :: float;
DCdouble :: float64;
DCpointer :: *void;
DCstring :: *u8;
DCsize :: u64;

DCsigchar :: u8;

DCCallVM_ :: struct {}
DCCallVM :: DCCallVM_;
DCstruct_ :: struct {}
DCstruct :: DCstruct_;

dcNewCallVM :: (size: DCsize) -> *DCCallVM #foreign libdyncall_s;
dcFree :: (vm: *DCCallVM) -> void #foreign libdyncall_s;
dcReset :: (vm: *DCCallVM) -> void #foreign libdyncall_s;

dcMode :: (vm: *DCCallVM, mode: DCint) -> void #foreign libdyncall_s;

dcArgBool :: (vm: *DCCallVM, value: DCbool) -> void #foreign libdyncall_s;
dcArgChar :: (vm: *DCCallVM, value: DCchar) -> void #foreign libdyncall_s;
dcArgShort :: (vm: *DCCallVM, value: DCshort) -> void #foreign libdyncall_s;
dcArgInt :: (vm: *DCCallVM, value: DCint) -> void #foreign libdyncall_s;
dcArgLong :: (vm: *DCCallVM, value: DClong) -> void #foreign libdyncall_s;
dcArgLongLong :: (vm: *DCCallVM, value: DClonglong) -> void #foreign libdyncall_s;
dcArgFloat :: (vm: *DCCallVM, value: DCfloat) -> void #foreign libdyncall_s;
dcArgDouble :: (vm: *DCCallVM, value: DCdouble) -> void #foreign libdyncall_s;
dcArgPointer :: (vm: *DCCallVM, value: DCpointer) -> void #foreign libdyncall_s;
dcArgStruct :: (vm: *DCCallVM, s: *DCstruct, value: DCpointer) -> void #foreign libdyncall_s;

dcCallVoid :: (vm: *DCCallVM, funcptr: DCpointer) -> void #foreign libdyncall_s;
dcCallBool :: (vm: *DCCallVM, funcptr: DCpointer) -> DCbool #foreign libdyncall_s;
dcCallChar :: (vm: *DCCallVM, funcptr: DCpointer) -> DCchar #foreign libdyncall_s;
dcCallShort :: (vm: *DCCallVM, funcptr: DCpointer) -> DCshort #foreign libdyncall_s;
dcCallInt :: (vm: *DCCallVM, funcptr: DCpointer) -> DCint #foreign libdyncall_s;
dcCallLong :: (vm: *DCCallVM, funcptr: DCpointer) -> DClong #foreign libdyncall_s;
dcCallLongLong :: (vm: *DCCallVM, funcptr: DCpointer) -> DClonglong #foreign libdyncall_s;
dcCallFloat :: (vm: *DCCallVM, funcptr: DCpointer) -> DCfloat #foreign libdyncall_s;
dcCallDouble :: (vm: *DCCallVM, funcptr: DCpointer) -> DCdouble #foreign libdyncall_s;
dcCallPointer :: (vm: *DCCallVM, funcptr: DCpointer) -> DCpointer #foreign libdyncall_s;
dcCallStruct :: (vm: *DCCallVM, funcptr: DCpointer, s: *DCstruct, returnValue: DCpointer) -> void #foreign libdyncall_s;

dcGetError :: (vm: *DCCallVM) -> DCint #foreign libdyncall_s;

dcNewStruct :: (fieldCount: DCsize, alignment: DCint) -> *DCstruct #foreign libdyncall_s;
dcStructField :: (s: *DCstruct, type: DCint, alignment: DCint, arrayLength: DCsize) -> void #foreign libdyncall_s;
dcSubStruct :: (s: *DCstruct, fieldCount: DCsize, alignment: DCint, arrayLength: DCsize) -> void #foreign libdyncall_s;

/* Each dcNewStruct or dcSubStruct call must be paired with a dcCloseStruct. */
dcCloseStruct :: (s: *DCstruct) -> void #foreign libdyncall_s;
dcStructSize :: (s: *DCstruct) -> DCsize #foreign libdyncall_s;
dcStructAlignment :: (s: *DCstruct) -> DCsize #foreign libdyncall_s;
dcFreeStruct :: (s: *DCstruct) -> void #foreign libdyncall_s;

dcDefineStruct :: (signature: *u8) -> *DCstruct #foreign libdyncall_s;

/* returns respective mode for callconv sig char (w/o checking if mode exists */
/* on current platform), or DC_ERROR_UNSUPPORTED_MODE if char isn't a sigchar */
dcGetModeFromCCSigChar :: (sig_char: DCsigchar) -> DCint #foreign libdyncall_s;

DCerror :: s32;

dcAllocWX :: (size: DCsize, p: **void) -> DCerror #foreign libdyncallback_s;
dcInitExecWX :: (p: *void, size: DCsize) -> DCerror #foreign libdyncallback_s;
dcFreeWX :: (p: *void, size: DCsize) -> void #foreign libdyncallback_s;

DCArgs :: struct {}

dcbArgBool :: (unknown0: *DCArgs) -> DCbool #foreign libdyncallback_s;
dcbArgChar :: (unknown0: *DCArgs) -> DCchar #foreign libdyncallback_s;
dcbArgShort :: (unknown0: *DCArgs) -> DCshort #foreign libdyncallback_s;
dcbArgInt :: (unknown0: *DCArgs) -> DCint #foreign libdyncallback_s;
dcbArgLong :: (unknown0: *DCArgs) -> DClong #foreign libdyncallback_s;
dcbArgLongLong :: (unknown0: *DCArgs) -> DClonglong #foreign libdyncallback_s;
dcbArgUChar :: (unknown0: *DCArgs) -> DCuchar #foreign libdyncallback_s;
dcbArgUShort :: (unknown0: *DCArgs) -> DCushort #foreign libdyncallback_s;
dcbArgUInt :: (unknown0: *DCArgs) -> DCuint #foreign libdyncallback_s;
dcbArgULong :: (unknown0: *DCArgs) -> DCulong #foreign libdyncallback_s;
dcbArgULongLong :: (unknown0: *DCArgs) -> DCulonglong #foreign libdyncallback_s;
dcbArgFloat :: (unknown0: *DCArgs) -> DCfloat #foreign libdyncallback_s;
dcbArgDouble :: (unknown0: *DCArgs) -> DCdouble #foreign libdyncallback_s;
dcbArgPointer :: (unknown0: *DCArgs) -> DCpointer #foreign libdyncallback_s;

DCValue :: DCValue_;

DCValue_ :: union {
    B: DCbool;
    c: DCchar;
    C: DCuchar;
    s: DCshort;
    S: DCushort;
    i: DCint;
    I: DCuint;

    j: DClong;
    J: DCulong;
    l: DClonglong;
    L: DCulonglong;

    f: DCfloat;

    d: DCdouble;
    p: DCpointer;
    Z: DCstring;
}

DCCallback :: struct {}

// return value is the type encoded as a signature char (character of the set [vBcCsSiIjJlLfd]).
DCCallbackHandler :: #type (pcb: *DCCallback, args: *DCArgs, result: *DCValue, userdata: *void) -> u8 #c_call;

dcbNewCallback :: (signature: *u8, funcptr: DCCallbackHandler, userdata: *void) -> *DCCallback #foreign libdyncallback_s;
dcbInitCallback :: (pcb: *DCCallback, signature: *u8, handler: DCCallbackHandler, userdata: *void) -> void #foreign libdyncallback_s;
dcbFreeCallback :: (pcb: *DCCallback) -> void #foreign libdyncallback_s;
dcbGetUserData :: (pcb: *DCCallback) -> *void #foreign libdyncallback_s;

dcArgF :: (vm: *DCCallVM, signature: *DCsigchar, __args: ..Any) -> void #foreign libdyncall_s;

dcCallF :: (vm: *DCCallVM, result: *DCValue, funcptr: DCpointer, signature: *DCsigchar, __args: ..Any) -> void #foreign libdyncall_s;

DLLib_ :: struct {}
/* shared library loading and explicit symbol resolving */
/* dlLoadLibrary will search for specified lib (e.g. as leaf name, only), */
/* following platforms' dynamic linking style, returns NULL on error */
DLLib :: DLLib_;

dlLoadLibrary :: (libPath: *u8) -> *DLLib #foreign libdynload_s;
dlFreeLibrary :: (pLib: *DLLib) -> void #foreign libdynload_s;
dlFindSymbol :: (pLib: *DLLib, pSymbolName: *u8) -> *void #foreign libdynload_s;
dlGetLibraryPath :: (pLib: *DLLib, sOut: *u8, bufSize: s32) -> s32 #foreign libdynload_s;

DLSyms_ :: struct {}
/* symbol table enumeration - only for symbol lookup, not resolve */
/* note that dlSymsInit does not search library paths */
DLSyms :: DLSyms_;

dlSymsInit :: (libPath: *u8) -> *DLSyms #foreign libdynload_s;
dlSymsCleanup :: (pSyms: *DLSyms) -> void #foreign libdynload_s;

dlSymsCount :: (pSyms: *DLSyms) -> s32 #foreign libdynload_s;
dlSymsName :: (pSyms: *DLSyms, index: s32) -> *u8 #foreign libdynload_s;
dlSymsNameFromValue :: (pSyms: *DLSyms, value: *void) -> *u8 #foreign libdynload_s;

#scope_file


#if OS == .WINDOWS {
    libdyncall_s :: #library,no_dll "windows/libdyncall_s";
    libdyncallback_s :: #library,no_dll "windows/libdyncallback_s";
    libdynload_s :: #library,no_dll "windows/libdynload_s";
} else #if OS == .LINUX {
    libdyncall_s :: #library,no_dll "linux/libdyncall_s";
    libdyncallback_s :: #library,no_dll "linux/libdyncallback_s";
    libdynload_s :: #library,no_dll "linux/libdynload_s";
} else #if OS == .MACOS {
    libdyncall_s :: #library,no_dll "macos/libdyncall_s";
    libdyncallback_s :: #library,no_dll "macos/libdyncallback_s";
    libdynload_s :: #library,no_dll "macos/libdynload_s";
} else #if OS == .ANDROID {
    #if CPU == .X64 {
        libdyncall_s :: #library,no_dll "android/x64/libdyncall_s";
        libdyncallback_s :: #library,no_dll "android/x64/libdyncallback_s";
        libdynload_s :: #library,no_dll "android/x64/libdynload_s";
    } else #if CPU == .ARM64 {
        libdyncall_s :: #library,no_dll "android/arm64/libdyncall_s";
        libdyncallback_s :: #library,no_dll "android/arm64/libdyncallback_s";
        libdynload_s :: #library,no_dll "android/arm64/libdynload_s";
    }
} else #if OS == .PS5 {
    libdyncall_s :: #library,no_dll "ps5/libdyncall_s";
    libdyncallback_s :: #library,no_dll "ps5/libdyncallback_s";
    libdynload_s :: #library,no_dll "ps5/libdynload_s";
} else {
    #assert false;
}

