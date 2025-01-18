#assert OS == .WINDOWS; 

#import "Basic";

#load "bindings.jai";
#load "dcaggr.jai";

// set to true to log a bunch of stuff
// this is not currently a module parameter since I plan to remove the frivolous debug logging once things have solidified more
DEBUG :: false; 

#module_parameters () (ENABLE_COERCIONS: enum { DISABLED :: 0; MINIMAL; EXTENDED; } = .MINIMAL);

// TODO: need to have option to pass arguments and return_values by [] *void instead of [] Any.
//       also, maybe an option to just pass a single pointer or [] u8 to buffer of all args 

// ==========  Type Coercions ==========

/*
    This module provides some capabilities to perform type coercions on arguments passed to dyncall.
    The most basic capabilites are included in coercion_minimal.jai, 
        but if you would like to have access to more extensive and configurable coercion settings, 
        then you can import that functionality from my Data_Packer module.
    But of course I realize that most people will probably not want all that, 
        so by default you only get the minimal version.
    You also have the option to enable type coercions altogether, 
*/

#if ENABLE_COERCIONS == {
  case .MINIMAL;
    #load "coercion_minimal.jai";
  case .EXTENDED;
    #load "coercion.jai";
}

// This procedure is the same for either the minimal or extended type coercion.
// The additional parameters settings required by the extended type coercion are set in the context.
maybe_coerce :: (dst: Any, src: Any) -> bool {
    if src.type == dst.type {
        memcpy(dst.value_pointer, src.value_pointer, src.type.runtime_size);
        return true;
    }
    
    #if ENABLE_COERCIONS {
        return coerce(dst, src);
    } else {
        log("Error: argument type '%' does not match expected type '%' and type coercions are not enabled.", as_type(src.type), T);
        return false;
    }
}

// ========== Additional Bindings ==========

// Some bindings which the bindings generator missed. Maybe due to being #defines for character literals?

DC_SIGCHAR_VOID         :: #char "v";
DC_SIGCHAR_BOOL         :: #char "B";
DC_SIGCHAR_CHAR         :: #char "c";
DC_SIGCHAR_UCHAR        :: #char "C";
DC_SIGCHAR_SHORT        :: #char "s";
DC_SIGCHAR_USHORT       :: #char "S";
DC_SIGCHAR_INT          :: #char "i";
DC_SIGCHAR_UINT         :: #char "I";
DC_SIGCHAR_LONG         :: #char "j";
DC_SIGCHAR_ULONG        :: #char "J";
DC_SIGCHAR_LONGLONG     :: #char "l";
DC_SIGCHAR_ULONGLONG    :: #char "L";
DC_SIGCHAR_FLOAT        :: #char "f";
DC_SIGCHAR_DOUBLE       :: #char "d";
DC_SIGCHAR_POINTER      :: #char "p"; /* also used for arrays, as such args decay to ptrs */
DC_SIGCHAR_STRING       :: #char "Z"; /* in theory same as 'p', but convenient to disambiguate */
DC_SIGCHAR_AGGREGATE    :: #char "A"; /* aggregate (struct/union described out-of-band via DCaggr) */
DC_SIGCHAR_ENDARG       :: #char ")";

/* calling convention and mode signatures */

DC_SIGCHAR_CC_PREFIX           :: #char "_"; /* announces next char to be one of the below calling convention mode chars */
DC_SIGCHAR_CC_DEFAULT          :: #char ":"; /* default calling conv (platform native) */
DC_SIGCHAR_CC_THISCALL         :: #char "*"; /* C++ this calls (platform native) */
DC_SIGCHAR_CC_ELLIPSIS         :: #char "e";
DC_SIGCHAR_CC_ELLIPSIS_VARARGS :: #char ".";
DC_SIGCHAR_CC_CDECL            :: #char "c"; /* x86 specific */
DC_SIGCHAR_CC_STDCALL          :: #char "s"; /* x86 specific */
DC_SIGCHAR_CC_FASTCALL_MS      :: #char "F"; /* x86 specific */
DC_SIGCHAR_CC_FASTCALL_GNU     :: #char "f"; /* x86 specific */
DC_SIGCHAR_CC_THISCALL_MS      :: #char "+"; /* x86 specific, MS C++ this calls */
DC_SIGCHAR_CC_THISCALL_GNU     :: #char "#"; /* x86 specific, GNU C++ this calls are cdecl, but keep specific sig char for clarity */
DC_SIGCHAR_CC_ARM_ARM          :: #char "A";
DC_SIGCHAR_CC_ARM_THUMB        :: #char "a";
DC_SIGCHAR_CC_SYSCALL          :: #char "$";

