#!/bin/bash

################################################################################
# Data and Constants
################################################################################

# List of stub method names (these are the special `::` methods)
# @type {Array}
_stub_method_names="
  restore
  reset
  returns
  errors
  exec
  called_with
  called
  not_called
  called_once
  called_twice
  called_thrice
  on_call
"

# Keep a direct path reference to functions used by the library itself (in
# case a user needs to stub them during testing)
_stub_echo="$(which echo)"
_stub_grep="$(which grep)"
_stub_sed="$(which sed)"
_stub_awk="$(which awk)"
_stub_env=$(which env)
_stub_cat=$(which cat)
_stub_cut=$(which cut)
_stub_touch=$(which touch)

################################################################################
# Core Methods
################################################################################

# Gets the prefix for data variables associated with a stub of the given name
# @param $1 name Name of the stub.
# @param $2 key Key for the data value.
_stub::data::prefix() {
  local name="$1"
  local key="$2"
  if [ -n "$key" ]; then
    $_stub_echo "{${name}}.$key"
  else
    $_stub_echo "{${name}}"
  fi
}

# Sets data for a stub.
# @param $1 name Name of the stub.
# @param $2 key Key for the data.
# @param $3 value Value to set.
_stub::data::set() {
  local name="$1"
  local key="$2"
  local value="${@:3}"
  local prefix=$(_stub::data::prefix "$name" "$key")

  $_stub_touch .stubdata
  if [ -n "$($_stub_grep "${prefix}" .stubdata)" ]; then
    local results=$(sed -n "/^$prefix/!p" .stubdata)
    $_stub_echo "$results" > .stubdata
  fi
  $_stub_echo "${prefix}=$value" >> .stubdata
}

# Gets (echos) data for a stub.
# @param $1 name Name of the stub.
# @param $2 key Key for the data.
_stub::data::get() {
  local name="$1"
  local key="$2"
  local prefix=$(_stub::data::prefix "$name" "$key")
  $_stub_grep "$prefix=" .stubdata | $_stub_cut -d '=' -f 2
}

# Deletes data for a stub.
# @param $1 name Name of the stub.
# @param $2 key Key for the data.
_stub::data::delete() {
  local name="$1"
  local key="$2"
  local prefix=$(_stub::data::prefix "$name" "$key")
  local results=$(sed -n "/^$prefix/!p" .stubdata)
  $_stub_echo "$results" > .stubdata
}

# Deletes data associated with a stub of the given name. If a name is not passed
# then this will clear all stub related data.
# @param $1 [name] Optional name for the stub.
_stub::data::clear() {
  local name="$1"
  if [ -n "$name" ]; then
    local results=$(sed -n "/^{$name}/!p" .stubdata)
    $_stub_echo "$results" > .stubdata
  else
    $_stub_echo '' > .stubdata
  fi
}

# Resets counts, argument lists, etc. associated with a stub of the given name.
# Roughly this implements the "::reset" method. Abstracted here since it mutates
# state associated with stubs.
# @param $1 name Name of the stub.
_stub::data::reset() {
  local name="$1"
  _stub::data::set "$name" 'call_count' '0'
  _stub::data::set "$name" 'last_args' ''
}

# Initializes all data environment variables associated with a stub of the
# given name.
# @param $1 name Name of the stub.
_stub::data::init() {
  local name="$1"
  _stub::data::reset "$name"
  _stub::data::set "$name" 'default_stdout' ''
  _stub::data::set "$name" 'default_stderr' ''
  _stub::data::set "$name" 'default_status_code' 0
  _stub::data::set "$name" 'default_command' ''
}

# Completely removes a stub with the given name from the environment.
# @param $1 name Name of the stub to remove.
_stub::remove() {
  local name="$1"
  unset -f "$name"
  for method_name in $_stub_method_names; do
    unset -f "${name}::${method_name}"
  done
  _stub::data::clear "$name"
}

# Sets all special `::` methods for a stub.
#
# @param $1 name Name of the command
_stub::set_all_methods() {
  for method_name in $_stub_method_names; do
    eval "
      ${name}::${method_name}() {
        _stub::methods::${method_name} ${name} \$@
      }
    "
  done
}

