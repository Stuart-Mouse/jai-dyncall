
# jai-dyncall

This module provides bindings and some convenient wrapper functions for dyncall: https://dyncall.org/
We also provide support for dynamically calling Jai procedures, but this is contingent on use of the LLVM backend, and its possible that future compiler changes could break compatibility.
I plan to keep this module up-to-date to provide a workaround in the case that Jai procedure calls are broken, but it's something I felt I should mention.


## Dependencies

This module depends on my Utils module (sorry): https://github.com/Stuart-Mouse/jai-utils
I use this Utils module for many functions which are common across my other modules.


## Features

### Better Names for Dyncall Data Types and Procedures

The basic data types and procedures provided by dyncall are aliased here using explicitly-sized names:
```
DCint8        :: DCchar;
DCint16       :: DCshort;
DCint32       :: DCint;
DCint64       :: DClonglong;

DCfloat32     :: DCfloat;
DCfloat64     :: DCdouble;

dcCallInt8    :: dcCallChar;
dcCallInt16   :: dcCallShort;
dcCallInt32   :: dcCallInt;
dcCallInt64   :: dcCallLongLong;

dcCallFloat32 :: dcCallFloat;
dcCallFloat64 :: dcCallDouble;
```

### Automating Dyncall with Reflection

If using the Dyncall bindings directly, the user will be required to manually set up the Dyncall virtual machine, push arguments properly, and set up DCaggr objects for all struct and array types.
This module automates all of that away by using Jai's runtime type information to push arguments and generate DCaggrs automatically.
All that the user needs to do is provide the DCCallVM object, the procedure pointer (as an Any), and an array of Any's for the arguments and return values.
All arguments and return values will be automatically runtime type-checked, and if enabled, arguments may even be automatically coerced from one type to another where possible.

DCAggr objects do not need to be manually created and managed by the user. 
Instead, the module itself maintains a table of registered DCAggr objects that are managed and used as needed by the generic push_argument() procedure.

The module also provides support for automatic type coercion on arguments.
The user can opt for either the minimal implementation that is included with this module, or can activate more extensive type coercion through integration with my `Convert` module.
This Data Packer module includes extensive functions for dynamic type-casting and struct remapping, and can be used from jai-dyncall with the toggle of a single module parameter.


### Generate #c_call Wrappers for Jai Procedures

Because Jai does not yet have a stable or well-defined calling convention, calling native Jai procedures with Dyncall is only partially supported (LLVM backend only) and could potentially break with a future version of the compiler.
In order to work around these limitations, this module provides a way to generate #c_call wrapper procedures which can be used to indirectly call native Jai procedures.
While this solution is not ideal, it should allow users to enjoy at least a subset of Dyncall's functionality with native Jai procedures.
Hopefully, the Jai compiler will one day adhere to a standardized calling convention or, better yet, expose its own Dyncall-like functionality through the Compiler module.
