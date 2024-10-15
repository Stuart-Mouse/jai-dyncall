#load "bindings.jai";

#if OS != .WINDOWS {
    #assert false;
}

DEBUG :: false; // set to true to log a bunch of stuff

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

/* calling convention / mode signatures */

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


/*
    TODO: 
    
    add handling for fixed size arrays as parameters in Jai calls
    
    add option to coerce types
        this will create temp copies of values, but should be able to keep it all on the stack
            so long as its only for simple things like int/float/bool whatnot
        we could possibly do it for structs with a remap_data, but that's getting very slow, and proabbyl won't be useful to almost anyone
            just creating Jaiva script at that point...
        create array views from fixed arrays and pass those?
            if we do an array literal then that gets passed as a fixed size array in Any
    
*/

#import "Basic";

// TODO: decent function to wrap both C and Jai calls.
// DYNAMIC_CALL :: (proc: Any, args: ..Any) -> [] Any {
//     if (ti_proc.procedure_flags & .IS_C_CALL) {
        
//         return Any.[];
//     }
// }



/*
    Jai calling convention notes
    
    If we de-sugared Jai calls into C calls, they would look something like this:
        void procedure(Context* context, ..Any arguments, ..void* return_values);
    
    The context pointer is passed as the first argument.
    Then we pass all normal arguments.
    Lastly, we pass pointers to all return values.
    
    Passing Arguments:
        Structs are always passed by pointer in Jai calls.
        All other types are passed by value, including all array types.
    
    Footnotes: 
        For #c_call procedures, we actually do pass structs by value.
        This should work with the x64 backend, but I have only tested with LLVM so far.
*/



/*
    The setup and execution of the dyncall VM have been split up here so that one can defer calling the VM after pushin args.
    I am testing this with a Go-style defer that works at function scope instead of block scope, which should be a good test.
    
    NOTE: The VM returned by setup_vm_jai will need to be freed manually!
    
    This has me thinking that we may want to have some better data structure 
    that wraps the dyncall VM pointer and holds the procedure pointer and type info
    so that the user does not have to manage those separately.
*/

setup_vm_jai :: (proc: Any, args: ..Any) -> *DCCallVM {
    assert(proc.type.type == .PROCEDURE, "proc.type.type was %!", proc.type.type);
    ti_proc := cast(*Type_Info_Procedure) proc.type;
    
    if (ti_proc.procedure_flags & .IS_C_CALL) {
        log("provided procedure '%' is not a C call!\n", proc);
        return null;
    }
    
    total_stack_needed, ok := _check_arguments(ti_proc, ..args);
    
    vm := dcNewCallVM(total_stack_needed + 1024); // big ass safety margin?
    dcMode(vm, DC_CALL_C_DEFAULT);
    dcReset(vm);
    
    ok = false;
    defer if !ok  dcFree(vm);
    
    if !(ti_proc.procedure_flags & .HAS_NO_CONTEXT) {
        dcArgPointer(vm, *context);
    }
    
    if !_push_arguments(vm, ..args, jai_call = true)  return null;
    
    ok = true;
    return vm;
}

// We just assume that this will never fail right now. 
// Only error we could have is memory allocation, or logic error because vm was not setup correctly. But that will probably just cause a crash anyhow, so I won't bother :)
exec_vm_jai :: (vm: *DCCallVM, proc: Any, args: ..Any) -> [] Any {
    assert(proc.type.type == .PROCEDURE, "proc.type.type was %!", proc.type.type);
    ti_proc := cast(*Type_Info_Procedure) proc.type;
    
    // push pointers for return values
    return_values := NewArray(ti_proc.return_types.count, Any,, temp);
    
    for ti_proc.return_types {
        ptr := alloc(it.runtime_size,, temp);
        dcArgPointer(vm, ptr);
        return_values[it_index] = Any.{ it, ptr };
    }
    
    proc_ptr := (cast(**void)proc.value_pointer).*;
    dcCallVoid(vm, xx proc_ptr);
    
    return return_values;
}

DYNAMIC_JAI_CALL :: inline (proc: Any, args: ..Any) -> [] Any {
    vm := setup_vm_jai(proc, ..args);
    if !vm  return Any.[];
    defer dcFree(vm);
    return exec_vm_jai(vm, proc, ..args);
}





