
coerce :: (dst: Any, src: Any) -> bool {
    return Convert.remap_data(dst, src,, data_packer = .{ conversion_settings = *coercion_settings });
}

coercion_settings: Convert.Conversion_Settings;


#scope_file

Convert :: #import "Convert";
