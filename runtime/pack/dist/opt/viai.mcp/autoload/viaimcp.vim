vim9script

# viai.mcp - a Model Context Protocol server for ViAI help and Vim script,
# run by ViAI itself
# Maintainer: Hirohito Higashi <h.east.727@gmail.com>
#
# A client starts it as
#     viai --clean --stdio-channel -S /path/to/autoload/viaimcp.vim
# and talks MCP to it on stdin and stdout.  Command() is that command line
# for the ViAI it is called in, with its 'runtimepath'.

import autoload './viaimcp/tools.vim'

export const VERSION = '0.1.001'

const SCRIPT = expand('<sfile>:p')

# The "mcp" channel mode came with ViAI 1.0.0050.
const PATCH = 'viai-1.0.50'

# The protocol versions this server speaks, the newest first.
const PROTOCOL_VERSIONS = ['2025-11-25', '2025-06-18', '2025-03-26',
  '2024-11-05']

# JSON-RPC error codes.
const METHOD_NOT_FOUND = -32601
const INVALID_PARAMS = -32602

var conn: channel

export def Command(): list<string>
  if !has(PATCH)
    throw 'viai.mcp: the server needs ViAI 1.0.0050 or later'
  endif
  var vim = v:progpath
  # The server needs no GUI: use the console program next to gviai.exe.
  if has('win32') && vim =~? '[\\/]g[^\\/]*\.exe$'
    var console = substitute(vim, '\c[\\/]\zsg\ze[^\\/]*\.exe$', '', '')
    if executable(console)
      vim = console
    endif
  endif
  return [vim, '--clean', '--stdio-channel',
    '--cmd', 'let $VIAIMCP_RUNTIMEPATH = ' .. string(&runtimepath),
    '-S', SCRIPT]
enddef

# With --clean the plugins of the user are not on 'runtimepath':
# $VIAIMCP_RUNTIMEPATH gives the value to use.  Nothing on it is run.
def SetRuntimepath()
  if $VIAIMCP_RUNTIMEPATH == ''
    return
  endif
  &runtimepath = $VIAIMCP_RUNTIMEPATH
  # The help of this ViAI is always there.
  if index(split(&runtimepath, ','), $VIMRUNTIME) < 0
    &runtimepath ..= ',' .. escape($VIMRUNTIME, ' ,')
  endif
enddef

def Reply(id: any, result: any)
  ch_sendexpr(conn, {id: id, result: result})
enddef

def ReplyError(id: any, code: number, message: string)
  ch_sendexpr(conn, {id: id, error: {code: code, message: message}})
enddef

def Initialize(params: dict<any>): dict<any>
  var wanted = params->get('protocolVersion', '')
  return {
    protocolVersion: index(PROTOCOL_VERSIONS, wanted) >= 0
      ? wanted : PROTOCOL_VERSIONS[0],
    capabilities: {tools: {}},
    serverInfo: {name: 'viai.mcp', version: VERSION},
  }
enddef

def OnMessage(_: channel, msg: dict<any>)
  if !msg->has_key('method')
    # A response to a request of ours: there are none.
    return
  endif
  var method = msg.method
  var params = msg->get('params', {})
  if type(params) != v:t_dict
    params = {}
  endif
  if !msg->has_key('id')
    # A notification, such as "notifications/initialized".
    return
  endif
  var id = msg.id
  if method == 'initialize'
    Reply(id, Initialize(params))
  elseif method == 'ping'
    Reply(id, {})
  elseif method == 'tools/list'
    Reply(id, {tools: tools.List()})
  elseif method == 'tools/call'
    var name = params->get('name', '')
    var args = params->get('arguments', {})
    if type(name) != v:t_string || !tools.Exists(name)
      ReplyError(id, INVALID_PARAMS, $'Unknown tool: {name}')
    elseif type(args) != v:t_dict
      ReplyError(id, INVALID_PARAMS, 'The arguments are not an object')
    else
      Reply(id, tools.Call(name, args))
    endif
  else
    ReplyError(id, METHOD_NOT_FOUND, $'Method not found: {method}')
  endif
enddef

def OnClose(_: channel)
  qall!
enddef

# Nothing is displayed with --stdio-channel, but with 'verbose' set an error
# still goes to stderr, where the client can show it.
def Die(msg: string)
  &verbose = 1
  echoerr 'viai.mcp: ' .. msg
  cquit
enddef

export def Start()
  # A client may start the server without Command().
  if !has(PATCH)
    Die('the server needs ViAI 1.0.0050 or later')
  endif
  SetRuntimepath()
  try
    conn = ch_open('stdio', {mode: 'mcp', callback: OnMessage,
      close_cb: OnClose})
  catch
    Die(substitute(v:exception, '^Vim\%((\a\+)\)\=:', '', ''))
  endtry
  if ch_status(conn) != 'open'
    Die('cannot open the stdio channel')
  endif
enddef

if index(v:argv, '--stdio-channel') >= 0
  Start()
endif

# test/run sets this to have every :def compiled as the script is read.
if $VIAIMCP_COMPILE_CHECK != ''
  defcompile
endif

# vim: ts=2 sw=0 et