// TODO: split this up like DYNAMIC_JAI_CALL
DYNAMIC_C_CALL :: (proc: Any, args: ..Any) -> Any {
    if proc.type.type != .PROCEDURE  return Any.{};
    ti_proc := cast(*Type_Info_Procedure) proc.type;
    
    if !(ti_proc.procedure_flags & .IS_C_CALL) {
        log("provided procedure '%' is not a C call!\n", proc);
        return Any.{};
    }
    
    total_stack_needed, ok := _check_arguments(ti_proc, ..args);
    
    assert(ti_proc.return_types.count <= 1); // sanity check for c calls
    
    // Begin the actual call
    
    vm := dcNewCallVM(total_stack_needed + 1024); // big ass safety margin?
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
        ti_array := cast(*Type_Info_Array) return_type;
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
        #if DEBUG log("dcBeginCallAggr(%)\n", ag);
        dcBeginCallAggr(vm, ag);
    }
    
    if !_push_arguments(vm, ..args)  return Any.{};
    
    // For now, we will allocate the space for the result in temp storage and the user will get back an any with the return value
    // TODO: allow user to pass allocator to use... but maybe not in context, since temp will probably be the main goto choice
    // also need to consider allowing user to pass a pointer for result that will be used if type is dc_aggr, maybe just by passing optional []u8? (so we can check size)
    return_value: Any;
    if return_type.runtime_size {
        return_value = Any.{ return_type, alloc(return_type.runtime_size,, temp) };
    }
    
    // macro to help us just catch the return value directly instead of requiring a copy
    assign :: inline (dst: *void, value: $T) {
        (cast(*T)dst).* = value;
    }
    
    proc_ptr := (cast(**void)proc.value_pointer).*;
    
    if return_type.type == {
      case .VOID;
        #if DEBUG log("dcCallVoid\n");
        dcCallVoid(vm, xx proc_ptr);
        
      case .POINTER;
        #if DEBUG log("dcCallPointer\n");
        dcCallPointer(vm, xx proc_ptr);
        
      case .ENUM; #through;
      case .BOOL; #through;
      case .INTEGER;
        if return_type.runtime_size == {
            case 1; 
                #if DEBUG log("dcCallChar\n");
                assign(return_value.value_pointer, dcCallChar    (vm, xx proc_ptr)); 
            case 2; 
                #if DEBUG log("dcCallShort\n");
                assign(return_value.value_pointer, dcCallShort   (vm, xx proc_ptr)); 
            case 4; 
                #if DEBUG log("dcCallInt\n");
                assign(return_value.value_pointer, dcCallInt     (vm, xx proc_ptr)); 
            case 8; 
                #if DEBUG log("dcCallLongLong\n");
                assign(return_value.value_pointer, dcCallLongLong(vm, xx proc_ptr)); 
            case;
                log("invalid integer size!\n");
                return Any.{};
        }
        
      case .FLOAT;
        if return_type.runtime_size == {
          case 4; 
            #if DEBUG log("dcCallFloat\n");
            assign(return_value.value_pointer, dcCallFloat (vm, xx proc_ptr)); 
          case 8; 
            #if DEBUG log("dcCallDouble\n");
            assign(return_value.value_pointer, dcCallDouble(vm, xx proc_ptr)); 
           case;
            log("invalid float size!\n");
            return Any.{};
        }
        
      case .ARRAY;
        ti_array := cast(*Type_Info_Array) return_type;
        if ti_array.array_type == .FIXED {
            log("error: we should never get fixed array as return type!\n");
            return Any.{};
        }
        #through;
        
      case .STRUCT;
        ag := find_DCaggr(return_type);
        if !ag {
            log("unable to find DCaggr for struct when calling proc!\n");
        }
        #if DEBUG log("dcCallAggr(%)\n", ag);
        dcCallAggr(vm, xx proc_ptr, ag, xx return_value.value_pointer);
        log("error: %\n", dcGetError(vm));
        log("result: %\n", return_value.value_pointer);
    }
    
    return return_value;
}

_check_arguments :: (ti_proc: *Type_Info_Procedure, args: ..Any) -> (u64, bool) {
    if ti_proc.argument_types.count != args.count {
        log("provided incorrect number of arguments for procedure!\n");
        return 0, false;
    }
    
    total_stack_needed: u64;
    for ti_proc.argument_types {
        if args[it_index].type != it {
            log("provided incorrect type for argument % of procedure!\n", it_index);
            log("expected %, got %\n", type_info_to_type(it), type_info_to_type(args[it_index].type));
            return 0, false;
        }
        if it.type == .STRUCT {
            if !find_or_make_and_register_DCaggr(cast(*Type_Info_Struct)it) {
                log("unable to register DCaggr for struct!\n");
            }
        }
        total_stack_needed += cast(u64) it.runtime_size;
    }
    return total_stack_needed, true;
}

