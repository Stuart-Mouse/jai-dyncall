    
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

// for now its just a global constant...
ALLOW_NARROWING_COERCIONS :: true;

coerce :: (dst: Any, src: Any) -> bool {
    if dst.type.type != src.type.type  return false;
    
    if dst.type.type == {
      case .INTEGER;
        ti_src := cast(*Type_Info_Integer) src.type;
        ti_dst := cast(*Type_Info_Integer) dst.type;
        
        if !ALLOW_NARROWING_COERCIONS {
            if ti_src.runtime_size > ti_dst.runtime_size  return false;
            if ti_src.signed {
                if !it_dst.signed  return false;
            } else {
                if it_dst.signed && ti_src.runtime_size = ti_dst.runtime_size  return false;
            }
        }
    
        // if both are u64, then using s64 as an intermediate (as we do below) is problematic
        if ti_src == type_info(u64) && ti_dst == type_info(u64) {
            (cast(*u64)dst.value_pointer).* = (cast(*u64)src.value_pointer).*;
            return true;
        }
        
        // all other cases we can use s64 as an intermediate and then we don't have to do the combinatorics
        s64_value: s64;
        if src.type.runtime_size == {
            case  1; s64_value = cast(s64) (cast(*s8  )src.value_pointer).*;
            case  2; s64_value = cast(s64) (cast(*s16 )src.value_pointer).*;
            case  4; s64_value = cast(s64) (cast(*s32 )src.value_pointer).*;
            case  8; s64_value = cast(s64) (cast(*s64 )src.value_pointer).*;
        }
        if dst.type.runtime_size == {
            case  1; (cast(*s8 )dst.value_pointer).* = cast(s8 ) s64_value;
            case  2; (cast(*s16)dst.value_pointer).* = cast(s16) s64_value;
            case  4; (cast(*s32)dst.value_pointer).* = cast(s32) s64_value;
            case  8; (cast(*s64)dst.value_pointer).* = cast(s64) s64_value;
        }
        return true;
        
      case .FLOAT;
        ti_src := cast(*Type_Info_Integer) src.type;
        ti_dst := cast(*Type_Info_Integer) dst.type;
        
        if !ALLOW_NARROWING_COERCIONS && ti_src.runtime_size > ti_dst.runtime_size  return false;
        
        // kind of silly to even use an intermediate here...
        f64_value: float64;
        if src.type.runtime_size == {
            case 4; f64_value = cast(float64) (cast(*float32)src.value_pointer).*;
            case 8; f64_value = cast(float64) (cast(*float64)src.value_pointer).*;
        }
        if dst.type.runtime_size == {
            case 4; (cast(*float32)dst.value_pointer).* = cast(float32) f64_value;
            case 8; (cast(*float64)dst.value_pointer).* = cast(float64) f64_value;
        }
        return true;
        
      case .ARRAY;
        ti_src := cast(*Type_Info_Array) src.type;
        ti_dst := cast(*Type_Info_Array) dst.type;
        
        if ti_dst.array_type   != .VIEW                // we only allow coercing from resizable or fixed arrays into array views
        || ti_dst.element_type != ti_src.element_type  // and of course, the element type here needs to match
            return false;
            
        dst_array: Array_View_64;
        
        if ti_src.array_type == {
          case .RESIZABLE;
            dst_array = cast(*Array_View_64) src.value_pointer; // Array_View_64 and Resizable_Array are spec'd to line up
            return true;
            
          case .FIXED;
            dst_array = .{ ti_src.array_count, src.value_pointer };
            return true;
        }
    }
    
    // an asumption of calling coerce is that we actually need to do 
    // some kind of coercion in the first place (refer to maybe_coerce)
    return false;
}
