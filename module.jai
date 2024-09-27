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
#assert(DCchar     == s8     );
#assert(DCshort    == s16    );
#assert(DCint      == s32    );
#assert(DClonglong == s64    );
#assert(DCfloat    == float  );
#assert(DCdouble   == float64);


#import "Basic";

DYNAMIC_C_CALL :: (proc: Any, args: ..Any) -> Any {
    if proc.type.type != .PROCEDURE  return Any.{};
    ti_proc := cast(*Type_Info_Procedure) proc.type;
    
    if !(ti_proc.procedure_flags & .IS_C_CALL) {
        print("provided procedure '%' is not a C call!\n", proc);
        return Any.{};
    }
    
    assert(ti_proc.return_types.count <= 1); // sanity check
    return_type := ifx ti_proc.return_types then ti_proc.return_types[0] else type_info(void);
    
    // check that all arguments are the right type, that we have the proper number of args, and count up stack space needed
    if ti_proc.argument_types.count != args.count {
        print("provided incorrect number of arguments for procedure '%'!\n", proc);
        return Any.{};
    }
    
    // TODO: in the future, we may want to support default values on arguments?
    // we can't get the info on default argument values at runtime though it seems?
    
    // We will definitely need better argument type checking, and we probabyl just want to implicitly conversions on integer and float parameters
    // otherwise, we will have calls failing any time a default sized int is passing in the args...
    
    // but we also don't want to have to make copies of all the arguments out here just so that we can resize them appropriately...
    // we could be very hacky about it and just allow narrowing conversions, and then just pass the same pointer as if it were the right size/signedness?
    
    total_stack_needed: u64;
    for ti_proc.argument_types {
        if args[it_index].type != it {
            print("provided incorrect type for argument % of procedure!\n", it_index);
            return Any.{};
        }
        if it.type == .STRUCT {
            if !find_or_make_and_register_DCaggr(cast(*Type_Info_Struct)it) {
                print("unable to register DCaggr for struct!\n");
            }
        }
        total_stack_needed += cast(u64) it.runtime_size;
    }
    
    // point of no return!
    
    vm := dcNewCallVM(total_stack_needed + 1024); // big ass safety margin?
    dcMode(vm, DC_CALL_C_DEFAULT);
    dcReset(vm);
    defer dcFree(vm);
    
    if return_type.type == .STRUCT {
        ag := find_or_make_and_register_DCaggr(cast(*Type_Info_Struct)return_type);
        print("dcBeginCallAggr(%)\n", ag);
        dcBeginCallAggr(vm, ag);
    }
    
    /*
        I think the only thing we actually care about when pushing args here is the size of the argument being pushed.
        Why there's not a more explicit way to specify that with dyncall, I don't really know.
        It doesn't appear to matter if I use the 4 and 8 byte int dcArg procs for floats, so presumably dyncall doesn't care
        
        Would be really nice if we could simplify here and just switch on the size of the parameter to know which verison to call.
        Or perhaps I should just try to investiage the source a bit more and figure out what it's doing behind the scenes
            maybe internally they've got a more sensible interface but just decided to hide it
        
        Also, I figure that for structs, we can probably also just push the proper number of bytes and call it a day
    */
    
    for args {
        // print("pushing arg of size '%'\n", it.type.runtime_size);
        if it.type.type == {
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
                    return Any.{};
            }
            
          case .FLOAT;
            if it.type.runtime_size == {
                case 4; dcArgFloat (vm, (cast(*DCfloat )(it.value_pointer)).*); print("dcArgFloat\n");
                case 8; dcArgDouble(vm, (cast(*DCdouble)(it.value_pointer)).*); print("dcArgDouble\n");
                case;
                    print("invalid float size!\n");
                    return Any.{};
            }
            
          case .STRUCT;
            ag := find_or_make_and_register_DCaggr(cast(*Type_Info_Struct)return_type);
            dcArgAggr(vm, ag, it.value_pointer);
        }
        
    }
    
    // For now, we will allocate the space for the result in temp storage and the user will get back an any with the return value
    return_value: Any;
    if return_type.runtime_size {
        return_value = Any.{ return_type, alloc(return_type.runtime_size) };
    }
    
    assign :: inline (dst: *void, value: $T) {
        (cast(*T)dst).* = value;
    }
    
    proc_ptr := (cast(**void)proc.value_pointer).*;
    
    if return_type.type == {
          case .ENUM; #through;
          case .BOOL; #through;
          case .INTEGER;
            if return_type.runtime_size == {
                case 1; assign(return_value.value_pointer, dcCallChar    (vm, xx proc_ptr));
                case 2; assign(return_value.value_pointer, dcCallShort   (vm, xx proc_ptr));
                case 4; assign(return_value.value_pointer, dcCallInt     (vm, xx proc_ptr));
                case 8; assign(return_value.value_pointer, dcCallLongLong(vm, xx proc_ptr));
                case;
                    print("invalid integer size!\n");
                    return Any.{};
            }
            
          case .FLOAT;
            if return_type.runtime_size == {
                case 4; assign(return_value.value_pointer, dcCallFloat (vm, xx proc_ptr));
                case 8; assign(return_value.value_pointer, dcCallDouble(vm, xx proc_ptr));
                case;
                    print("invalid float size!\n");
                    return Any.{};
            }
            
          case .STRUCT;
            ag := find_DCaggr(cast(*Type_Info_Struct)return_type);
            if !ag {
                print("unable to find DCaggr for struct when calling proc!\n");
            }
            print("dcCallAggr(%)\n", ag);
            ptr_returned := dcCallAggr(vm, xx proc_ptr, ag, xx return_value.value_pointer);
            print("error: %\n", dcGetError(vm));
            print("result: %\n", return_value.value_pointer);
            print("ptr_returned: %\n", ptr_returned);
        }
        
    return return_value;
}