_push_arguments :: (vm: *DCCallVM, args: ..Any, jai_call := false) -> (bool) {
    for args {
        if it.type.type == {
          case .POINTER;
            dcArgPointer(vm, (cast(*DCpointer)(it.value_pointer)).*); #if DEBUG log("dcArgPointer\n");
            
          case .ENUM; #through;
          case .BOOL; #through;
          case .INTEGER;
            if it.type.runtime_size == {
                case 1; dcArgChar    (vm, (cast(*DCchar    )(it.value_pointer)).*); #if DEBUG log("dcArgChar\n");
                case 2; dcArgShort   (vm, (cast(*DCshort   )(it.value_pointer)).*); #if DEBUG log("dcArgShort\n");
                case 4; dcArgInt     (vm, (cast(*DCint     )(it.value_pointer)).*); #if DEBUG log("dcArgInt\n");
                case 8; dcArgLongLong(vm, (cast(*DClonglong)(it.value_pointer)).*); #if DEBUG log("dcArgLongLong\n");
                case;
                    log("invalid integer size!\n");
                    return false;
            }
            
          case .FLOAT;
            if it.type.runtime_size == {
                case 4; dcArgFloat (vm, (cast(*DCfloat )(it.value_pointer)).*); #if DEBUG log("dcArgFloat\n");
                case 8; dcArgDouble(vm, (cast(*DCdouble)(it.value_pointer)).*); #if DEBUG log("dcArgDouble\n");
                case;
                    log("invalid float size!\n");
                    return false;
            }
            
          case .STRUCT;
            if jai_call {
                dcArgPointer(vm, it.value_pointer); #if DEBUG log("dcArgPointer\n");
            } else {
                ag := find_or_make_and_register_DCaggr(cast(*Type_Info_Struct)it.type);
                if !ag  return false;
                dcArgAggr(vm, ag, it.value_pointer);
            }
            
          case .ARRAY;
            ti_array := cast(*Type_Info_Array) it.type;
            if ti_array.array_type == {
              case .VIEW;
                ag := find_or_make_and_register_DCaggr(type_info(Array_View_64));
                if !ag  return false;
                dcArgAggr(vm, ag, it.value_pointer);
                
              case .RESIZABLE;
                ag := find_or_make_and_register_DCaggr(type_info(Resizable_Array));
                if !ag  return false;
                dcArgAggr(vm, ag, it.value_pointer);
                
              case;
                if !jai_call {
                    log("Error: cannot pass a fixed array to a #c_call procedure!\n");
                    return false;
                }
                
                ag := find_or_make_and_register_DCaggr(xx ti_array);
                if !ag  return false;
                dcArgAggr(vm, ag, it.value_pointer);
            }
        }
    }
    return true;
}


/*
    DCaggr objects
    
    We keep one big lookup table of all the aggr objects we've built, 
        so that we don't have to re-construct them every time.
    These get built automatically from type info.
*/

DCaggr_lookup_table: [..] struct { ti: *Type_Info; ag: *DCaggr; };

find_DCaggr :: inline (ti: *Type_Info) -> *DCaggr {
    for DCaggr_lookup_table  if it.ti == ti  return it.ag;
    return null;
}

find_or_make_and_register_DCaggr :: (ti: *Type_Info) -> *DCaggr {
    ag := find_DCaggr(ti);
    if !ag {
        ag = make_DCaggr(ti);
        #if DEBUG log("created new DCaggr object @ %\n", ag);
        register_DCaggr(ti, ag);
    }
    return ag;
}

register_DCaggr :: inline (ti: *Type_Info, ag: *DCaggr) {
    if !ti || !ag {
        log("attempted to register invalid DCaggr\n");
        return;
    }
    array_add(*DCaggr_lookup_table, .{ ti, ag });
}

make_DCaggr :: (ti: *Type_Info) -> *DCaggr {
    if ti.type == {
      case .ARRAY;
        ti_array := cast(*Type_Info_Array) ti;
        if ti_array.array_type == .FIXED {
            return _make_DCaggr_array(cast(*Type_Info_Array)ti);
        }
      case .STRUCT;
        return _make_DCaggr_struct(cast(*Type_Info_Struct)ti);
    }
    log("Invalid type given in make_DCaggr()!\n");
    return null;
}

