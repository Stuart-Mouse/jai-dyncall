#load "bindings.jai";

#if OS != .WINDOWS {
    #assert false;
}

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
    for *ti_proc.argument_types {
        if args[it_index].type != it.* {
            print("provided incorrect type for argument % of procedure '%'!\n\texpected '%', got '%'\n", it_index, proc, (cast(*Type)it).*, (cast(*Type)*args[it_index]).*);
            return Any.{};
        }
        total_stack_needed += cast(u64) it.*.runtime_size;
    }
    
    // point of no return!
    
    vm := dcNewCallVM(total_stack_needed + 1024); // big ass safety margin?
    dcMode(vm, DC_CALL_C_DEFAULT);
    dcReset(vm);
    defer dcFree(vm);
    
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
        if it.type.runtime_size == {
            case 1; dcArgChar    (vm, (cast(*DCchar    )(it.value_pointer)).*);
            case 2; dcArgShort   (vm, (cast(*DCshort   )(it.value_pointer)).*);
            case 4; dcArgInt     (vm, (cast(*DCint     )(it.value_pointer)).*);
            case 8; dcArgLongLong(vm, (cast(*DClonglong)(it.value_pointer)).*);
            case;
                print("not yet supporting args over 8 bytes!\n");
                return Any.{};
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
    
    // TODO: we should probably have some static assert to sanity check that these correspond to the proper sizes
    if return_type.runtime_size == {
        case 1; assign(return_value.value_pointer, dcCallChar    (vm, xx proc_ptr));
        case 2; assign(return_value.value_pointer, dcCallShort   (vm, xx proc_ptr));
        case 4; assign(return_value.value_pointer, dcCallInt     (vm, xx proc_ptr));
        case 8; assign(return_value.value_pointer, dcCallLongLong(vm, xx proc_ptr));
        case;
            print("not yet supporting args over 8 bytes!\n");
            return Any.{};
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

DCstruct_lookup_table: [..] struct { ti: *Type_Info_Struct; dc: *DCstruct; };

find_DCstruct :: inline (ti: *Type_Info_Struct) -> *DCstruct {
    for DCstruct_lookup_table  if it.ti == ti  return it.dc;
    return null;
}

register_DCstruct :: inline (ti: *Type_Info_Struct, dc: *DCstruct) {
    array_add(*DCstruct_lookup_table, .{ ti, dc });
}
