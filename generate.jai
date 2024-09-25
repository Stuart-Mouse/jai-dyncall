AT_COMPILE_TIME :: true;

SOURCE_PATH :: "source";
LIB_BASE_NAME :: "dyncall";

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

LIB_FILES :: string.[
    "libdyncall_s.lib", 
    "libdyncallback_s.lib", 
    "libdynload_s.lib"
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
        array_add(*libnames, "libdyncall_s");
        array_add(*libnames, "libdyncallback_s");
        array_add(*libnames, "libdynload_s");
        
        for INCLUDE_FILES array_add(*source_files, tprint("%/%", SOURCE_PATH, it));
        // array_add(*typedef_prefixes_to_unwrap, "stbi_");


        generate_library_declarations = false;
        footer = tprint(FOOTER_TEMPLATE, LIB_BASE_NAME);

        auto_detect_enum_prefixes = true;
        log_stripped_declarations = false;
        generate_compile_time_struct_checks = false;
    }

    output_filename := "bindings.jai";
    return generate_bindings(options, output_filename);
}

FOOTER_TEMPLATE :: #string END

#if OS == .WINDOWS {
    %1 :: #library "windows/%1";
} else #if OS == .LINUX {
    %1 :: #library "linux/%1";
} else #if OS == .MACOS {
    %1 :: #library "macos/%1";
} else #if OS == .ANDROID {
    #if CPU == .X64 {
        %1 :: #library "android/x64/%1";
    } else #if CPU == .ARM64 {
        %1 :: #library "android/arm64/%1";
    }
} else #if OS == .PS5 {
    %1 :: #library "ps5/%1";
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
