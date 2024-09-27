/*
    There is currently come kind of bug with the bindings generator creating a define for DC_POINTER, 
        where its leaving the type as void* instead of translating to *void.
    I probably need to have it strip that identifier and then just manually define it in module.jai
*/

AT_COMPILE_TIME :: true;

SOURCE_PATH :: "source";

INCLUDE_FILES :: string.[
    "dyncall.h", 
    "dyncall_alloc_wx.h", 
    "dyncall_args.h", 
    "dyncall_callback.h", 
    "dyncall_callf.h", 
    "dyncall_config.h", 
    "dyncall_macros.h", 
    "dyncall_signature.h", 
    "dyncall_types.h", 
    "dyncall_value.h", 
    "dynload.h"
];

#if AT_COMPILE_TIME {
    #run,stallable {
        set_build_options_dc(.{do_output=false});
        options := get_build_options();
        args := options.compile_time_command_line;
        if !generate_bindings(args, options.minimum_os_version) {
            compiler_set_workspace_status(.FAILED);
        }
    }
} else {
    #import "System";

    main :: () {
        set_working_directory(path_strip_filename(get_path_of_running_executable()));
        if !generate_bindings(get_command_line_arguments(), #run get_build_options().minimum_os_version) {
            exit(1);
        }
    }
}

generate_bindings :: (args: [] string, minimum_os_version: type_of(Build_Options.minimum_os_version)) -> bool {
    os_target  := OS;
    cpu_target := CPU;

    // target_android := array_find(args, "-android");
    // target_arm     := array_find(args, "-arm64");
    // compile        := array_find(args, "-compile");
    // compile_debug  := array_find(args, "-debug");
    // if target_android {
    //     os_target = .ANDROID;
    // }
    // if target_arm {
    //     cpu_target = .ARM64;
    // }

    lib_directory: string;
    if os_target == {
        case .WINDOWS;
            lib_directory = "windows";
        // case .LINUX;
        //     lib_directory = "linux";
        // case .MACOS;
        //     // @Incomplete: do Arm64
        //     lib_directory = "macos";
        // case .ANDROID;
        //     lib_directory = ifx cpu_target == .X64 then "android/x64" else "android/arm64";
        // case .PS5;
        //     lib_directory = "ps5";
        case;
            assert(false);
    }

    // if compile {
    //     source_file := tprint("%/dyncall.c", SOURCE_PATH);

    //     make_directory_if_it_does_not_exist(lib_directory, recursive = true);
    //     lib_path := tprint("%/%", lib_directory, LIB_BASE_NAME);
    //     extra: [] string;
    //     if os_target == {
    //         case .MACOS;
    //             // @Incomplete: do Arm64
    //             macos_version_arg := tprint("-mmacos-version-min=%.%", minimum_os_version.major, minimum_os_version.minor);
    //             extra = .[macos_version_arg];
    //         case .ANDROID;
    //             _, target_triple_with_sdk := get_android_target_triple(cpu_target);
    //             extra = .["-target", target_triple_with_sdk];
    //     }

    //     success := true;
    //     if os_target != .PS5 {
    //         success &&= build_cpp_dynamic_lib(lib_path, source_file, target = os_target, debug = compile_debug, extra = extra);
    //     }
    //     success &&= build_cpp_static_lib(lib_path, source_file, target = os_target, debug = compile_debug, extra = extra);

    //     if !success     return false;
    // }

    options: Generate_Bindings_Options;
    options.os = os_target;
    options.cpu = cpu_target;
    {
        using options;

        array_add(*libpaths, lib_directory);
        array_add(*libnames, "dyncall_s");
        array_add(*libnames, "dyncallback_s");
        array_add(*libnames, "dynload_s");
        
        for INCLUDE_FILES array_add(*source_files, tprint("%/%", SOURCE_PATH, it));
        // array_add(*typedef_prefixes_to_unwrap, "stbi_");


        generate_library_declarations = false;
        footer = tprint(FOOTER_TEMPLATE, "dyncall_s", "dyncallback_s", "dynload_s");

        auto_detect_enum_prefixes = true;
        log_stripped_declarations = true;
        generate_compile_time_struct_checks = false;
    }

    output_filename := "bindings.jai";
    return generate_bindings(options, output_filename);
}

FOOTER_TEMPLATE :: #string END

#if OS == .WINDOWS {
    %1 :: #library,no_dll "windows/%1";
    %2 :: #library,no_dll "windows/%2";
    %3 :: #library,no_dll "windows/%3";
} else #if OS == .LINUX {
    %1 :: #library,no_dll "linux/%1";
    %2 :: #library,no_dll "linux/%2";
    %3 :: #library,no_dll "linux/%3";
} else #if OS == .MACOS {
    %1 :: #library,no_dll "macos/%1";
    %2 :: #library,no_dll "macos/%2";
    %3 :: #library,no_dll "macos/%3";
} else #if OS == .ANDROID {
    #if CPU == .X64 {
        %1 :: #library,no_dll "android/x64/%1";
        %2 :: #library,no_dll "android/x64/%2";
        %3 :: #library,no_dll "android/x64/%3";
    } else #if CPU == .ARM64 {
        %1 :: #library,no_dll "android/arm64/%1";
        %2 :: #library,no_dll "android/arm64/%2";
        %3 :: #library,no_dll "android/arm64/%3";
    }
} else #if OS == .PS5 {
    %1 :: #library,no_dll "ps5/%1";
    %2 :: #library,no_dll "ps5/%2";
    %3 :: #library,no_dll "ps5/%3";
} else {
    #assert false;
}

END

#import "Toolchains/Android";
#import "Basic";
#import "BuildCpp";
#import "Bindings_Generator";
#import "Compiler";
#import "File";
