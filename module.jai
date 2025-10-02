 
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
// but the ones for the procedures are actually kind of nice and it felt wierd not to do the types to match
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

// ========== Implementation Notes ==========

/*
    IMPORTANT: Dyncall-ing Jai procedures totally doesn't work at all with the x64 backend!
    So in the mean time your choices are to use the LLVM backend, where Jai uses the C calling convention behind the scenes, or you can wrap your Jai procedures with #c_call wrappers.
    
    Passing Arguments to Jai Procedures:
        Structs are always passed by pointer in Jai calls.
        All other types are passed by value, including all array types.
        For #c_call procedures, we actually do pass structs by value.
        
        If we de-sugared Jai calls into C calls, they would look something like this:
            void procedure(Context* context, ..T arguments, ..void* return_values);
        
        The context pointer is passed as the first argument.
        Then we pass all normal arguments.
        Lastly, we pass pointers to all return values.
        
    TODO: 
        - create a test suite
        - think about ways to improve #c_call wrappers
*/


// ========== Convenience Wrappers ==========

/*
    The Dyncall_VM struct acts as a sort of wrapper around the DCCallVM,
    holding some additional state so that it can provide extra checking
    while also allowing the user to manually push arguments if they wish to do so.
    
    While this module also provides simple procedures to push a whole array of arguments automatically,
    there are many cases where the user may want to manually coerce or modify arguments as they are passed.
    
    Return values don't have any kind of support for manual pushing or coercions,
    but if you want to handle return values specially, or you aren't certain of the return type before 
    executing some call, you can use do_dyncall_a or execute_call_a to allocate the results as an [] Any.
*/

Dyncall_VM :: struct {
    __vm:              *DCCallVM;
    target:            C_Call_Wrapper;
    arguments_pushed:  int;
    flags:             Flags;
    return_aggr:       *DCaggr;
    
    Flags :: enum_flags {
        INITIALIZED;
        USING_WRAPPER;
        CALL_STARTED;
    };
}

new_vm :: (size := 2048, mode := DC_CALL_C_DEFAULT) -> Dyncall_VM {
    vm: Dyncall_VM;
    init(vm);
    return vm;
}

init :: (using vm: *Dyncall_VM, size := 2048, mode := DC_CALL_C_DEFAULT) {
    __vm = dcNewCallVM(size);
    dcMode(__vm, mode);
    dcReset(__vm);  
    flags |= .INITIALIZED;
}

deinit :: (using vm: *Dyncall_VM) {
    if vm  dcFree(vm);
}

get_error :: (using vm: *DCCallVM) -> string {
    // TODO: maybe provide more context?
    error := dcGetError(__vm);
    return error;
}

// will log error if present and reset the vm
check_error :: (using vm: *DCCallVM) -> bool {
    error := get_error(vm);
    if error {
        log("Dyncall Internal Error: %", error);
        reset(vm);
        return false;
    }
    return true;
}

reset :: (using vm: *DCCallVM, mode := DC_CALL_C_DEFAULT) {
    bvm := __vm;
    vm = .{};
    __vm = bvm;
    dcMode(__vm, mode);
    dcReset(__vm);
    flags |= .INITIALIZED;
}

begin_call :: (vm: *Dyncall_VM, procedure: Any) -> bool {
    if flags & .CALL_STARTED {
        log("Error: cannot begin call, call was already started.");
        reset(vm);
        return false;
    }
    defer  if check_error(vm)  return false;
    
    if procedure.type == xx C_Call_Wrapper {
        flags |= .USING_WRAPPER;
        
        dcArgPointer(vm, xx jai_proc.pointer);
        if !(jai_proc.procedure_flags & .HAS_NO_CONTEXT) { 
            dcArgPointer(vm, xx ifx context_pointer else *context);
        }
    } else {
        proc := Any_Proc.from(procedure);
        set(target, proc);
        
        if proc.procedure_flags & .IS_C_CALL {
            assert(proc.return_types.count <= 1);
            ok:, return_aggr = begin_c_call(vm, proc, ifx proc.return_types then proc.return_types[0] else xx void);
            if !ok  return false;
        } else {
            if !(proc.procedure_flags & .HAS_NO_CONTEXT)  dcArgPointer(vm, *context);
        }
    }
    
    flags |= .CALL_STARTED;
    return true;
}

