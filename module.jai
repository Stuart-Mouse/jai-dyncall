#load "bindings.jai";

#if OS != .WINDOWS {
    #assert false;
}

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

DYNAMIC_JAI_CALL :: (proc: Any, args: ..Any) -> [] Any {
    if proc.type.type != .PROCEDURE  return Any.[];
    ti_proc := cast(*Type_Info_Procedure) proc.type;
    
    if (ti_proc.procedure_flags & .IS_C_CALL) {
        print("provided procedure '%' is not a C call!\n", proc);
        return Any.[];
    }
    
    total_stack_needed, ok := _check_arguments(ti_proc, ..args);
    
    // Begin the actual call
    
    vm := dcNewCallVM(total_stack_needed + 1024); // big ass safety margin?
    dcMode(vm, DC_CALL_C_DEFAULT);
    dcReset(vm);
    defer dcFree(vm);
    
    if !(ti_proc.procedure_flags & .HAS_NO_CONTEXT) {
        dcArgPointer(vm, *context);
    }
    
    if !_push_arguments(vm, ..args, jai_call = true)  return Any.[];
    
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

DYNAMIC_C_CALL :: (proc: Any, args: ..Any) -> Any {
    if proc.type.type != .PROCEDURE  return Any.{};
    ti_proc := cast(*Type_Info_Procedure) proc.type;
    
    if !(ti_proc.procedure_flags & .IS_C_CALL) {
        print("provided procedure '%' is not a C call!\n", proc);
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
        ag := find_or_make_and_register_DCaggr(cast(*Type_Info_Struct)return_type_for_aggr);
        print("dcBeginCallAggr(%)\n", ag);
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
        print("dcCallVoid\n");
        dcCallVoid(vm, xx proc_ptr);
        
      case .POINTER;
        print("dcCallPointer\n");
        dcCallPointer(vm, xx proc_ptr);
        
      case .ENUM; #through;
      case .BOOL; #through;
      case .INTEGER;
        if return_type.runtime_size == {
            case 1; 
                print("dcCallChar\n");
                assign(return_value.value_pointer, dcCallChar    (vm, xx proc_ptr)); 
            case 2; 
                print("dcCallShort\n");
                assign(return_value.value_pointer, dcCallShort   (vm, xx proc_ptr)); 
            case 4; 
                print("dcCallInt\n");
                assign(return_value.value_pointer, dcCallInt     (vm, xx proc_ptr)); 
            case 8; 
                print("dcCallLongLong\n");
                assign(return_value.value_pointer, dcCallLongLong(vm, xx proc_ptr)); 
            case;
                print("invalid integer size!\n");
                return Any.{};
        }
        
      case .FLOAT;
        if return_type.runtime_size == {
          case 4; 
            print("dcCallFloat\n");
            assign(return_value.value_pointer, dcCallFloat (vm, xx proc_ptr)); 
          case 8; 
            print("dcCallDouble\n");
            assign(return_value.value_pointer, dcCallDouble(vm, xx proc_ptr)); 
           case;
            print("invalid float size!\n");
            return Any.{};
        }
        
      case .ARRAY;
        ti_array := cast(*Type_Info_Array) return_type;
        if ti_array.array_type == .FIXED {
            print("error: we should never get fixed array as return type!\n");
            return Any.{};
        }
        #through;
        
      case .STRUCT;
        ag := find_DCaggr(cast(*Type_Info_Struct)return_type);
        if !ag {
            print("unable to find DCaggr for struct when calling proc!\n");
        }
        print("dcCallAggr(%)\n", ag);
        dcCallAggr(vm, xx proc_ptr, ag, xx return_value.value_pointer);
        print("error: %\n", dcGetError(vm));
        print("result: %\n", return_value.value_pointer);
    }
    
    return return_value;
}

_check_arguments :: (ti_proc: *Type_Info_Procedure, args: ..Any) -> (u64, bool) {
    if ti_proc.argument_types.count != args.count {
        print("provided incorrect number of arguments for procedure!\n");
        return 0, false;
    }
    
    total_stack_needed: u64;
    for ti_proc.argument_types {
        if args[it_index].type != it {
            print("provided incorrect type for argument % of procedure!\n", it_index);
            return 0, false;
        }
        if it.type == .STRUCT {
            if !find_or_make_and_register_DCaggr(cast(*Type_Info_Struct)it) {
                print("unable to register DCaggr for struct!\n");
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
            dcArgPointer(vm, (cast(*DCpointer)(it.value_pointer)).*); print("dcArgPointer\n");
            
          case .ENUM; #through;
          case .BOOL; #through;
          case .INTEGER;
            if it.type.runtime_size == {
                case 1; dcArgChar    (vm, (cast(*DCchar    )(it.value_pointer)).*); print("dcArgChar\n");
                case 2; dcArgShort   (vm, (cast(*DCshort   )(it.value_pointer)).*); print("dcArgShort\n");
                case 4; dcArgInt     (vm, (cast(*DCint     )(it.value_pointer)).*); print("dcArgInt\n");
                case 8; dcArgLongLong(vm, (cast(*DClonglong)(it.value_pointer)).*); print("dcArgLongLong\n");
                case;
                    print("invalid integer size!\n");
                    return false;
            }
            
          case .FLOAT;
            if it.type.runtime_size == {
                case 4; dcArgFloat (vm, (cast(*DCfloat )(it.value_pointer)).*); print("dcArgFloat\n");
                case 8; dcArgDouble(vm, (cast(*DCdouble)(it.value_pointer)).*); print("dcArgDouble\n");
                case;
                    print("invalid float size!\n");
                    return false;
            }
            
          case .STRUCT;
            if jai_call {
                dcArgPointer(vm, it.value_pointer); print("dcArgPointer\n");
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
                print("vp %\n", it.value_pointer);
                dcArgAggr(vm, ag, it.value_pointer);
                
              case .RESIZABLE;
                ag := find_or_make_and_register_DCaggr(type_info(Resizable_Array));
                if !ag  return false;
                dcArgAggr(vm, ag, it.value_pointer);
                
              case;
                // TODO: we should be able to pass fixed size arrays in Jai calls...
                // but we don't want to store dcAggrs for random ass array types
                print("error: invalid array type!\n");
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

DCaggr_lookup_table: [..] struct { ti: *Type_Info_Struct; ag: *DCaggr; };

find_DCaggr :: inline (ti: *Type_Info_Struct) -> *DCaggr {
    for DCaggr_lookup_table  if it.ti == ti  return it.ag;
    return null;
}

find_or_make_and_register_DCaggr :: (ti: *Type_Info_Struct) -> *DCaggr {
    ag := find_DCaggr(ti);
    if !ag {
        ag = make_DCaggr(ti);
        print("created new DCaggr object @ %\n", ag);
        register_DCaggr(ti, ag);
    }
    return ag;
}

register_DCaggr :: inline (ti: *Type_Info_Struct, ag: *DCaggr) {
    if !ti || !ag {
        print("attempted to register invalid DCaggr\n");
        return;
    }
    array_add(*DCaggr_lookup_table, .{ ti, ag });
}

make_DCaggr :: (ti: *Type_Info_Struct) -> *DCaggr {
    ag := dcNewAggr(cast(u64)ti.members.count, cast(u64)ti.runtime_size);
    success := false;
    defer if !success dcFreeAggr(ag);
    
    for ti.members {
        if it.flags & .CONSTANT  continue;
        
        sigchar  : DCsigchar = 0;
        arrcount : DCsize    = 1;
        
        // Handle fixed-size arrays by multiplying arrcount, updating elem_type
        elem_type := it.type;
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
            if !ag_nested  return null;
            
            dcAggrField(ag, DC_SIGCHAR_AGGREGATE, cast(s32)it.offset_in_bytes, 1, ag_nested);
            continue; // We don't want to run the common case below.
        
          case .ARRAY;
            ti_array := cast(*Type_Info_Array) elem_type;
            
            if ti_array.array_type == {
              case .VIEW;
                ag_nested := find_or_make_and_register_DCaggr(type_info(Array_View_64));
                if !ag_nested  return null;
                dcAggrField(ag, DC_SIGCHAR_AGGREGATE, cast(s32)it.offset_in_bytes, 1, ag_nested);
                
              case .RESIZABLE;
                ag_nested := find_or_make_and_register_DCaggr(type_info(Resizable_Array));
                if !ag_nested  return null;
                dcAggrField(ag, DC_SIGCHAR_AGGREGATE, cast(s32)it.offset_in_bytes, 1, ag_nested);
                
              case;
                print("error: invalid array type!\n");
            }
            continue; // We don't want to run the common case below.
        }
        
        // print("it %\n", it); // debug print all struct members that we add to the dcAggr 
        assert(sigchar != 0, "Sigchar was not assigned a value!");
        dcAggrField(ag, sigchar, cast(s32)it.offset_in_bytes, arrcount);
    }
    
    success = true;
    dcCloseAggr(ag);
    return ag;
}