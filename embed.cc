
#include <iostream>
#include <octave/oct.h>
#include <octave/octave.h>
#include <octave/parse.h>
#include <octave/interpreter.h>

#include "embed.h"

/* Interface to the Octave interpreter. */

octave::interpreter interpreter;
bool first_init = false;
int interpreter_status = 0;

static void install_builtins();

static lua_State *_L;

static bool oct_init(lua_State *L)
{
  if (first_init) return interpreter_status == 0;
  first_init = true;
  install_builtins();
  _L = L;
  try {
    // Inhibit reading history file by calling
    //
    //   interpreter.initialize_history (false);

    // Set custom load path here if you wish by calling
    //
    //   interpreter.initialize_load_path (false);

    // Perform final initialization of interpreter, including
    // executing commands from startup files by calling
    //
    //   interpreter.initialize ();
    //
    //   if (! interpreter.initialized ())
    //     {
    //       std::cerr << "Octave interpreter initialization failed!"
    //                 << std::endl;
    //       exit (status);
    //     }
    //
    // You may skip this step if you don't need to do anything
    // between reading the startup files and telling the interpreter
    // that you are ready to execute commands.

    // Tell the interpreter that we're ready to execute commands:

    interpreter_status = interpreter.execute ();
  } catch (const octave::exit_exception& ex) {
    std::cerr << "Octave interpreter exited with status = "
	      << ex.exit_status () << std::endl;
    interpreter_status = -1;
  } catch (const octave::execution_exception& ex) {
    //std::cerr << "error encountered in Octave evaluator!" << std::endl;
    interpreter.handle_exception(ex);
    interpreter_status = -2;
  }

  return interpreter_status == 0;
}

/* Marshalling between Octave and Lua values (real scalars and matrices only
   for now). */

static bool octave_to_lua(lua_State *L, const octave_value& v)
{
  // this should catch all (complex and real) scalars and matrix values
  if (!(v.is_defined() && v.ndims() == 2 && v.is_double_type()))
    return false;
  // XXXTODO: since Lua has no built-in complex number type, we don't handle
  // complex Octave matrices right now.
  if (v.iscomplex())
    return false;
  // convert to a Lua value (number or table), push on top of the Lua stack
  dim_vector dim = v.dims();
  size_t k = dim(0), l = dim(1);
  Matrix M = v.matrix_value();
  //std::cout << M << std::endl;
  if (k == 0 || l == 0) {
    // empty matrix, return as empty table
    lua_createtable(L, 0, 0);
  } else if (k == 1 && l == 1) {
    // this could be a scalar or an actual 1x1 matrix (Octave doesn't
    // distinguish these), return as a single number
    double x = M(0,0);
    lua_pushnumber(L, x);
  } else if (k == 1 || l == 1) {
    // a row or column vector, return as a table
    lua_createtable(L, k*l, 0);
    for (int i = 0; i < k; i++)
      for (int j = 0; j < l; j++) {
	double x = M(i,j);
	lua_pushinteger(L, i*l+j+1);
	lua_pushnumber(L, x);
	lua_settable(L, -3);
      }
  } else {
    // everything else (general matrix), return as a table of tables
    // (table of row vectors, i.e., row-major order; note that Octave
    // actually keeps matrix data in column-major format internally
    // for Fortran compatibility)
    lua_createtable(L, k, 0);
    for (int i = 0; i < k; i++) {
      lua_pushinteger(L, i+1);
      lua_createtable(L, l, 0);
      for (int j = 0; j < l; j++) {
	double x = M(i,j);
	lua_pushinteger(L, j+1);
	lua_pushnumber(L, x);
	lua_settable(L, -3);
      }
      lua_settable(L, -3);
    }
  }
  return true;
}

