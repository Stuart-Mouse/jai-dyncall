
# jai-dyncall

This module provides bindings and some convenient wrapper functions for dyncall: https://dyncall.org/
We also provide support for dynamically calling Jai procedures, but this is contingent on use of the LLVM backend, and its possible that future compiler changes could break compatibility.
I plan to keep this module up-to-date to provide a workaround in the case that Jai procedure calls are broken, but it's something I felt I should mention.


## Dependencies

This module depends on my Utils module (sorry): https://github.com/Stuart-Mouse/jai-utils
I use this Utils module for many functions which are common across my other modules.


## Convenience Functions

In addition to the basic argument-pushing functions provided by dyncall, this module includes a generic push_argument() procedure that will take an Any, automatically typecheck the argument, and push it as the proper type.
Accordingly, there's also a push_arguments procedure that will take a `[] Any` and a `*Type_Info_Procedure`


The basic datatypes provided by dyncall are aliased here using explicitly-sized names. For example:
```
DCint8        :: DCchar;
DCint16       :: DCshort;
DCint32       :: DCint;
DCint64       :: DClonglong;

DCfloat32     :: DCfloat;
DCfloat64     :: DCdouble;
```


DCAggr objects do not need to be manually created and managed by the user. 
Instead, the module itself maintains a table of registered DCAggr objects that managed and used as needed by the generic push_argument() procedure.


The module also provides support for automatic type coercion on arguments.
The user can opt for either the minimal implementation that is included with this module, or can activate more extensive type coercion through integration with my Data Packer module.
This Data Packer module includes extensive functions for dynamic type-casting and struct remapping, and can be used from jai-dyncall with the toggle of a single module parameter.