execute_call :: (vm: *Dyncall_VM, return_values: ..Any) -> bool {
    if !(flags & .CALL_STARTED) {
        log("Error: cannot execute call before calling begin_call.");
        reset(vm);
        return false;
    }
    if arguments_pushed != proc_info.argument_types.count {
        log("Error: Incorrect number of arguents passed to call. Expected %, got %.", proc_info.argument_types.count, arguments_pushed);
        reset(vm);
        return false;
    }
    defer  if get_error(vm)  return false;
    
    if !typecheck_return_values(proc.proc_info, ..return_values)  return false;
    
    if flags & .USING_WRAPPER {
        dcCallVoid(vm, xx target.wrapper.wrapper_proc.pointer);
    } else {
        proc := target.procedure;
        assert(proc != null);
        
        if proc.procedure_flags & .IS_C_CALL {
            return_value := ifx return_values then return_values[0] else Void_Any;
            if !execute_c_call(__vm, target.procedure.pointer, return_value, aggr)  return false;
        } else {
            for return_values  dcArgPointer(vm, it.value_pointer);
            dcCallVoid(vm, xx target.procedure.pointer);
        }
    }
    
    return true;
}

// Standard procedure for calling any procedure type. 
// Will support coercion of arguments if user has enabled coercions.
do_dyncall :: (vm: *DCCallVM, procedure: Any, arguments: [] Any, return_values: [] Any) -> bool {
    dcReset(vm);
    defer {
        error := dcGetError(vm);
        if error {
            log("Dyncall Internal Error: %", error);
            return false;
        }
    }
    
    proc := Any_Proc.from(procedure);
    if !typecheck_arguments    (proc.proc_info, ..arguments    )  return false;
    if !typecheck_return_values(proc.proc_info, ..return_values)  return false;
    
    if proc.procedure_flags & .IS_C_CALL {
        assert(proc.return_types.count <= 1); // sanity check
        return_value := ifx return_values then return_values[0] else Void_Any;
        
        // For a C call, we may have to start an aggr call before pushing arguments.
        ok, aggr := begin_c_call(vm, return_value.type);
        if !ok  return false;
        
        if !push_all_arguments(vm, proc.argument_types, arguments)  return false;
        if !execute_c_call(vm, proc.pointer, return_value, aggr)  return false;
    } else {
        if !(proc.procedure_flags & .HAS_NO_CONTEXT)  dcArgPointer(vm, *context);
        if !push_all_arguments(vm, proc.argument_types, arguments, jai_call = true)  return false;
        
        for return_values  dcArgPointer(vm, it.value_pointer);
        dcCallVoid(vm, xx proc.pointer);
    }
    
    return true;
}

// Allocating version of do_dyncall.
// In order to make freeing the allocated results easier, we only allocate a 
//     single chunk of memory for both the array and the elements within.
// The user should just call free() on the array's data pointer and free the individual elements.
do_dyncall_a :: (vm: *DCCallVM, procedure: Any, arguments: ..Any) -> bool, [] Any {
    proc := Any_Proc.from(procedure);
    
    array_size_in_bytes := proc.return_types.count * size_of(Any);
    bytes_to_allocate   := array_size_in_bytes;
    for proc.return_types  bytes_to_allocate += it.runtime_size;
    
    return_values: [] Any = .{ proc.return_types.count, alloc(bytes_to_allocate) };
    
    value_pointer := return_values.data + array_size_in_bytes;
    for proc.return_types {
        return_values[it_index] = .{ it, value_pointer };
        initialize_any(return_values[it_index]);
        value_pointer += it.runtime_size;
    }
    
    success := do_dyncall(vm, procedure, arguments, return_values);
    if !success  array_reset(return_values);
    return success, return_values;
}

// Temporary allocator version of do_dyncall_a
do_dyncall_t :: (vm: *DCCallVM, procedure: Any, arguments: ..Any) -> bool, [] Any {
    proc := Any_Proc.from(procedure);
    
    return_values := NewArray(proc.return_types.count, Any,, temp);
    for proc.return_types  return_values[it_index] = New_Any(it,, temp);
    
    success := do_dyncall(vm, procedure, arguments, return_values);
    return success, return_values;
}