// some sanity checks for sizes of types
// I suppose these may be different for 32 bit if that is added in the future
#assert(size_of(DCchar    ) == 1);
#assert(size_of(DCshort   ) == 2);
#assert(size_of(DCint     ) == 4);
#assert(size_of(DClonglong) == 8);
#assert(size_of(DCfloat   ) == 4);
#assert(size_of(DCdouble  ) == 8);

// custom aliases for explicitly sized numeric types
// arguably, we don't really need these because the DC types are already typedefs of standard Jai types
// but the ones for the procedures are actually kind of nice and it felt wierd not to do the types themselvs to match
// maybe I will remove these in the future. I'm still somewhat considering trying to implement a different backend with libffi.

DCint8        :: DCchar;
DCint16       :: DCshort;
DCint32       :: DCint;
DCint64       :: DClonglong;

DCfloat32     :: DCfloat;
DCfloat64     :: DCdouble;

// dcArgX procedures
dcArgInt8     :: dcArgChar;
dcArgInt16    :: dcArgShort;
dcArgInt32    :: dcArgInt;
dcArgInt64    :: dcArgLongLong;

dcArgFloat32  :: dcArgFloat;
dcArgFloat64  :: dcArgDouble;

// dcCallX procedures
dcCallInt8    :: dcCallChar;
dcCallInt16   :: dcCallShort;
dcCallInt32   :: dcCallInt;
dcCallInt64   :: dcCallLongLong;

dcCallFloat32 :: dcCallFloat;
dcCallFloat64 :: dcCallDouble;

// ========== Real Stuff ==========

// TODO: decent function to wrap both C and Jai calls.
// DYNAMIC_CALL :: (proc: Any, args: ..Any) -> [] Any {
//     if (ti_proc.procedure_flags & .IS_C_CALL) {
        
//         return Any.[];
//     }
// }



/*
    Jai calling convention notes
    
    Jai calls totally don't work at all with the x64 backend!
    So for the mean time your choices are to use the LLVM backend, where Jai uses the C calling convention behind the scenes, or you can wrap your Jai procedures with #c_call wrappers
    If Jon ever decides to change things in the LLVM backend such that it no longer uses the C calling convention and breaks this entire module, then I will most likely go ahead and write a little macro that will wrap your Jai procedures in #c_call proceudres that take the additional context pointer and just fix it that way.
    Really, I ought to go ahead and do that anyways so that this module actually works in the x64 backend...        TODO!
    
    If we de-sugared Jai calls into C calls, they would look something like this:
        void procedure(Context* context, ..T arguments, ..void* return_values);
    
    The context pointer is passed as the first argument.
    Then we pass all normal arguments.
    Lastly, we pass pointers to all return values.
    
    Passing Arguments:
        Structs are always passed by pointer in Jai calls.
        All other types are passed by value, including all array types.
    
    Footnotes: 
        For #c_call procedures, we actually do pass structs by value.
        Currently, Jai calls don't work on the x64 backend. 
            I will have to look into fixing this, 
            but it may not be trivial if the calling convention 
            is meaningfully different than C's.
        
    
    
    
*/


/*
    The setup and execution of the dyncall VM have been split up here so that one can defer calling the VM after pushing args.
    I am testing this with a Go-style defer that works at function scope instead of block scope, which should be a good test.
    
    NOTE: The VM returned by setup_vm_jai will need to be freed manually!
    
    This has me thinking that we may want to have some better data structure 
    that wraps the dyncall VM pointer and holds the procedure pointer and type info
    so that the user does not have to manage those separately.
    
    Doing the setup and execution of a dyncall separately comes with a lot of extra considerations.
    And currently, I don't have anything here that accounts for those considerations.
    The plan is that doing the Go Defer stuff will help me to develop the proper affordances, and a nice interface to do this kind of thing.
    But at the moment, it's just 'user beware'.
    
    It may be problematic to even push arguments here, since we have to push the context first, and that's maybe the most complicated part of all.
    One solution would be to create a context in temp storage or on the heap that we get a pointer to here, and then don't fill in until we execute the call.
    But I'm not sure if that's the most elegant solution.
    Perhaps we can smooth over some of the complications by just making a good wrapper struct around *DCCallVM.
    
    LATER...
    After having used dyncall for a while in Lead Sheets, 
    I've realized that there's really not much point having most of these higher-level procedures
    since most non-trivial use cases will actually want to manage the vm on their own.
    But, since these procedures are still useful for doing basic testing and because they may be 
    useful as a reference for those who have not used dyncall before, I'm leaving them in the module.
*/


