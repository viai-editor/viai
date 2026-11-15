@echo off
rem Starts viai.mcp: a ViAI that serves the Model Context Protocol on its
rem stdin and stdout.  %VIAIMCP_VIM% names the ViAI to use, "viai" from
rem %PATH% otherwise.
setlocal
if "%VIAIMCP_VIM%"=="" set VIAIMCP_VIM=viai
"%VIAIMCP_VIM%" --clean --stdio-channel -S "%~dp0..\autoload\viaimcp.vim"