# Asserts that the last command passed
_stub::assert() {
  local last_code="$?"
  if [ -n "$(type -t assert)" ] && [ "$(type -t assert)" = 'function' ]; then
    assert equal "$last_code" '0'
  fi
  return $last_code
}

# Executes a stubbed command.
# @param $1     name Name of the stubbed command.
# @param $2...  argv Arguments passed to the stub when executed.
_stub::exec() {
  local name="$1"
  local argv="${@:2}"

  # Increment the call count
  local call_count
  call_count=$(_stub::data::get "$name" 'call_count')
  ((call_count++))
  _stub::data::set "$name" 'call_count' "$call_count"

  # Set the last used arguments
  _stub::data::set "$name" 'last_args' "$argv"

  # Fetch the default stub behavior
  local default_stdout
  default_stdout=$(_stub::data::get "$name" 'default_stdout')
  local default_stderr
  default_stderr=$(_stub::data::get "$name" 'default_stderr')
  local default_status_code
  default_status_code=$(_stub::data::get "$name" 'default_status_code')
  local default_command
  default_command=$(_stub::data::get "$name" 'default_command')

  # Check to see if there is an override command for this invocation
  local on_call_exec
  on_call_exec=$(_stub::data::get "$name" "on_call_${call_count}")
  if [ -n "$on_call_exec" ]; then
    default_command="$on_call_exec"
  fi

  # Execute the stub
  if [ -n "$default_command" ]; then
    ${default_command} ${argv}
    return $?
  elif [ "$default_status_code" -gt "0" ]; then
    if [ -n "$default_stderr" ]; then
      $_stub_echo "$default_stderr" >&2
    fi
    return $default_status_code
  else
    if [ -n "$default_stdout" ]; then
      $_stub_echo "$default_stdout"
    fi
    return 0
  fi
}

################################################################################
# Stub methods
################################################################################

# Restores a command to its original state. Effectively removes the stub and all
# special :: commands from the bash environment.
# @param $1 name Name of the command to restore
_stub::methods::restore() {
  local name="$1"
  _stub::remove "$name"
}

# Resets all internal call counts and argument lists associated with a stub.
# @param $1 name Name of the command to restore
_stub::methods::reset() {
  local name="$1"
  _stub::data::reset "${name}"
}

# Sets a stub to output the given string to stdout and return a 0 status code.
# @param $1 name Name of the command to restore
# @param $2 output Output for the command
_stub::methods::returns() {
  local name="$1"
  local output="${@:2}"
  _stub::data::set "$name" 'default_command' ''
  _stub::data::set "$name" 'default_stderr' ''
  _stub::data::set "$name" 'default_status_code' 0
  _stub::data::set "$name" 'default_stdout' "$output"
}

