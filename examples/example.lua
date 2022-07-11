
-- need this to print table values (available from LuaRocks)
inspect = require("inspect")

-- load the Octave interface
oct = require("octave")

-- evaluate an Octave expression, return the result(s)
-- NOTE: the Octave interpreter gets initialized automatically on the first
-- call to `eval`, at which time Octave's initialization files get executed.
a = oct.eval("6*7")
print("a = ", a)

-- set a variable in the Octave interpreter, return that value
x = oct.eval("x = [1,2;3,4]")
print("x = ", inspect(x))

-- eval without a second argument always returns the max number of results (up
-- to 256); here, eig() returns three matrix results
b1,b2,b3 = oct.eval("eig(x)")
print("b1 = ", inspect(b1))
print("b2 = ", inspect(b2))
print("b3 = ", inspect(b3))

-- specifying 1 return value only returns the first result (just the vector of
-- eigenvalues in this case)
c = oct.eval("eig(x)", 1)
print("c = ", inspect(c))

-- Specifying zero return values switches the interpreter to "command mode",
-- in which special commands such as `global`, `help`, and `source` can be
-- executed, which wouldn't work with a plain `eval`.

--oct.eval("help eig", 0)

-- Functions can also be invoked directly by their name, specifying parameters
-- as extra arguments to `feval` which is invoked as `feval(name,nret,...)`.
-- Note that in this case, the requested number of return values *must* be
-- given as the second argument, before the remaining numeric arguments to be
-- passed to the Octave function.

-- On the Lua side, numeric values can be either numbers, or tables (of
-- tables) of numbers, such as 99 (scalar), {15,9} (vector), or {{1,2},{3,4}}
-- (2x2 matrix). These will be interpreted as Octave scalars, vectors or
-- matrices, respectively. Any such values may also be returned as evaluation
-- results by `feval` or `eval`.

d = oct.feval("gcd", 1, {15,27}, {20,18})
print("d = ", inspect(d))

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
print("eig = \n" .. oct.eval("disp(eig([1,2;3,4]))"))

-- Octave code can call back into Lua by means of the `lua_call` builtin.
-- Again, all arguments and results must be numeric (scalars, vectors,
-- matrices). Lua functions may return multuple results. One quirk here is
-- that the function name in the 1st argument *must* be a Lua value in the
-- global environment, i.e., `lua_call` will *not* go out and find functions
-- in other modules such as `math.exp`. Thus, if you want to use such
-- functions, you'll have to bind them in the global environment, e.g.:

exp = math.exp
e = oct.eval("lua_call('exp', 1)")
print("e = ", e) -- prints e = 2.71828...

-- Global variables can be set and retrieved with either `eval` or `set` and
-- `get`. However, in order to exchange global variables between Lua and
-- Octave, they *must* be declared global, e.g.:
oct.eval("global A = [1,2;3,4]", 0) -- must use command mode here
print("A = ", inspect(oct.get("A")))
-- `set` uses the same kind of numeric (scalar, vector, or matrix) values as
-- `feval` in its second argument.
oct.set("A", 99)
print("A = ", oct.get("A"))
 -- 2nd arg may also be a vector or matrix
oct.set("A", {1,2,3})
print("A = ", inspect(oct.get("A")))

-- Application example: multidimensional scaling using the SMACOF algorithm.

-- Execute a `source` command to load the scale.m script file which implements
-- the algorithm.
oct.eval("source scale.m", 0)

-- Set the input metric for the algorithm.
M = {{0,13.0666666666667,8.33333333333333,10.0666666666667,8.4,4.66666666666667,16.7333333333333,3.66666666666667,9.4,9.06666666666667,9.33333333333333,12.0666666666667,1.0},{13.0666666666667,0,21.4,8.33333333333333,21.4666666666667,8.4,29.8,16.7333333333333,3.66666666666667,16.8,9.06666666666667,25.1333333333333,12.0666666666667},{8.33333333333333,21.4,0,13.0666666666667,12.7333333333333,13.0,8.4,4.66666666666667,17.7333333333333,17.4,17.6666666666667,9.06666666666667,9.33333333333333},{10.0666666666667,8.33333333333333,13.0666666666667,0,18.4666666666667,12.7333333333333,21.4666666666667,8.4,4.66666666666667,19.1333333333333,17.4,16.8,9.06666666666667},{8.4,21.4666666666667,12.7333333333333,18.4666666666667,0,13.0666666666667,8.33333333333333,10.0666666666667,17.8,4.66666666666667,17.7333333333333,3.66666666666667,9.4},{4.66666666666667,8.4,13.0,12.7333333333333,13.0666666666667,0,21.4,8.33333333333333,10.0666666666667,8.4,4.66666666666667,16.7333333333333,3.66666666666667},{16.7333333333333,29.8,8.4,21.4666666666667,8.33333333333333,21.4,0,13.0666666666667,26.1333333333333,13.0,26.0666666666667,4.66666666666667,17.7333333333333},{3.66666666666667,16.7333333333333,4.66666666666667,8.4,10.0666666666667,8.33333333333333,13.0666666666667,0,13.0666666666667,12.7333333333333,13.0,8.4,4.66666666666667},{9.4,3.66666666666667,17.7333333333333,4.66666666666667,17.8,10.0666666666667,26.1333333333333,13.0666666666667,0,18.4666666666667,12.7333333333333,21.4666666666667,8.4},{9.06666666666667,16.8,17.4,19.1333333333333,4.66666666666667,8.4,13.0,12.7333333333333,18.4666666666667,0,13.0666666666667,8.33333333333333,10.0666666666667},{9.33333333333333,9.06666666666667,17.6666666666667,17.4,17.7333333333333,4.66666666666667,26.0666666666667,13.0,12.7333333333333,13.0666666666667,0,21.4,8.33333333333333},{12.0666666666667,25.1333333333333,9.06666666666667,16.8,3.66666666666667,16.7333333333333,4.66666666666667,8.4,21.4666666666667,8.33333333333333,21.4,0,13.0666666666667},{1.0,12.0666666666667,9.33333333333333,9.06666666666667,9.4,3.66666666666667,17.7333333333333,4.66666666666667,8.4,10.0666666666667,8.33333333333333,13.0666666666667,0}}
oct.eval("global M", 0)
oct.set("M", M)

-- Calculate the multidimensional scaling (an embedding in Euclidean space)
-- along with the error ("stress") of the embedding using the mds function
-- from mds.m (the second argument indicates the requested dimension).
V,s = oct.eval("mds(M, 3)")

-- Print results.
print("\nMDS example:\n")
print(string.format("3D embedding = %s\n", inspect(V)))
print(string.format("stress = %g\n", s))
