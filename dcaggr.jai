// ========== DCaggr Objects ==========

/*    
    We keep one big lookup table of all the aggr objects we've built, 
        so that we don't have to re-construct them every time.
    These get built automatically from type info.
*/

DCaggr_lookup_table := ([..] struct { info: *Type_Info; aggr: *DCaggr; }).{ allocator = Context_Base.default_allocator };

make_DCaggr :: (info: *Type_Info) -> *DCaggr {
    if info.type == {
      case .ARRAY;
        ti_array := cast(*Type_Info_Array) info;
        if ti_array.array_type == .FIXED {
            return _make_DCaggr_array(cast(*Type_Info_Array)info);
        }
      case .STRUCT;
        return _make_DCaggr_struct(cast(*Type_Info_Struct)info);
    }
    log("Error: Invalid type given in make_DCaggr!\n");
    return null;
}

register_DCaggr :: inline (info: *Type_Info, aggr: *DCaggr) {
    if !info || !aggr {
        log("Error: Attempted to register invalid DCaggr\n");
        return;
    }
    array_add(*DCaggr_lookup_table, .{ info, aggr });
}

find_DCaggr :: inline (info: *Type_Info) -> *DCaggr {
    for DCaggr_lookup_table  if it.info == info  return it.aggr;
    return null;
}

// I basically just use this one procedure everywhere that I deal with DCAggr objects internally.
// I haven't needed to use the above procedures directly, but they are still exposed to the user.
// But if you really want to deal with the DCaggr objects yourself then chances are you'd not be using this module in the first place.
find_or_make_and_register_DCaggr :: (info: *Type_Info) -> *DCaggr {
    aggr := find_DCaggr(info);
    if !aggr {
        aggr = make_DCaggr(info);
        register_DCaggr(info, aggr);
    }
    return aggr;
}

#scope_file

/*
    In general, we want to avoid making DCaggr objects for fixed array types.
    We could avoid this altogether if only supporting the C calling convention, but Jai allows for passing fixed size arrays, 
        and I want to be feature complete here even if it means having some less than ideal code.
    If fixed arrays are within a struct, then we don't need to call into this proc because we can pass an array count.
    But if the array is the top-level type so-to-speak, then we need to make a DCaggr for it.
    Maybe in the future I can come up with some better way to minimize the need for this further...
*/
_make_DCaggr_array :: (info: *Type_Info_Array) -> *DCaggr {
    aggr := dcNewAggr(cast(u64)info.array_count, cast(u64)info.runtime_size);
    success := false;
    defer if !success dcFreeAggr(aggr);
    
    // basically a DCaggr struct, but with only one member (the fixed size array)
    if !_add_DCaggr_field(aggr, info, 0)  return null;
    
    dcCloseAggr(aggr);
    success = true;
    return aggr;
}

_make_DCaggr_struct :: (info: *Type_Info_Struct) -> *DCaggr {
    aggr := dcNewAggr(cast(u64)info.members.count, cast(u64)info.runtime_size);
    success := false;
    defer if !success dcFreeAggr(aggr);
    
    last_offset := 0; // hacky fix to skip adding fields with #place directives, as dyncall doesn't seem to like overlapping fields in a struct definition (reasonably so)
    for info.members {
        if it.flags & .CONSTANT  continue;
        if it.offset_in_bytes < last_offset  continue; 
        
        if !_add_DCaggr_field(aggr, it.type, it.offset_in_bytes)  return null;
        
        last_offset = it.offset_in_bytes + it.type.runtime_size;
    }
    
    dcCloseAggr(aggr);
    success = true;
    return aggr;
}

_add_DCaggr_field :: (aggr: *DCaggr, info: *Type_Info, offset_in_bytes: int) -> bool {
    sigchar  : DCsigchar = 0;
    arrcount : DCsize    = 1;
    
    // Handle fixed-size arrays by multiplying arrcount, updating elem_type
    elem_type := info;
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
        
        dcAggrField(aggr, DC_SIGCHAR_AGGREGATE, cast(s32)offset_in_bytes, arrcount, ag_nested);
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
        dcAggrField(aggr, DC_SIGCHAR_AGGREGATE, cast(s32)offset_in_bytes, arrcount, ag_array);
        return true; // We don't want to run the common case below.
    }
    
    // Common case for primitive types, no need to duplicate the call up in each case.
    assert(sigchar != 0, "Sigchar was not assigned a value!");
    dcAggrField(aggr, sigchar, cast(s32)offset_in_bytes, arrcount);
    return true;
}
