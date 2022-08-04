# Lua Octave module

This module provides a basic interface between Lua and Octave. The operations of this module allow you to evaluate arbitrary expressions in the Octave interpreter, set and retrieve variable values in the interpreter, and invoke Lua callbacks from Octave. So this module provides you with the means to access Octave's vast collection of numeric algorithms, which Lua itself doesn't readily provide.

This is a fairly straightforward port of the corresponding Pure module, see <https://agraef.github.io/pure-docs/pure-octave.html>, with some improvements in the behavior of the `eval` operation. It implements most of the basic operations of that module in Lua, but lacks some of the more advanced functionality (mostly related to Octave's non-numeric data types). A brief synopsis of the available functions can be found below. Please also check the examples folder for some sample Lua scripts showing how to utilize this module.

## Prerequisites

Obviously, you'll need Lua (Lua 5.2 or later should be fine, 5.4 has been tested), and Octave (6.4 and 7.2 have been tested and are known to work, 7.1 doesn't due to a broken interpreter API). Earlier Octave versions might work, but Octave is a *huge* project and its C++ API keeps changing all the time, so your mileage may vary. I've developed and tested this on Linux, porting to Mac and other Unix-based systems shouldn't be too hard, but Windows probably needs work (try mingw).

## Installation

This version comes with a rockspec which lets you conveniently install the module using [luarocks][].

To build and install: `sudo luarocks install lua-octave`

Note that if you already have the source from GitHub, you can also just run `sudo luarocks make` in the source directory instead.

To uninstall: `sudo luarocks remove lua-octave`

The module can also be installed in the usual way if you don't have luarocks, as follows:

To build and install: `make && sudo make install`

To uninstall: `sudo make uninstall`

**NB:** In order to run the examples, you'll also need [inspect][] which can be installed with luarocks (`sudo luarocks install inspect`). Or download inspect.lua and put it into the examples folder so that the Lua interpreter can find it.

[luarocks]: https://luarocks.org/
[inspect]: https://github.com/kikito/inspect.lua

## Synopsis

To load this module: `oct = require("octave")`

`oct.eval(s)`, `oct.eval(s, n)`: Evaluates the expression `s` (a string) in the Octave interpreter, and returns the result. An instance of the interpreter will be created if none is running. The desired number of results can optionally be specified as a second argument. Results must be strings or numeric (i.e., scalars, vectors, and matrices). The latter are represented as numbers and tables on the Lua side, see below for details and examples.

In the Octave interpreter, you can call back to Lua using the Octave `lua_call` builtin which is invoked as `lua_call(f, args, ...)`, where `f` is the name of a Lua function (which must be global), and `args` are the arguments the function is to be invoked with.

`oct.feval(f, n, args, ...)`: Invoke an Octave function named `f` (a string) with the given arguments and return (at most) the given number of results. Note that here the return count `n` *must* be specified as the second argument, unless the Octave function doesn't take any arguments at all.

`oct.set(var, val)`, `oct.get(var)`: Set and get global Octave variables containing string or numeric (scalar, vector, and matrix) data.

## Notes

By default, `eval` returns (at most) one result. This is consistent with the way the interactive command line in Octave works. For instance, the Octave `eig` function will return the vector of eigenvalues:

~~~lua
oct.eval("x = [1,2;3,4]")
l = oct.eval("eig(x)")
~~~

The number of results to be returned can also be specified as an optional second argument. In fact, some Octave functions may return different results depending on the given return count. E.g.,  if you request three results from `eig`, you'll get a tuple with three matrices which can be bound to variables in Lua as follows:

~~~lua
v,d,w = oct.eval("eig(x)", 3)
~~~

You might also collect all results in a Lua table like this:

~~~lua
t = {oct.eval("eig(x)", 3)}
#t -- number of results actually returned by eval
inspect(t) -- print the table
~~~

(As already mentioned, we recommend that you install [inspect][] which makes it easy to get a human-readable representation of tables like these. You'll really need this when dealing with Octave's matrix results.)

Finally, specifying a zero return count switches the interpreter to "command mode", in which special Octave commands such as `global`, `help`, and `source` become available. (See the discussion of `get` and `set` below for an example.)

On the Lua side, numeric values can be either numbers, or tables (of tables) of numbers, such as `99` (a scalar), `{15,9}` (a vector), or `{{1,2},{3,4}}` (a 2x2 matrix). These will be marshaled to Octave scalars, row vectors, and matrices, respectively, when passed to Octave using `feval` or `set`. Any such values may also be returned as results by `eval`, `feval`, `set`, and `get`.

For convenience, all vectors are represented as tables of numbers on the Lua side, so Octave column vectors will effectively become row vectors when returned to Lua. But you can easily convert such a row vector back to a column vector on the Octave side by employing Octave's `'` (or `.'`) operator, which provides a quick means to pass proper column vectors as parameters to Octave functions if needed.

The interface also has limited support for passing strings between Lua and Octave, as these are sometimes used as Octave function arguments and results. That is, both `feval` and `set` may take string arguments, and all of the interface functions may return string values as results. Note that this only covers simple string values (no string tables or other similar aggregates). For instance:

~~~lua
oct.feval("rand", 0, "seed", 99) -- set and ...
oct.feval("rand", 1, "seed") -- ... get the seed of the random number generator
oct.eval("disp(eig(x))") -- return display string for a vector result
~~~

At present, these are the only types of Octave values which are supported by the module. If you need to call Octave functions which take other types of parameters, you'll either have to call them through an Octave wrapper function which supplies the needed parameters, or assign the special values to global variables on the Octave side.

In order to exchange global variable values between Lua and Octave via `set` and `get`, you have to make sure that the variable names are also declared `global` (using the corresponding Octave command). If you don't do this, variables created on the Lua side won't be visible in Octave, and vice versa. E.g., you can access the value of Octave's built-in `ans` variable like so:

~~~lua
oct.eval("global ans", 0) -- this must be executed in command mode
oct.eval("eig(x)", 0) -- Octave prints the result and stores it in ans
oct.get("ans") -- returns the computed vector as a Lua table
~~~

Another quirk of the present implementation is that, when using `lua_call(f, args, ...)` to call back from Octave into Lua, the function name `f` must denote a function value *in the global environment*, which excludes functions found in other Lua modules such as `math`. The remedy in this case is to just call such functions through a proxy or wrapper function, e.g.:

~~~lua
exp = math.exp
e = oct.eval("lua_call('exp', 1)") -- Octave code calling the Lua exp function
print("e = ", e) -- prints e = 2.71828...
~~~