// Performs a dyncall for a Jai procedure using a C_Call_Wrapper.
do_dyncall :: (vm: *DCCallVM, using c_call_wrapper: C_Call_Wrapper, arguments: [] Any, return_values: [] Any) -> bool {
    dcReset(vm);
    defer {
        error := dcGetError(vm);
        if error {
            log("Dyncall Internal Error: %", error);
            return false;
        }
    }
    
    // We basically just typecheck arguments and return values against the original jai_proc info,
    //     and ignore the wrapper type info. Maybe this is not the best idea since someone can come along
    //     and easily crash the program by using a mismatched wrapper and Jai proc...
    // But then again, that's sort of their own fault and we shouldn't have to check the wrapper 
    //     against the Jai proc type info every time we want to make a call.
    
    dcArgPointer(vm, xx procedure.pointer);
    if !(procedure.procedure_flags & .HAS_NO_CONTEXT) { 
        dcArgPointer(vm, xx ifx context_pointer else *context);
    }
    
    if !typecheck_arguments(procedure.proc_info, ..arguments)  return false;
    if !push_all_arguments(vm, procedure.proc_info.argument_types, arguments, jai_call = true)  return false;
    
    if !typecheck_return_values(procedure.proc_info, ..return_values)  return false;
    for return_values  dcArgPointer(vm, it.value_pointer);
    
    dcCallVoid(vm, xx wrapper.pointer);
    
    return true;
}

#scope_module

begin_c_call :: (vm: *DCCallVM, return_type: *Type_Info) -> bool, *DCaggr {
    if !return_type  return true, null;
    
    aggr_type:  *Type_Info;
    aggr:       *DCaggr;
    
    if return_type.type == {
      case .STRUCT;
        aggr_type = return_type;
        
      case .ARRAY;
        // If the return type is an array type, we want to pass the struct equivalent 
        //     for the array type rather than the array type itself.
        if return_type.(*Type_Info_Array).array_type == {
          case .VIEW;       aggr_type = xx Array_View_64;
          case .RESIZABLE;  aggr_type = xx Resizable_Array;
          case .FIXED;      aggr_type = return_type;
        }
    }
    if aggr_type {
        aggr = find_or_make_and_register_DCaggr(aggr_type);
        dcBeginCallAggr(vm, aggr);
    }
    
    return !dcGetError(vm), aggr;
}

// This is #scope_module for now, since the way we pass aggr_type 
//     is a bit odd and I may refactor this later.
// If we started the call with dcBeginCallAggr, then we need to call dcCallAggr with the same aggr object.
execute_c_call :: (vm: *DCCallVM, proc_ptr: *void, return_value: Any, aggr: *DCaggr = null) -> bool {
    if return_value.type.type == {
      case .VOID;
        dcCallVoid(vm, xx proc_ptr);
        
      case .POINTER;
        dcCallPointer(vm, xx proc_ptr);
        
      case .ENUM; #through;
      case .BOOL; #through;
      case .INTEGER;
        if return_value.type.runtime_size == {
            case 1; return_value.value_pointer.(*DCint8 ).* = dcCallInt8 (vm, xx proc_ptr); 
            case 2; return_value.value_pointer.(*DCint16).* = dcCallInt16(vm, xx proc_ptr); 
            case 4; return_value.value_pointer.(*DCint32).* = dcCallInt32(vm, xx proc_ptr); 
            case 8; return_value.value_pointer.(*DCint64).* = dcCallInt64(vm, xx proc_ptr); 
        }
        
      case .FLOAT;
        if return_value.type.runtime_size == {
          case 4; return_value.value_pointer.(*DCfloat32).* = dcCallFloat32(vm, xx proc_ptr); 
          case 8; return_value.value_pointer.(*DCfloat64).* = dcCallFloat64(vm, xx proc_ptr); 
        }
        
      case .ARRAY;
        ti_array := return_value.type.(*Type_Info_Array);
        if ti_array.array_type == .FIXED {
            log("Error: we should never get fixed array as return type!");
            return false;
        }
        #through;
        
      case .STRUCT;
        assert(aggr != null);
        dcCallAggr(vm, xx proc_ptr, aggr, xx return_value.value_pointer);
    }
    return true;
}
#scope_export

