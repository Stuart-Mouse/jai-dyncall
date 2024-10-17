
/*
    This is all still completely to-do.
    
    I am not yet sure how to (or if I will at all) go about implementing type coercions on return values.
    I think perhaps that is best left up to the user to handle. 
    And they should have a pretty good idea how to do that if they refer to the implementation here.
    
    The 'coerce' procedure here is just used as a thin interface to procedures in the Data_Packer module.
    So if you want to actually see what is being done behind the scenes, you should go refer to the 'coercion.jai' file from that module.
*/

coerce :: (dst: Any, src: Any) -> bool
    // TODO:
    return xx 0, bool 
}

#scope_file

DP :: #import "Data_Packer";