/*
    dyncall struct objects
    
    in order to prevent needing to define these structs every single time we make a call, 
    I'm going to have one large global lookup table for this
    would need to have a mutex for this in threaded environment
    
    may not actually do this if we can find a better way to push and return structs
    I don't know why they have this ridiculous interface when presumably all they really need to know is the total size of the struct?
    
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
        
        sigchar: DCsigchar;
        arrcount: DCsize = 1;
        
        if it.type.type == {
          case .ENUM; #through;
          case .INTEGER;
            if it.type.runtime_size == {
                case 1; sigchar = DC_SIGCHAR_CHAR;
                case 2; sigchar = DC_SIGCHAR_SHORT;
                case 4; sigchar = DC_SIGCHAR_INT;
                case 8; sigchar = DC_SIGCHAR_LONGLONG;
            }
            
          case .FLOAT;
            if it.type.runtime_size == {
                case 4; sigchar = DC_SIGCHAR_FLOAT;
                case 8; sigchar = DC_SIGCHAR_DOUBLE;
            }
            
          case .POINTER; 
            sigchar = DC_SIGCHAR_POINTER;
            
          case .STRUCT;
            ti_nested := cast(*Type_Info_Struct)it.type;
            ag_nested := find_or_make_and_register_DCaggr(ti_nested);
            if !ag_nested  return null;
            
            dcAggrField(ag, DC_SIGCHAR_AGGREGATE, cast(s32)it.offset_in_bytes, 1, ag_nested);
            continue; // We don't want to run the common case below.
            
          case .ARRAY;
            /*
                array view and resizable array can be treated as structs
                fixed size arrays should probably be extracted up to a condition before this switch
                    while type is fixed array, multiply arrcount
                    then sub element type for it.type
            */
        }
        
        print("it %\n", it);
        assert(sigchar != 0);
        dcAggrField(ag, sigchar, cast(s32)it.offset_in_bytes, arrcount);
    }
    
    success = true;
    dcCloseAggr(ag);
    return ag;
}