setup_vm_jai :: (proc: Any, arguments: [] Any) -> *DCCallVM {
    assert(proc.type.type == .PROCEDURE, "proc.type.type was %!", proc.type.type);
    ti_proc := proc.type.(*Type_Info_Procedure);
    
    if (ti_proc.procedure_flags & .IS_C_CALL) {
        log("provided procedure '%' is not a C call!\n", proc);
        return null;
    }
    
    vm := dcNewCallVM(2048); 
    dcMode(vm, DC_CALL_C_DEFAULT);
    dcReset(vm);
    
    ok := false;
    defer if !ok  dcFree(vm);
    
    if !(ti_proc.procedure_flags & .HAS_NO_CONTEXT) {
        dcArgPointer(vm, *context);
    }
    
    if !push_arguments(vm, ti_proc.argument_types, arguments, jai_call = true)  return null;
    
    ok = true;
    return vm;
}

exec_vm_jai :: (vm: *DCCallVM, proc: Any, return_values: [] Any) -> bool {
    assert(proc.type.type == .PROCEDURE, "proc.type.type was %!", proc.type.type);
    ti_proc := proc.type.(*Type_Info_Procedure);
    
    // we assert that return types are as they should be, since user should have done their own type checking
    // but we still want to catch those errors in case they don't
    // but it's still slow, so I dunno, maybe we wrap this in a debug flag later...
    assert(ti_proc.return_types.count == return_values.count);
    for return_values {
        assert(it.type == ti_proc.return_types[it_index]);
        assert(it.value_pointer != null);
        dcArgPointer(vm, it.value_pointer);
    }
    
    dcCallVoid(vm, proc.value_pointer.(*DCpointer).*);
    
    return true;
}

// this is basically the same as DYNAMIC_JAI_CALL except that we provide 'return_values'
setup_and_exec_vm_jai :: inline (proc: Any, arguments: [] Any, return_values: [] Any) -> bool {
    vm := setup_vm_jai(proc, arguments);
    if !vm  return false;
    defer dcFree(vm);
        
    ok := exec_vm_jai(vm, proc, return_values);
    return ok;
}


/*
    This is really a convenience for only the most entry-level use case, and for general testing purposes.
    For most things, one will really want to use the more granular procedures (setup_vm and exec_vm).
    Also, this will just stuff the return values into temp storage, 
        so if you want to actually catch returns into existing variables
        then you will need use the setup_vm and exec_vm procs instead.
*/
DYNAMIC_JAI_CALL :: inline (proc: Any, arguments: ..Any) -> ([] Any, bool) {
    vm := setup_vm_jai(proc, arguments);
    if !vm  return Any.[], false;
    defer dcFree(vm);
    
    ti_proc := proc.type.(*Type_Info_Procedure) ;
    return_values := NewArray(ti_proc.return_types.count, Any,, temp);
    for ti_proc.return_types {
        ptr := alloc(it.runtime_size,, temp);
        return_values[it_index] = Any.{ it, ptr };
    }
    
    ok := exec_vm_jai(vm, proc, return_values);
    return return_values, ok;
}