static bool lua_to_octave(lua_State *L, octave_value& v)
{
  // value to be converted is assumed to be at the top of the stack
  if (lua_isnumber(L, -1)) {
    double x = lua_tonumber(L, -1);
    v = octave_value(x);
    return true;
  } else if (lua_istable(L, -1)) {
    int k = lua_rawlen(L, -1), l = -1;
    // traverse the table once, to determine the column size and make sure
    // that all the dimensions match up and that all the table cells contain
    // numeric data
    lua_pushnil(L);
    while (lua_next(L, -2) != 0) {
      if (lua_isnumber(L, -1)) {
	if (l < 0)
	  l = 1;
	else if (l != 1) {
	  lua_pop(L, 2);
	  return false;
	}
      } else if (lua_istable(L, -1)) {
	int m = lua_rawlen(L, -1);
	if (l < 0)
	  l = m;
	else if (l != m) {
	  lua_pop(L, 2);
	  return false;
	}
	lua_pushnil(L);
	while (lua_next(L, -2) != 0) {
	  if (!lua_isnumber(L, -1)) {
	    lua_pop(L, 4);
	    return false;
	  }
	  lua_pop(L, 1);
	}
      }
      lua_pop(L, 1);
    }
    // Massage the dimensions to something reasonable based on the Lua table
    // data we've been given. For sanity, we just assume the user wants either
    // an empty matrix (0x0), a row vector (1xl), or a proper kxl matrix with
    // k>1 rows and l>1 columns. The following checks enforce those rules.
    if (l == 1) {
      // turn into a row vector
      l = k; k = 1;
    } else if (l < 0) {
      // empty matrix, k will also be zero in this case
      l = 0;
    }
    // All good, now traverse the table a second time and construct the output
    // matrix.
    Matrix a = Matrix(k, l);
    int i = 0;
    lua_pushnil(L);
    while (lua_next(L, -2) != 0) {
      if (lua_isnumber(L, -1)) {
	double x = lua_tonumber(L, -1);
	a(i, 0) = x;
      } else if (lua_istable(L, -1)) {
	int j = 0;
	lua_pushnil(L);
	while (lua_next(L, -2) != 0) {
	  double x = lua_tonumber(L, -1);
	  a(i, j) = x;
	  lua_pop(L, 1);
	  j++;
	}
      }
      lua_pop(L, 1);
      i++;
    }
    v = octave_value(a);
    return true;
  } else
    return false;
}

/* Error handling. */

static int oct_error(lua_State *L, const char *result)
{
  char msg[1024];
  snprintf(msg, 1024, "oct_error: %s", result);
  lua_pushstring(L, msg);
  return lua_error(L);
}

/* Interface functions. */

int octave_eval(lua_State *L)
{
  const char *s = luaL_checkstring(L, 1);
  if (!s)
    return oct_error(L, "eval: expected string argument");
  if (!oct_init(L))
    return oct_error(L, "eval: error initializing Octave interpreter");

  std::string cmd = s;
  if (cmd.empty()) return 0;
  // optional second argument: max number of results to return
  int nres = lua_gettop(L)>1 ? luaL_checkinteger(L, 2) : 256;

  try {
    octave_value_list out = interpreter.eval (cmd, nres);
    int mres = 0;
    for (int i = 0; i < out.length (); i++) {
      octave_value &v = out(i);
      if (octave_to_lua(L, v))
	mres++;
      else
	return oct_error(L, "eval: unknown Octave value");
    }
    //std::cerr << "mres = " << mres << ", top = " << lua_gettop(L) << std::endl;
    return mres;
  } catch (const octave::exit_exception& ex) {
    std::cerr << "Octave interpreter exited with status = "
	      << ex.exit_status () << std::endl;
    return oct_error(L, "eval: Octave error");
  } catch (const octave::execution_exception& ex) {
    //std::cerr << "error encountered in Octave evaluator!" << std::endl;
    interpreter.handle_exception(ex);
    return oct_error(L, "eval: Octave error");
  }
  return 0;
}

int octave_feval(lua_State *L)
{
  const char *s = luaL_checkstring(L, 1);
  int nres = lua_gettop(L)>1 ? luaL_checkinteger(L, 2) : 256;
  if (!s)
    return oct_error(L, "feval: expected string argument");
  if (!oct_init(L))
    return oct_error(L, "feval: error initializing Octave interpreter");

  int n = lua_gettop(L)>1 ? lua_gettop(L)-2 : 0;
  octave_value_list in;

  for (int i = 0; i < n; i++) {
    octave_value v;
    lua_pushvalue(L, i+3);
    if (lua_to_octave(L, v)) {
      lua_pop(L, 1);
      in(i) = v;
    } else {
      lua_pop(L, 1);
      return oct_error(L, "feval: expected numeric or table argument");
    }
  }
  
  try {
    octave_value_list out = interpreter.feval (s, in, nres);
    int mres = 0;
    for (int i = 0; i < out.length (); i++) {
      octave_value &v = out(i);
      if (octave_to_lua(L, v))
	mres++;
      else
	return oct_error(L, "eval: unknown Octave value");
    }
    //std::cerr << "mres = " << mres << ", top = " << lua_gettop(L) << std::endl;
    return mres;
  } catch (const octave::exit_exception& ex) {
    std::cerr << "Octave interpreter exited with status = "
	      << ex.exit_status () << std::endl;
    return oct_error(L, "eval: Octave error");
  } catch (const octave::execution_exception& ex) {
    //std::cerr << "error encountered in Octave evaluator!" << std::endl;
    interpreter.handle_exception(ex);
    return oct_error(L, "eval: Octave error");
  }
  return 0;
}

