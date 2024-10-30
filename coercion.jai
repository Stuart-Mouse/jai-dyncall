
coerce :: (dst: Any, src: Any) -> bool {
    return DP.remap_data(dst, src);
}

// TODO: add to context?
coercion_settings: DP.Conversion_Settings;


#scope_file

DP :: #import "Data_Packer";