// NOTE: The reason this is not split up more like DYNAMIC_JAI_CALL is because of how dcBeginCallAggr works, and the fact that we may need to 
//       AND because even though the aforementioned issues are defintely solvable, I didn't feel like putting in the effort when I know very few people will want to use those procedures for C calls.
//       because if your doing dynamic C calls for non-trivial reasons in the first place, you probably don't want the high-level convience procedure and will just do it right.
DYNAMIC_C_CALL :: (proc: Any, args: ..Any) -> Any {
    if proc.type.type != .PROCEDURE  return Any.{};
    ti_proc := proc.type.(*Type_Info_Procedure);
    
    if !(ti_proc.procedure_flags & .IS_C_CALL) {
        log("provided procedure '%' is not a C call!\n", proc);
        return Any.{};
    }
    
    assert(ti_proc.return_types.count <= 1); // sanity check for c calls
    
    // Begin the actual call
    
    vm := dcNewCallVM(2048); // big ass safety margin?
    dcMode(vm, DC_CALL_C_DEFAULT);
    dcReset(vm);
    defer dcFree(vm);
    
    // For a C call, we need to get the return type up top and maybe start an aggr call
    return_type := ifx ti_proc.return_types then ti_proc.return_types[0] else type_info(void);
    // If the return type is an array type, we want to pass the struct equivalent for the array type rather than the array type itself 
    return_type_for_aggr := return_type;
    return_type_is_aggr  := false;
    
    if return_type.type == .STRUCT {
        return_type_is_aggr = true;
    }
    else if return_type.type == .ARRAY {
        ti_array := return_type.(*Type_Info_Array);
        if ti_array.array_type == {
          case .VIEW;
            return_type_for_aggr = type_info(Array_View_64);
            return_type_is_aggr  = true;
          case .RESIZABLE;
            return_type_for_aggr = type_info(Resizable_Array);
            return_type_is_aggr  = true;
        }
    }
    
    if return_type_is_aggr {
        ag := find_or_make_and_register_DCaggr(return_type_for_aggr);
        dcBeginCallAggr(vm, ag);
    }
    
    if !push_arguments(vm, ti_proc.argument_types, args)  return Any.{};
    
    // For now, we will allocate the space for the result in temp storage and the user will get back an any with the return value
    // TODO: allow user to pass allocator to use... but maybe not in context, since temp will probably be the main goto choice
    // also need to consider allowing user to pass a pointer for result that will be used if type is dc_aggr, maybe just by passing optional []u8? (so we can check size)
    return_value: Any;
    if return_type.runtime_size {
        return_value = Any.{ return_type, alloc(return_type.runtime_size,, temp) };
    }
    
    proc_ptr := proc.value_pointer.(**void).*;
    
    if return_type.type == {
      case .VOID;
        dcCallVoid(vm, xx proc_ptr);
        
      case .POINTER;
        dcCallPointer(vm, xx proc_ptr);
        
      case .ENUM; #through;
      case .BOOL; #through;
      case .INTEGER;
        if return_type.runtime_size == {
            case 1; return_value.value_pointer.(*DCint8 ).* = dcCallInt8 (vm, xx proc_ptr); 
            case 2; return_value.value_pointer.(*DCint16).* = dcCallInt16(vm, xx proc_ptr); 
            case 4; return_value.value_pointer.(*DCint32).* = dcCallInt32(vm, xx proc_ptr); 
            case 8; return_value.value_pointer.(*DCint64).* = dcCallInt64(vm, xx proc_ptr); 
            case;
                log("invalid integer size!\n");
                return Any.{};
        }
        
      case .FLOAT;
        if return_type.runtime_size == {
          case 4; return_value.value_pointer.(*DCfloat32).* = dcCallFloat32(vm, xx proc_ptr); 
          case 8; return_value.value_pointer.(*DCfloat64).* = dcCallFloat64(vm, xx proc_ptr); 
           case;
            log("invalid float size!\n");
            return Any.{};
        }
        
      case .ARRAY;
        ti_array := return_type.(*Type_Info_Array);
        if ti_array.array_type == .FIXED {
            log("error: we should never get fixed array as return type!\n");
            return Any.{};
        }
        #through;
        
      case .STRUCT;
        ag := find_or_make_and_register_DCaggr(return_type_for_aggr);
        if !ag then log("unable to find DCaggr for struct when calling proc!\n");
        
        dcCallAggr(vm, xx proc_ptr, ag, xx return_value.value_pointer);
        error := dcGetError(vm);
        if error  log("error: %\n", error);
    }
    
    return return_value;
}

// ========== Type Checking ==========

// These procs take Any's for the arguments since that is the common case.
// I will probably add versions taking only the types soon, since that is also useful.

// user should call this before calling DYNAMIC_X_CALL or setup_vm_x procs 
//     if they want to verify that argument types exactly match
typecheck_arguments :: (ti_proc: *Type_Info_Procedure, arguments: ..Any) -> bool {
    if ti_proc.argument_types.count != arguments.count {
        log("argument count did not match. % != %", ti_proc.argument_types.count, arguments.count);
        return false;
    }
    
    for ti_proc.argument_types 
        if it != arguments[it_index].type {
            log("argument % did not match. % != %", it_index, as_type(it), as_type(arguments[it_index].type));
            return false;
        }
    
    return true;
}

// user should call this before calling DYNAMIC_X_CALL or setup_vm_x procs 
//     if they want to verify that argument types exactly match
typecheck_return_values :: (ti_proc: *Type_Info_Procedure, return_values: ..Any) -> bool {
    if ti_proc.return_types.count != return_values.count 
        return false;
    
    for ti_proc.return_types 
        if it != return_values[it_index].type{
            log("return value % did not match. % != %", it_index, as_type(it), as_type(arguments[it_index].type));
            return false;
        }
    
    return true;
}