// ========== Type Checking ==========

// These procs take Any's for the arguments since that is the common case.
// I will probably add versions taking only the types soon, since that is also useful.

typecheck_arguments :: (proc_info: *Type_Info_Procedure, arguments: ..Any) -> bool {
    if proc_info.argument_types.count != arguments.count {
        log("Error: argument count did not match. Expected %, got %", proc_info.argument_types.count, arguments.count);
        return false;
    }
    for proc_info.argument_types {
        if it != arguments[it_index].type {
            log("argument % did not match. % != %", it_index, as_type(it), as_type(arguments[it_index].type));
            return false;
        }
    }
    return true;
}

typecheck_return_values :: (proc_info: *Type_Info_Procedure, return_values: ..Any) -> bool {
    if proc_info.return_types.count != return_values.count {
        log("Error: return value count did not match. Expected %, got %", proc_info.return_types.count, return_values.count);
        return false;
    }
    for proc_info.return_types {
        if it != return_values[it_index].type{
            log("return value % did not match. % != %", it_index, as_type(it), as_type(return_values[it_index].type));
            return false;
        }
    }
    return true;
}

// ========== Pushing Arguments ==========

// This version of push_argument will ensure that the proper number and types of arguments are passed
push_argument :: (using vm: *Dyncall_VM, any: Any, jai_call := false) -> bool {
    if arguments_pushed >= procedure.argument_types.count {
        log("Error: Attempted to pass too many arguments for call.");
        return false;
    }
    expected_type := procedure.argument_types[arguments_pushed];
    if !push_argument(__vm, expected_type, any) return false;
    
    arguments_pushed += 1;
    return true;
}

push_argument :: (vm: *DCCallVM, expected_type: *Type_Info, any: Any, jai_call := false) -> bool {
    if expected_type.type == {
      case .POINTER;
        // TODO: add support for passing pointers of subtypes as base type
        if any.type != expected_type {
            log("Error: argument type '%' does not match expected type '%'.", as_type(any.type), as_type(expected_type));
            return false;
        }
        dcArgPointer(vm, any.value_pointer.(*DCpointer).*); 
        
      case .ENUM; #through;
      case .BOOL; #through;
      case .INTEGER;
        if expected_type.runtime_size == {
          case 1; 
            val: DCint8;
            if !maybe_coerce(val, any)  return false;
            dcArgInt8(vm, val); 
            
          case 2; 
            val: DCint16;
            if !maybe_coerce(val, any)  return false;
            dcArgInt16(vm, val); 
            
          case 4; 
            val: DCint32;
            if !maybe_coerce(val, any)  return false;
            dcArgInt32(vm, val); 
            
          case 8; 
            val: DCint64;
            if !maybe_coerce(val, any)  return false;
            dcArgInt64(vm, val); 
        }
        
      case .FLOAT;
        if expected_type.runtime_size == {
          case 4; 
            val: DCfloat32;
            if !maybe_coerce(val, any)  return false;
            dcArgFloat32(vm, val); 
            
          case 8; 
            val: DCfloat64;
            if !maybe_coerce(val, any)  return false;
            dcArgFloat64(vm, val); 
        }
        
      case .STRING;
        if any.type != expected_type {
            log("Error: argument type '%' does not match expected type '%'.", as_type(any.type), as_type(expected_type));
            return false;
        }
        aggr := find_or_make_and_register_DCaggr(xx Array_View_64);
        if !aggr  return false;
        dcArgAggr(vm, aggr, any.value_pointer);
        
      case .STRUCT;
        if any.type != expected_type {
            log("Error: argument type '%' does not match expected type '%'.", as_type(any.type), as_type(expected_type));
            return false;
        }
        if jai_call {
            dcArgPointer(vm, any.value_pointer); 
        } else {
            aggr := find_or_make_and_register_DCaggr(xx any.type);
            if !aggr  return false;
            dcArgAggr(vm, aggr, any.value_pointer);
        }
        
      case .ARRAY;
        if any.type != expected_type {
            log("Error: argument type '%' does not match expected type '%'.", as_type(any.type), as_type(expected_type));
            return false;
        }
        array_info := any.type.(*Type_Info_Array);
        if array_info.array_type == {
          case .VIEW;
            aggr := find_or_make_and_register_DCaggr(xx Array_View_64);
            if !aggr  return false;
            dcArgAggr(vm, aggr, any.value_pointer);
            
          case .RESIZABLE;
            aggr := find_or_make_and_register_DCaggr(xx Resizable_Array);
            if !aggr  return false;
            dcArgAggr(vm, aggr, any.value_pointer);
            
          case;
            if !jai_call {
                log("Error: cannot pass a fixed array to a #c_call procedure!\n");
                return false;
            }
            
            aggr := find_or_make_and_register_DCaggr(xx array_info);
            if !aggr  return false;
            dcArgAggr(vm, aggr, any.value_pointer);
        }
    }
    return true;
}