# Sets a stub to error by printing the given string to stderr and returning the
# given status code.
# @param $1 name Name of the command to stub
# @param $2 [output] Output to send to stderr
# @param $3 [code=1] Status code to return
_stub::methods::errors() {
  local name="$1"
  local output
  local code

  # Handle the optional parameters
  if [ $# -lt 3 ]; then
    output="$2"
    code=1
    if [ "$output" -eq "$output" ] 2> /dev/null; then
      code="$output"
      output=''
    fi
  else
    output="${@:2:$#-2}"
    code="${@:$#}"
    if ! [ "$code" -eq "$code" ] 2> /dev/null; then
      output="$output $code"
      code=1
    fi
  fi

  _stub::data::set "$name" 'default_command' ''
  _stub::data::set "$name" 'default_stdout' ''
  _stub::data::set "$name" 'default_status_code' "$code"
  _stub::data::set "$name" 'default_stderr' "$output"
}

# Sets a stub to execute the given command or function when it is called.
# @param $1 name Name of the stub.
# @param $2 exec_command Command to execute.
_stub::methods::exec() {
  local name="$1"
  local exec_command="$2"
  _stub::data::set "$name" 'default_command' "$exec_command"
  _stub::data::set "$name" 'default_stdout' ''
  _stub::data::set "$name" 'default_status_code' ''
  _stub::data::set "$name" 'default_stderr' ''
}

# Override the default behavior for the stub for the given call number by having
# it run the given command instead.
# @param $1 name Name of the stub.
# @param $2 number Which call to override.
# @param $3 exec_command The command to execute on that particular call
_stub::methods::on_call() {
  local name="$1"
  local number="$2"
  local exec_command="$3"
  _stub::data::set "$name" "on_call_${number}" "$exec_command"
}

# Asserts that a stub was called with the given arguments the last time it was
# executed.
# @param $1     name Name of the stub.
# @param $2...  argv Arguments that should have been provided.
_stub::methods::called_with() {
  local name="$1"
  local argv="${@:2}"
  local last_args
  last_args=$(_stub::data::get "$name" 'last_args')
  [[ -n $($_stub_echo $last_args | $_stub_grep "^$argv") ]]
  _stub::assert
}

# Asserts that a stub was called the given number of times.
# @param $1 name Name of the stub.
# @param $2 [number=1] Number of times to assert that the stub was called.
_stub::methods::called() {
  local name="$1"
  local number="$2"
  local call_count
  call_count=$(_stub::data::get "$name" 'call_count')
  if [[ -n "$number" ]]; then
    (( $call_count == $number ))
  else
    (( $call_count > 0 ))
  fi
  _stub::assert
}

# Asserts that the stub was not called.
# @param $1 name Name of the stub.
_stub::methods::not_called() {
  local name="$1"
  local number="$2"
  local call_count
  call_count=$(_stub::data::get "$name" 'call_count')
  (( $call_count == 0 ))
  _stub::assert
}

# Asserts that the stub was called exactly once.
# @param $1 name Name of the stub.
_stub::methods::called_once() {
  local name="$1"
  local number="$2"
  local call_count
  call_count=$(_stub::data::get "$name" 'call_count')
  (( $call_count == 1 ))
  _stub::assert
}

# Asserts that the stub was called exactly twice.
# @param $1 name Name of the stub.
_stub::methods::called_twice() {
  local name="$1"
  local number="$2"
  local call_count
  call_count=$(_stub::data::get "$name" 'call_count')
  (( $call_count == 2 ))
  _stub::assert
}

# Asserts that the stub was called exactly three times.
# @param $1 name Name of the stub.
_stub::methods::called_thrice() {
  local name="$1"
  local number="$2"
  local call_count
  call_count=$(_stub::data::get "$name" 'call_count')
  (( $call_count == 3 ))
  _stub::assert
}

################################################################################
# Command Stubbing Methods
################################################################################

# Creates a basic stub for the given command. The stub will have no effect and
# simply return 0. This method will also set a slew of methods that can be used
# to change the default behavior of the stub. See the :: methods below for more
# information.
# @param $1 name Name of the command to stub.
stub() {
  local name="$1"

  if [[ -n $($_stub_echo "$name" | $_stub_grep '^_stub') ]]; then
    $_stub_echo "[ERROR] shtub: Cannot stub command '$name'," \
      "internal library methods cannot be stubbed" >&2
    return 1
  fi

  local blacklist="local if do done fi eval source return eval"
  if [[ -n $($_stub_echo $blacklist | $_stub_grep "$name") ]]; then
    $_stub_echo "[ERROR] shtub: Cannot stub command '$name'," \
      "bash built-ins cannot be stubbed" >&2
    return 1
  fi

  eval "
    _stub::methods::restore '${name}'
    ${name}() {
      _stub::exec '${name}' \$@
    }
    _stub::data::init '${name}'
    _stub::set_all_methods '${name}'
  "
}

# Creates a stub for the given command that pipes the given output to stdout
# when the command is executed.
# @param $1 name Name of the command to stub.
# @param $2 output Output the stub should pipe to stdout when called.
stub::returns() {
  local name="$1"
  local output="${@:2}"
  stub "$name"
  eval "${name}::returns '$output'"
}


# Creates a stub for the given command that pipes the given output to stderr and
# returns the given status code.
# @param $1 name Name of the command to stub.
# @param $2 output Output the stub should pipe to stderr when called.
# @param $3 code Status code to set upon execution
stub::errors() {
  local name="$1"
  local output="$2"
  local code="$3"
  stub "$name"
  eval "${name}::errors '$output' '$code'"
}

# Creates a stub for the given command that executes the given command string or
# function when the stub is called.
# @param $1 name Name of the command to stub.
# @param $2 exec_command Command to execute when the stub is called.
stub::exec() {
  local name="$1"
  local exec_command="$2"
  stub "$name"
  eval "${name}::exec '$exec_command'"
}