/*
    In general, we want to avoid making DCaggr objects for fixed array types.
    We could avoid this altogether if only supporting the C calling convention, but Jai allows for passing fixed size arrays, 
        and I want to be feature complete here even if it means having some less than ideal code.
    If fixed arrays are within a struct, then we don't need to call into this proc because we can pass an array count.
    But if the array is the top-level type so-to-speak, then we need to make a DCaggr for it.
    Maybe in the future I can come up with some better way to minimize the need for this further...
*/
_make_DCaggr_array :: (ti: *Type_Info_Array) -> *DCaggr {
    ag := dcNewAggr(cast(u64)ti.array_count, cast(u64)ti.runtime_size);
    success := false;
    defer if !success dcFreeAggr(ag);
    
    // basically a DCaggr struct, but with only one member (the fixed size array)
    if !_add_DCaggr_field(ag, ti, 0)  return null;
    
    dcCloseAggr(ag);
    success = true;
    return ag;
}

_make_DCaggr_struct :: (ti: *Type_Info_Struct) -> *DCaggr {
    ag := dcNewAggr(cast(u64)ti.members.count, cast(u64)ti.runtime_size);
    success := false;
    defer if !success dcFreeAggr(ag);
    
    last_offset := 0; // hacky fix to skip adding fields with #place directives, as dyncall doesn't seem to like overlapping fields in a struct definition (reasonably so)
    for ti.members {
        if it.flags & .CONSTANT  continue;
        if it.offset_in_bytes < last_offset  continue; 
        
        if !_add_DCaggr_field(ag, it.type, it.offset_in_bytes)  return null;
        
        last_offset = it.offset_in_bytes + it.type.runtime_size;
    }
    
    dcCloseAggr(ag);
    success = true;
    return ag;
}

_add_DCaggr_field :: (ag: *DCaggr, ti: *Type_Info, offset_in_bytes: int) -> bool {
    sigchar  : DCsigchar = 0;
    arrcount : DCsize    = 1;
    
    // Handle fixed-size arrays by multiplying arrcount, updating elem_type
    elem_type := ti;
    while true {
        if elem_type.type == .ARRAY {
            ti_array := cast(*Type_Info_Array) elem_type;
            if ti_array.array_type == .FIXED {
                arrcount *= cast(u64) ti_array.array_count;
                elem_type = ti_array.element_type;
                continue;
            }
        }
        break;
    }
    
    if elem_type.type == {
      case .ENUM; #through;
      case .INTEGER;
        if elem_type.runtime_size == {
            case 1; sigchar = DC_SIGCHAR_CHAR;
            case 2; sigchar = DC_SIGCHAR_SHORT;
            case 4; sigchar = DC_SIGCHAR_INT;
            case 8; sigchar = DC_SIGCHAR_LONGLONG;
        }
        
      case .FLOAT;
        if elem_type.runtime_size == {
            case 4; sigchar = DC_SIGCHAR_FLOAT;
            case 8; sigchar = DC_SIGCHAR_DOUBLE;
        }
        
      case .POINTER; 
        sigchar = DC_SIGCHAR_POINTER;
        
      case .PROCEDURE;
        sigchar = DC_SIGCHAR_POINTER;
        
      case .STRUCT;
        ti_nested := cast(*Type_Info_Struct)elem_type;
        ag_nested := find_or_make_and_register_DCaggr(ti_nested);
        if !ag_nested  return false;
        
        dcAggrField(ag, DC_SIGCHAR_AGGREGATE, cast(s32)offset_in_bytes, arrcount, ag_nested);
        return true; // We don't want to run the common case below.
        
      case .ARRAY;
        ti_array := cast(*Type_Info_Array) elem_type;
        
        ag_array: *DCaggr;
        if ti_array.array_type == {
          case .VIEW;
            ag_array := find_or_make_and_register_DCaggr(type_info(Array_View_64));
          case .RESIZABLE;
            ag_array := find_or_make_and_register_DCaggr(type_info(Resizable_Array));
          case;
            log("error: invalid array type!\n");
            return false;
        }
        
        if !ag_array  return false;
        dcAggrField(ag, DC_SIGCHAR_AGGREGATE, cast(s32)offset_in_bytes, arrcount, ag_array);
        return true; // We don't want to run the common case below.
    }
    
    // Common case for primitive types, no need to duplicate the call up in each case.
    assert(sigchar != 0, "Sigchar was not assigned a value!");
    dcAggrField(ag, sigchar, cast(s32)offset_in_bytes, arrcount);
    return true;
}

#scope_file

// may remove later, for now it's useful to debug the below
type_info_to_type :: (ti: *Type_Info) -> Type {
    return (cast(*Type)*ti).*;
}