push_all_arguments :: inline (vm: *DCCallVM, expected_types: [] *Type_Info, arguments: [] Any, jai_call := false) -> bool {
    if expected_types.count != arguments.count {
        log("Error: argument count did not match. Expected %, got %", expected_types.count, arguments.count);
        return false;
    }
    for arguments {
        if !push_argument(vm, expected_types[it_index], it, jai_call)  return false;
    }
    return true;
}

push_argument_nocheck :: (vm: *DCCallVM, any: Any, jai_call := false) -> bool {
    if type.type == {
      case .POINTER;
        dcArgPointer(vm, value_pointer.(*DCpointer).*); 
        
      case .ENUM; #through;
      case .BOOL; #through;
      case .INTEGER;
        if type.runtime_size == {
          case 1; dcArgInt8 (vm, value_pointer.(*DCint8 ).*); 
          case 2; dcArgInt16(vm, value_pointer.(*DCint16).*); 
          case 4; dcArgInt32(vm, value_pointer.(*DCint32).*); 
          case 8; dcArgInt64(vm, value_pointer.(*DCint64).*); 
          case;   assert(false, "Invalid integer size!");
        }
        
      case .FLOAT;
        if type.runtime_size == {
          case 4; dcArgFloat32(vm, value_pointer.(*DCfloat32).*); 
          case 8; dcArgFloat64(vm, value_pointer.(*DCfloat32).*); 
          case;   assert(false, "Invalid float size!");
        }
        
      case .STRING;
        aggr := find_or_make_and_register_DCaggr(type_info(Array_View_64));
        if !aggr  return false;
        dcArgAggr(vm, aggr, value_pointer);
        
      case .STRUCT;
        if jai_call {
            dcArgPointer(vm, value_pointer);
        } else {
            aggr := find_or_make_and_register_DCaggr(xx type);
            if !aggr  return false;
            dcArgAggr(vm, aggr, value_pointer);  
        }
        
      case .ARRAY;
        ti_array := type.(*Type_Info_Array);
        if ti_array.array_type == {
          case .VIEW;
            aggr := find_or_make_and_register_DCaggr(type_info(Array_View_64));
            if !aggr  return false;
            dcArgAggr(vm, aggr, value_pointer);  
            
          case .RESIZABLE;
            aggr := find_or_make_and_register_DCaggr(type_info(Resizable_Array));
            if !aggr  return false;
            dcArgAggr(vm, aggr, value_pointer);  
            
          case;
            if !jai_call {
                log("Error: cannot pass a fixed array to a #c_call procedure!\n");
                return false;
            }
            
            aggr := find_or_make_and_register_DCaggr(xx ti_array);
            if !aggr  return false;
            dcArgAggr(vm, aggr, value_pointer);  
        }
        
      case;
        log("Error: unable to push argument of type %\n", as_type(type));
        return false;
    }
    
    return true;
}