push_any_argument :: inline (vm: *DCCallVM, any: Any, jai_call := false) -> bool {
    return push_argument(vm, any.type, any.value_pointer, jai_call);
}

push_argument :: (vm: *DCCallVM, type: *Type_Info, value_pointer: *void, jai_call := false) -> bool {
    if type.type == {
      case .POINTER;
        dcArgPointer(vm, value_pointer.(*DCpointer).*); 
        
      case .ENUM; #through;
      case .BOOL; #through;
      case .INTEGER;
        if type.runtime_size == {
          case 1; dcArgInt8 (vm, value_pointer.st(*DCint8 ).*); 
          case 2; dcArgInt16(vm, value_pointer.st(*DCint16).*); 
          case 4; dcArgInt32(vm, value_pointer.st(*DCint32).*); 
          case 8; dcArgInt64(vm, value_pointer.st(*DCint64).*); 
          case;   assert(false, "Invalid integer size!");
        }
        
      case .FLOAT;
        if type.runtime_size == {
          case 4; dcArgFloat32(vm, value_pointer.(*DCfloat32).*); 
          case 8; dcArgFloat64(vm, value_pointer.(*DCfloat32).*); 
          case;   assert(false, "Invalid float size!");
        }
        
      case .STRING;
        ag := find_or_make_and_register_DCaggr(type_info(Array_View_64));
        if !ag  return false;
        dcArgAggr(vm, ag, value_pointer);  
        
      case .STRUCT;
        if jai_call {
            dcArgPointer(vm, value_pointer);
        } else {
            ag := find_or_make_and_register_DCaggr(xx type);
            if !ag  return false;
            dcArgAggr(vm, ag, value_pointer);  
        }
        
      case .ARRAY;
        ti_array := type.(*Type_Info_Array);
        if ti_array.array_type == {
          case .VIEW;
            ag := find_or_make_and_register_DCaggr(type_info(Array_View_64));
            if !ag  return false;
            dcArgAggr(vm, ag, value_pointer);  
            
          case .RESIZABLE;
            ag := find_or_make_and_register_DCaggr(type_info(Resizable_Array));
            if !ag  return false;
            dcArgAggr(vm, ag, value_pointer);  
            
          case;
            if !jai_call {
                log("Error: cannot pass a fixed array to a #c_call procedure!\n");
                return false;
            }
            
            ag := find_or_make_and_register_DCaggr(xx ti_array);
            if !ag  return false;
            dcArgAggr(vm, ag, value_pointer);  
        }
        
      case;
        log("Error: unable to push argument of type %\n", as_type(type));
        return false;
    }
    
    return true;
}

check_arguments :: (ti_proc: *Type_Info_Procedure, args: [] Any) -> (u64, bool) {
    if ti_proc.argument_types.count != args.count {
        log("provided incorrect number of arguments for procedure!\n");
        return 0, false;
    }
        
    total_stack_needed: u64;
    for ti_proc.argument_types {
        if it.type == .STRUCT {
            if !find_or_make_and_register_DCaggr(xx it) {
                log("unable to register DCaggr for struct!\n");
            }
        }
        total_stack_needed += it.runtime_size.(u64);
    }
    return total_stack_needed, true;
}

