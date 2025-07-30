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

    lib_directory: string;
    if os_target == {
        case .WINDOWS;
            lib_directory = "windows";
        case;
            assert(false);
    }
    
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
        
        generate_library_declarations = false;
        footer = tprint(FOOTER_TEMPLATE, "dyncall_s", "dyncallback_s", "dynload_s");
        
        auto_detect_enum_prefixes = true;
        log_stripped_declarations = true;
        generate_compile_time_struct_checks = false;
    }
    
    output_filename := "bindings.jai";
    return generate_bindings(options, output_filename);
}

FOOTER_TEMPLATE :: #string __JAI
#if OS == .WINDOWS {
    %1 :: #library,no_dll "windows/%1";
    %2 :: #library,no_dll "windows/%2";
    %3 :: #library,no_dll "windows/%3";
} else {
    #assert false;
}
__JAI

#import "Toolchains/Android";
#import "Basic";
#import "BuildCpp";
#import "Bindings_Generator";
#import "Compiler";
#import "File";