int octave_get(lua_State *L)
{
  const char *s = luaL_checkstring(L, 1);
  if (!s)
    return oct_error(L, "get: expected string argument");
  if (!oct_init(L))
    return oct_error(L, "get: error initializing Octave interpreter");

  octave_value v = interpreter.global_varval(s);
  if (octave_to_lua(L, v))
    return 1;
  else
    return oct_error(L, "get: unknown Octave value");
}

int octave_set(lua_State *L)
{
  const char *s = luaL_checkstring(L, 1);
  if (!s)
    return oct_error(L, "get: expected string argument");
  luaL_checkany(L, 2);
  if (!oct_init(L))
    return oct_error(L, "get: error initializing Octave interpreter");

  octave_value v;
  if (lua_to_octave(L, v)) {
    interpreter.global_assign(s, v);
    return 1;
  } else
    return oct_error(L, "get: unknown Octave value");
}

/* Add a builtin to call Lua from Octave. */

#include "oct.h"

#define LUA_HELP "\
  RES = lua_call(NAME, ARG, ...)\n\
  [RES, ...] = lua_call(NAME, ARG, ...)\n\
\n\
  Execute the Lua function named NAME (a string) with the given arguments.\n\
  NAME must denote a Lua function value in the global environment.\n\
  The Lua function may return multiple results. Example:\n\
  lua_call('select', -2, 1, 2, 3) => 2 3.\n"

DEFUN_DLD(lua_call, args, nargout, LUA_HELP)
{
  int nargin = args.length();
  octave_value_list retval;
  if (nargin < 1) {
    print_usage();
    return retval;
  }
  charMatrix ch = args(0).char_matrix_value();
  octave_idx_type nr = ch.rows();
  if (nr != 1) {
    print_usage();
    return retval;
  }
  std::string name = ch.row_as_string(0);
  const char *nm = name.c_str();
  lua_State *L = _L;
  int n = lua_gettop(L);
  //std::cerr << "Call Lua function: " << nm << std::endl;
  /* Set up function and arguments. */
  lua_getglobal(L, nm);
  for (int i = 1; i < nargin; i++) {
    if (!octave_to_lua(L, args(i))) {
      error("lua: invalid argument #%d in call to function '%s'",
	    i, nm);
      lua_pop(L, i);
      return retval;
    }
  }
  /* Do the call. */
  if (lua_pcall(L, nargin-1, LUA_MULTRET, 0)) {
    /* Callback raised an exception. */
    error("lua: exception in call to function '%s'\n%s", nm,
	  lua_tostring(L, -1));
    /* pop the exception object */
    lua_pop(L, 1);
  } else {
    /* Callback was executed successfully, get the results. */
    int m = lua_gettop(L), l = m-n;
    for (int i = 0; i < l; i++) {
      lua_pushvalue(L, i+n+1);
      octave_value v;
      bool res = lua_to_octave(L, v);
      if (res) {
	retval(i) = v;
	lua_pop(L, 1);
      } else {
	if (l != 1)
	  error("lua: invalid return value #%d in call to function '%s'\n%s",
	        i+1, nm, lua_tostring(L, -1));
	else
	  error("lua: invalid return value in call to function '%s'\n%s",
		nm, lua_tostring(L, -1));
	lua_pop(L, l+1);
	return octave_value_list();
      }
    }
    lua_pop(L, l);
  }
  return retval;
}

static void install_builtins()
{
  // install_builtin_function is deprecated in 4.3, might be gone in 4.4+, but
  // this will hopefully continue to work
  octave_value fcn (new octave_builtin (Flua_call, "lua_call", "embed.cc", LUA_HELP));
  octave::symbol_table& symtab = interpreter.get_symbol_table();
  symtab.install_built_in_function ("lua_call", fcn);
}

extern "C" {
static const struct luaL_Reg l_oct [] = {
  {"eval", octave_eval},
  {"feval", octave_feval},
  {"get", octave_get},
  {"set", octave_set},
  {NULL, NULL}  /* sentinel */
};

int luaopen_octave (lua_State *L) {
  luaL_newlib(L, l_oct);
  return 1;
}
}