/*
    What we're generating below basically looks like this. 
    It's just a very thin wrapper proc to push the context and call the underlying jai procedure:
    
    wrapped_procedure :: (procedure: P, _context: *#Context, a1: Ta1, a2: Ta2, ..., r1: *Tr1, r2: *Tr2, ...) {
        push_context _context.* {
            r1.*, r2.*, ... := jai_proc(a1, a2, ...);
        }
    }
    
    Because we aren't baking `procedure`, we should only have one overload per type of procedure,
        not for every single procedure we wrap.
        
    TODO: make sure that we are properly passing struct parameters by pointer.
          I need to add some test cases for this, since I don't think I have any at the moment...
*/
make_c_call_wrapper :: (jai_proc: $P, _context: *#Context) -> C_Call_Wrapper #modify {
    jai_proc_info := P.(*Type_Info_Procedure);
    if jai_proc_info.type != .PROCEDURE  return false, "P must be a procedure type.";
    if jai_proc_info.procedure_flags & .IS_C_CALL  return false, "P must be a Jai procedure, not a #c_call.";
    return true;
} {
    jai_proc_info :: type_info(P);
    
    #insert -> string {
        builder: String_Builder;
        
        // declare types for use in argument list
        for 1..jai_proc_info.argument_types.count {
            print(*builder, "Ta% :: #run (*jai_proc_info.argument_types[%]).(*Type).*;\n", it, it-1);
        }
        for 1..jai_proc_info.return_types.count {
            print(*builder, "Tr% :: #run (*jai_proc_info.return_types[%]).(*Type).*;\n", it, it-1);
        }
        
        has_context := !(jai_proc_info.procedure_flags & .HAS_NO_CONTEXT);
        
        append(*builder, "wrapper_proc :: (jai_proc: P, ");
        if has_context  append(*builder, "_context: *#Context, ");
        
        for jai_proc_info.argument_types {
            if it_index != 0  append(*builder, ", ");
            print_to_builder(*builder, "a%: ",  it_index+1);
            if is_aggr(it)  append(*builder, "*");  // aggregates get passed by pointer
            print_to_builder(*builder, "Ta%",  it_index+1);
        }
        for jai_proc_info.return_types   print_to_builder(*builder, ", r%1: *Tr%1", it_index+1);
        append(*builder, ") ");
        append(*builder, "#c_call {\n");
        
        if has_context  append(*builder, "\tpush_context _context.* {\n");
        
        append(*builder, "\t\t");
        for 1..jai_proc_info.return_types.count {
            if it != 1  append(*builder, ", ");
            print_to_builder(*builder, "r%.*", it);
        }
        if jai_proc_info.return_types.count > 0 {
            append(*builder, " = ");
        }
        
        append(*builder, "jai_proc(");
        for jai_proc_info.argument_types {
            if it_index != 0  append(*builder, ", ");
            print_to_builder(*builder, "a%", it_index+1);
            if is_aggr(it)  append(*builder, ".*");  // aggregates get passed by pointer
        }
        append(*builder, ");\n");
        
        if has_context  append(*builder, "\t}\n");
        
        append(*builder, "}\n");
        return builder_to_string(*builder);
    };
    
    return .{ 
        wrapper         = Any_Proc.from(wrapper_proc),
        procedure       = Any_Proc.from(jai_proc),
        context_pointer = _context,
    };
}

/*
    A structure for packaging a generated #c_call wrapper and the jai procedure which it calls.
    This is handy because we there are many situations where one may want the original Type_Info_Procedure,
        since some info is lost about the original procedure when generating the wrapper.
*/
C_Call_Wrapper :: struct {
    wrapper:            Any_Proc;
    procedure:          Any_Proc;
    context_pointer:    *#Context;
}


#load "bindings.jai";
#load "dcaggr.jai";

#scope_module

#assert OS == .WINDOWS; 

#import "Basic";
#import "Utils";

#module_parameters () (ENABLE_COERCIONS: enum { DISABLED :: 0; MINIMAL; EXTENDED; } = .MINIMAL);

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
  case .MINIMAL;  #load "coercion_minimal.jai";
  case .EXTENDED; #load "coercion.jai";
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


// Any type which is not principally register-sized is considered an aggregate type.
// This means all structs and arrays are considered aggregates.
// Aggregates are also those types which are implicitly passed by const reference in Jai procedure calls.
is_aggr :: (t: Type) -> bool { return is_aggr(t.(*Type_Info)); }
is_aggr :: (ti: *Type_Info) -> bool {
    if ti.type == {
        case .INTEGER;   return false;
        case .FLOAT;     return false;
        case .ENUM;      return false;
        case .BOOL;      return false;
        case .POINTER;   return false;
        case .PROCEDURE; return false;
        case .TYPE;      return false;
    }
    return true;
}
