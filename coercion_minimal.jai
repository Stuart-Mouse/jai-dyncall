    
/*
    This file will only be included if ENABLE_EXPANDED_COERCION_CAPABILITIES is false.
    
    Defines a minimal implementation of coerce which only handles numeric type conversions 
        and coercion of fixed/dynamic arrays to array views.
    We don't even do int-to-float or vice versa here.
        
    This minimal implementation aims just to cover the sort of implicit coercions that Jai already does internally. 
    
    There is a little bit of global configuration that you can set to restrict/permit narrowing conversions to occur implicitly.
    I have set these to be allowed by default, because...
        1. it is convenient in many cases (e.g. calling C procedures where the default int size is 32 bit)
        2. you will still get a runtime error in debug if some value ends up out-of-range
*/

// for now its just a global constant...  maybe should be put into context?
ALLOW_NARROWING_COERCIONS :: true;

coerce :: (dst: Any, src: Any) -> bool {
    if dst.type.type != src.type.type  return false;
    
    if dst.type.type == {
      case .INTEGER;
        src_ti := cast(*Type_Info_Integer) src.type;
        dst_ti := cast(*Type_Info_Integer) dst.type;
        
        if !ALLOW_NARROWING_COERCIONS && is_narrowing_int(dst_ti, src_ti)  return false;
        
        // if both are u64, then using s64 as an intermediate (as we do below) is problematic
        if src_ti == type_info(u64) && dst_ti == type_info(u64) {
            dst.value_pointer.(*u64).* = src.value_pointer.(*u64).*;
            return true;
        }
        
        // all other cases we can use s64 as an intermediate and then we don't have to do the combinatorics
        // still have to switch on signedness though...
        s64_value: s64;
        if src_ti.signed {
            if src.type.runtime_size == {
              case 1; s64_value = src.value_pointer.(*s8 ).*.(s64);
              case 2; s64_value = src.value_pointer.(*s16).*.(s64);
              case 4; s64_value = src.value_pointer.(*s32).*.(s64);
              case 8; s64_value = src.value_pointer.(*s64).*.(s64);
            }
        } else {
            if src.type.runtime_size == {
              case 1; s64_value = src.value_pointer.(*u8 ).*.(s64);
              case 2; s64_value = src.value_pointer.(*u16).*.(s64);
              case 4; s64_value = src.value_pointer.(*u32).*.(s64);
              case 8; s64_value = src.value_pointer.(*u64).*.(s64);
            }
        }
        
        if dst_ti.signed {
            if dst.type.runtime_size == {
              case 1; dst.value_pointer.(*s8 ).* = s64_value.(s8 );
              case 2; dst.value_pointer.(*s16).* = s64_value.(s16);
              case 4; dst.value_pointer.(*s32).* = s64_value.(s32);
              case 8; dst.value_pointer.(*s64).* = s64_value.(s64);
            }
        } else {
            if dst.type.runtime_size == {
              case 1; dst.value_pointer.(*u8 ).* = s64_value.(u8 );
              case 2; dst.value_pointer.(*u16).* = s64_value.(u16);
              case 4; dst.value_pointer.(*u32).* = s64_value.(u32);
              case 8; dst.value_pointer.(*u64).* = s64_value.(u64);
            }
        }
        return true;
        
      case .FLOAT;
        src_ti := src.type.(*Type_Info_Integer);
        dst_ti := dst.type.(*Type_Info_Integer);
        
        if !ALLOW_NARROWING_COERCIONS && src_ti.runtime_size > dst_ti.runtime_size  return false;
        
        // kind of silly to even use an intermediate here...
        f64_value: float64;
        if src.type.runtime_size == {
            case 4; f64_value = src.value_pointer.(*float32).*.(float64);
            case 8; f64_value = src.value_pointer.(*float64).*.(float64);
        }
        if dst.type.runtime_size == {
            case 4; dst.value_pointer.(*float32).* = f64_value.(float32);
            case 8; dst.value_pointer.(*float64).* = f64_value.(float64);
        }
        return true;
        
      case .ARRAY;
        src_ti := src.type.(*Type_Info_Array);
        dst_ti := dst.type.(*Type_Info_Array);
        
        if dst_ti.array_type   != .VIEW                // we only allow coercing from resizable or fixed arrays into array views
        || dst_ti.element_type != src_ti.element_type  // and of course, the element type here needs to match
            return false;
            
        dst_array: Array_View_64;
        if src_ti.array_type == {
          case .RESIZABLE;
            dst_array = src.value_pointer.(*Array_View_64); // Array_View_64 and Resizable_Array are spec'd to line up
            return true;
            
          case .FIXED;
            dst_array = .{ src_ti.array_count, src.value_pointer };
            return true;
        }
    }
    
    // an asumption of calling coerce is that we actually need to do 
    // some kind of coercion in the first place (refer to maybe_coerce)
    return false;
}

#scope_file

is_narrowing_int :: (dst_ti: *Type_Info_Integer, src_ti: *Type_Info_Integer) -> bool {
    if src_ti.runtime_size > dst_ti.runtime_size  return true;
    if src_ti.signed {
        if !dst_ti.signed  return true;
    } else {
        if dst_ti.signed && src_ti.runtime_size == dst_ti.runtime_size  return true;
    }
    return false;
}
