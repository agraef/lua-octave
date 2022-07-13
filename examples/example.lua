
-- need this to print table values (available from LuaRocks, source at
-- https://github.com/kikito/inspect.lua)
inspect = require("inspect")

-- load the Octave interface
oct = require("octave")

-- NOTE: the Octave interpreter gets initialized automatically on the first
-- call to `eval`, at which time Octave's initialization files get executed.

-- Declare Octave's ans variable as global so that we can access it on the Lua
-- side - see the get/set examples below for explanation. We do this here
-- before doing any calculations in order to prevent a warning about ans being
-- declared global after its first use.
oct.eval("global ans", 0)

-- evaluate an Octave expression, return the result
a = oct.eval("6*7")
print("a = ", a)

-- set a variable in the Octave interpreter, return that value
x = oct.eval("x = [1,2;3,4]")
print("x = ", inspect(x))

-- eval without a second argument always returns (at most) one result; here,
-- eig() returns the vector of eigenvalues
l = oct.eval("eig(x)")
print("l = ", inspect(l))

-- Some Octave functions may return multiple values, and indeed return
-- different results depending on how many return values are requested. You
-- can specify the desired return count in eval's optional second argument, in
-- which case eval will return (at most) the given number of results. Note
-- that this value is only advisory; the actual number of return values may
-- vary depending on the function at hand.

-- E.g., when 3 return values are requested, eig() returns three matrices
-- v,d,w instead. (v and w are the left and right eigenvectors, d ist a
-- diagonal matrix containg the eigenvalues, please check `help eig` in Octave
-- for details.)
v,d,w = oct.eval("eig(x)", 3)
print("v = ", inspect(v))
print("d = ", inspect(d))
print("w = ", inspect(w))

-- When in doubt, you can just request a large number of return values, store
-- them in a Lua table, and check the size of that table to determine how many
-- results you got:
t = {oct.eval("eig(x)", 99)}
print("#t = ", #t)
print("t = ", inspect(t))

-- Specifying zero return values switches the interpreter to "command mode",
-- in which special commands such as `global`, `help`, and `source` can be
-- executed, which wouldn't work with a plain `eval`.

oct.eval("global lambda = eig(x)", 0)

-- On the Lua side, numeric values can be either numbers, or tables (of
-- tables) of numbers, such as 99 (scalar), {15,9} (vector), or {{1,2},{3,4}}
-- (2x2 matrix). These will be interpreted as Octave scalars, vectors or
-- matrices, respectively. Any such values may also be returned as evaluation
-- results by `eval` (as well as `feval`, `get`, and `set` discussed below).

-- Functions can also be invoked directly by their name, specifying parameters
-- as extra arguments to `feval` which is invoked as `feval(name,nret,...)`.
-- Note that in this case, the requested number of return values *must* be
-- given as the second argument, before the remaining arguments to be passed
-- to the Octave function.

g = oct.feval("gcd", 1, {15,27}, {20,18})
print("g = ", inspect(g))

-- feval can also be called with just the function name in the case of a
-- parameterless function, e.g.:
r = oct.feval("rand") -- single random number in the 0-1 range
print("r = ", r)
-- the return count (1 in this example) *must* be given in the 2nd argument if
-- there are any parameters
r = oct.feval("rand", 1, 1, 3) -- 1x3 result (row vector)
print("r = ", inspect(r))

-- feval can also take strings as arguments and return them as results. The
-- same is true for eval, set, and get. This is there to accommodate cases in
-- which an Octave function may take or return string values, e.g.:
print("seed = ", oct.feval("rand", 1, "seed"))
print("eig = \n" .. oct.eval("disp(eig(x))"))

-- Octave code can call back into Lua by means of the `lua_call` builtin.
-- Again, all arguments and results must be numeric (scalars, vectors,
-- matrices) or strings. Lua functions may return multiple results. One quirk
-- here is that the function name in the 1st argument *must* be a Lua value in
-- the global environment, i.e., `lua_call` will *not* go out and find
-- functions in other modules such as `math.exp`. Thus, if you want to use
-- such functions, you'll have to bind them in the global environment, e.g.:

exp = math.exp
e = oct.eval("lua_call('exp', 1)")
print("e = ", e) -- prints e = 2.71828...

-- Global variables can be set and retrieved with either `eval` or `set` and
-- `get`. However, in order to exchange global variables between Lua and
-- Octave, they *must* be declared global, e.g.:
oct.eval("global ans", 0) -- this must be executed in command mode
-- this executes eig() in command mode in which the result is printed and
-- stored in ans; we can then access that value on the Lua side with get()
oct.eval("eig(x)", 0)
print("ans = ", inspect(oct.get("ans")))
-- `set` uses the same kind of numeric (scalar, vector, or matrix) values as
-- `feval` in its second argument.
oct.set("ans", {1,2,3})
print("ans = ", inspect(oct.get("ans")))
-- note that this really changes the value of ans on the Octave side:
oct.eval("ans", 0)
-- string values are also supported
oct.set("ans", "abc")
print("ans = ", oct.get("ans"))

-- Application example: multidimensional scaling using the SMACOF algorithm.

-- Execute a `source` command to load the scale.m script file which implements
-- the algorithm. This must be executed in command mode.
oct.eval("source scale.m", 0)

-- Set the input metric for the algorithm.
M = {{0,13.0666666666667,8.33333333333333,10.0666666666667,8.4,4.66666666666667,16.7333333333333,3.66666666666667,9.4,9.06666666666667,9.33333333333333,12.0666666666667,1.0},{13.0666666666667,0,21.4,8.33333333333333,21.4666666666667,8.4,29.8,16.7333333333333,3.66666666666667,16.8,9.06666666666667,25.1333333333333,12.0666666666667},{8.33333333333333,21.4,0,13.0666666666667,12.7333333333333,13.0,8.4,4.66666666666667,17.7333333333333,17.4,17.6666666666667,9.06666666666667,9.33333333333333},{10.0666666666667,8.33333333333333,13.0666666666667,0,18.4666666666667,12.7333333333333,21.4666666666667,8.4,4.66666666666667,19.1333333333333,17.4,16.8,9.06666666666667},{8.4,21.4666666666667,12.7333333333333,18.4666666666667,0,13.0666666666667,8.33333333333333,10.0666666666667,17.8,4.66666666666667,17.7333333333333,3.66666666666667,9.4},{4.66666666666667,8.4,13.0,12.7333333333333,13.0666666666667,0,21.4,8.33333333333333,10.0666666666667,8.4,4.66666666666667,16.7333333333333,3.66666666666667},{16.7333333333333,29.8,8.4,21.4666666666667,8.33333333333333,21.4,0,13.0666666666667,26.1333333333333,13.0,26.0666666666667,4.66666666666667,17.7333333333333},{3.66666666666667,16.7333333333333,4.66666666666667,8.4,10.0666666666667,8.33333333333333,13.0666666666667,0,13.0666666666667,12.7333333333333,13.0,8.4,4.66666666666667},{9.4,3.66666666666667,17.7333333333333,4.66666666666667,17.8,10.0666666666667,26.1333333333333,13.0666666666667,0,18.4666666666667,12.7333333333333,21.4666666666667,8.4},{9.06666666666667,16.8,17.4,19.1333333333333,4.66666666666667,8.4,13.0,12.7333333333333,18.4666666666667,0,13.0666666666667,8.33333333333333,10.0666666666667},{9.33333333333333,9.06666666666667,17.6666666666667,17.4,17.7333333333333,4.66666666666667,26.0666666666667,13.0,12.7333333333333,13.0666666666667,0,21.4,8.33333333333333},{12.0666666666667,25.1333333333333,9.06666666666667,16.8,3.66666666666667,16.7333333333333,4.66666666666667,8.4,21.4666666666667,8.33333333333333,21.4,0,13.0666666666667},{1.0,12.0666666666667,9.33333333333333,9.06666666666667,9.4,3.66666666666667,17.7333333333333,4.66666666666667,8.4,10.0666666666667,8.33333333333333,13.0666666666667,0}}
oct.eval("global M", 0)
oct.set("M", M)

-- Calculate the multidimensional scaling (an embedding in Euclidean space)
-- along with the error ("stress") of the embedding using the mds function
-- from mds.m (the second argument indicates the requested dimension).
V,s = oct.eval("mds(M, 3)", 2)

-- Print results.
print("\nMDS example:\n")
print(string.format("3D embedding = %s\n", inspect(V)))
print(string.format("stress = %g\n", s))