// the arg_types array is provided for the sake of doing type checking and type coercions, based on the argument_types array in a Type_Info_Procedure
push_arguments :: (vm: *DCCallVM, arg_types: []*Type_Info, args: []Any, jai_call := false) -> (bool) {
    for arg_type: arg_types {
        arg_any := args[it_index];
        
        if arg_type.type == {
          case .POINTER;
        //     #if DEBUG { log("dcArgPointer\n"); }
            dcArgPointer(vm, arg_any.value_pointer.(*DCpointer).*); 
            
          case .ENUM; #through;
          case .BOOL; #through;
          case .INTEGER;
            if arg_type.runtime_size == {
              case 1; 
                val: DCint8;
                if !maybe_coerce(val, arg_any)  return false;
                dcArgInt8(vm, val); 
                
              case 2; 
                val: DCint16;
                if !maybe_coerce(val, arg_any)  return false;
                dcArgInt16(vm, val); 
                
              case 4; 
                val: DCint32;
                if !maybe_coerce(val, arg_any)  return false;
                dcArgInt32(vm, val); 
                
              case 8; 
                val: DCint64;
                if !maybe_coerce(val, arg_any)  return false;
                dcArgInt64(vm, val); 
                
              case;
                log("invalid integer size!\n");
                return false;
            }
            
          case .FLOAT;
            if arg_type.runtime_size == {
              case 4; 
                val: DCfloat32;
                if !maybe_coerce(val, arg_any)  return false;
                dcArgFloat32(vm, val); 
                
              case 8; 
                val: DCfloat64;
                if !maybe_coerce(val, arg_any)  return false;
                dcArgFloat64(vm, val); 
                
              case;
                log("invalid float size!\n");
                return false;
            }
            
          case .STRUCT;
            if jai_call {
                dcArgPointer(vm, arg_any.value_pointer); 
            } else {
                ag := find_or_make_and_register_DCaggr(xx arg_type);
                if !ag  return false;
                dcArgAggr(vm, ag, arg_any.value_pointer);
            }
            
          case .ARRAY;
            ti_array := arg_type.(*Type_Info_Array);
            if ti_array.array_type == {
              case .VIEW;
                ag := find_or_make_and_register_DCaggr(type_info(Array_View_64));
                if !ag  return false;
                dcArgAggr(vm, ag, arg_any.value_pointer);
                
              case .RESIZABLE;
                ag := find_or_make_and_register_DCaggr(type_info(Resizable_Array));
                if !ag  return false;
                dcArgAggr(vm, ag, arg_any.value_pointer);
                
              case;
                if !jai_call {
                    log("Error: cannot pass a fixed array to a #c_call procedure!\n");
                    return false;
                }
                
                ag := find_or_make_and_register_DCaggr(xx ti_array);
                if !ag  return false;
                dcArgAggr(vm, ag, arg_any.value_pointer);
            }
        }
    }
    
    return true;
}

// a version of push_arguments where each arg is *void instead of Any, meaning no type checking will be done
// and of course, no type coercion can be done since we don't know what the source type is for each argument
push_arguments_nocheck :: (vm: *DCCallVM, arg_types: [] *Type_Info, args: [] *void, jai_call := false) -> (bool) {
    assert(arg_types.count == args.count);
    for arg_type: arg_types {
        arg_ptr := args[it_index];
        
        if arg_type.type == {
          case .POINTER;
            dcArgPointer(vm, arg_ptr.(*DCpointer).*); 
            
          case .ENUM; #through;
          case .BOOL; #through;
          case .INTEGER;
            if arg_type.runtime_size == {
              case 1; dcArgInt8 (vm, arg_ptr.(*DCint8 )); 
              case 2; dcArgInt16(vm, arg_ptr.(*DCint16)); 
              case 4; dcArgInt32(vm, arg_ptr.(*DCint32)); 
              case 8; dcArgInt64(vm, arg_ptr.(*DCint64)); 
              case;
                log("invalid integer size!\n");
                return false;
            }
            
          case .FLOAT;
            if arg_type.runtime_size == {
              case 4; dcArgFloat32(vm, arg_ptr.(*DCfloat32)); 
              case 8; dcArgFloat64(vm, arg_ptr.(*DCfloat32)); 
              case;
                log("invalid float size!\n");
                return false;
            }
            
          case .STRUCT;
            if jai_call {
                dcArgPointer(vm, arg_ptr);   
            } else {
                ag := find_or_make_and_register_DCaggr(xx arg_type);
                if !ag  return false;
                dcArgAggr(vm, ag, arg_ptr);  
            }
            
          case .ARRAY;
            ti_array := arg_type.(*Type_Info_Array);
            if ti_array.array_type == {
              case .VIEW;
                ag := find_or_make_and_register_DCaggr(type_info(Array_View_64));
                if !ag  return false;
                dcArgAggr(vm, ag, arg_ptr);  
                
              case .RESIZABLE;
                ag := find_or_make_and_register_DCaggr(type_info(Resizable_Array));
                if !ag  return false;
                dcArgAggr(vm, ag, arg_ptr);  
                
              case;
                if !jai_call {
                    log("Error: cannot pass a fixed array to a #c_call procedure!\n");
                    return false;
                }
                
                ag := find_or_make_and_register_DCaggr(xx ti_array);
                if !ag  return false;
                dcArgAggr(vm, ag, arg_ptr);  
            }
        }
    }
    
    return true;
}


// TODO: maybe move this to some utils file if we do keep it around
as_type :: inline (ti: *Type_Info) -> Type {
    return (*ti).(*Type).*;
}


