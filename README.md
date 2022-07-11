# Lua Octave module

This module provides a basic interface between Lua and Octave. The operations of this module allow you to evaluate arbitrary expressions in the Octave interpreter, set and retrieve variable values in the interpreter, and invoke Lua callbacks from Octave. Lua itself doesn't come with advanced numeric capabilities such as matrix calculations, so this module provides you with the means to access such facilities through the Octave language instead.

This is a fairly straightforward port of the corresponding Pure module, see <https://agraef.github.io/pure-docs/pure-octave.html>. It implements most of the basic operations of that module in Lua, but lacks some of the more advanced functionality. A brief synopsis of the available functions can be found below. Please also check the examples folder for some sample Lua scripts showing how to utilize this module.

## Installation

This version comes with a rockspec which lets you conveniently install the module using [luarocks](https://luarocks.org/).

To build and install: `sudo luarocks make`

To uninstall: `sudo luarocks remove luaoct`

The module can also be installed in the usual way if you don't have luarocks, as follows:

To build and install: `make && sudo make install`

To uninstall: `sudo make uninstall`

## Synopsis

To load this module: `oct = require("octave")`

`oct.eval(s)`: Evaluates the expression `s` (a string) in the Octave interpreter, and returns results. An instance of the interpreter will be created if none is running.

By default, `eval` tries to grab as many results as possible and returns them all as a tuple. Results must be numeric (i.e., scalars, vectors, and matrices) which are represented as numbers and tables on the Lua side, see below for details and examples. The number of results to be returned can be specified as an optional second argument, e.g., `oct.eval("eig(x)", 1)`. In particular, specifying a zero return count switches the interpreter to "command mode", in which special Octave commands such as `global`, `help`, and `source` can be executed, which wouldn't work with a plain `eval` which only evaluates Octave expressions.

In the Octave interpreter, you can call back to Lua using the Octave `lua_call` builtin which is invoked as `lua_call(f, args, ...)`, where `f` is the name of a Lua function (which must be global), and `args` are the (numeric, i.e., scalar, vector, and matrix) arguments the function is to be invoked with.

`oct.feval(f, n, args, ...)`: Invoke an Octave function named `f` (a string) with the given (numeric) arguments and return (at most) the given number of results. Note that here the return count `n` *must* be specified as the second argument, unless the Octave function doesn't take any arguments at all.

`oct.set(var, val)`, `oct.get(var)`: Set and get global Octave variables containing numeric (scalar, vector, and matrix) data.

## Notes

On the Lua side, numeric values can be either numbers, or tables (of tables) of numbers, such as `99` (a scalar), `{15,9}` (a vector), or `{{1,2},{3,4}}` (a 2x2 matrix). These will be marshaled to Octave scalars, vectors, and matrices, respectively, when passed to Octave using `feval` or `set`. Any such values may also be returned as results by `eval`, `feval`, and `get`.

Note that, for convenience, all vectors are represented as tables of numbers on the Lua side, so Octave column vectors will effectively become row vectors when returned by `eval`, `feval`, or `get`. But note that you can easily convert such a row vector back to a column vector on the Octave side by employing Octave's `transpose` function, which provides a means to pass proper column vectors as parameters to Octave functions if needed.

At present, these are the only types of Octave values which are supported by the module. If you need to call Octave functions which take other types of parameters, such as strings, you'll either have to call them through an Octave wrapper function which supplies the needed parameters, or assign the special values to global variables on the Octave side.

In order to exchange global variable values between Lua and Octave via `set` and `get`, you have to make sure that the variable names are also declared `global` (using the corresponding Octave command). If you don't do this, variables created on the Lua side won't be visible in Octave, and vice versa. E.g., you can access the value of Octave's built-in `ans` variable like so:

~~~lua
oct.eval("global ans", 0)
oct.eval("eig([1,2;3,4])", 0) -- Octave prints the result and stores it in ans
oct.get("ans") -- returns the computed eigenvector as a Lua table
~~~

Another quirk of the present implementation is that, when using `lua_call(f, args, ...)` to call back from Octave into Lua, the function name `f` must denote a function value *in the global environment*, which excludes functions found in other Lua modules such as `math`. The remedy in this case is to just call such functions through a proxy or wrapper function, e.g.:

~~~lua
exp = math.exp
e = oct.eval("lua_call('exp', 1)")
print("e = ", e) -- prints e = 2.71828...
~~~

