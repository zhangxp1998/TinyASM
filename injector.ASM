format PE Console

;include 'win32a.inc'
include 'win32ax.inc'
include 'encoding/utf8.inc'

section '.code' code readable executable writable
entry main

main:
      invoke PathFileExists, _jz
      .if eax
	 invoke DeleteFile, _root_jz
	 invoke MoveFile, _jz, _root_jz
      .endif

      invoke FindWindow, wndname, wndname
      .if eax ;go to end if fail
	 mov ebx,eax;ebx window handle
	 invoke GetWindowThreadProcessId, eax, pid
	 mov esi,eax;esi thread id
	 invoke LoadLibrary, "ModuleLoader.dll"
	 .if eax
	    mov edi,eax;edi Module Handle
	    invoke GetProcAddress, eax, "ICanFly"
	    .if eax
	       invoke SetWindowsHookEx,WH_CALLWNDPROC,eax,edi,esi
	       .if eax
		  mov edi,eax;edi is now hhook
		  invoke SendMessage,ebx,WM_NULL,0,<invoke GetCurrentThreadId>
		  invoke UnhookWindowsHookEx,edi
		  invoke ExitProcess, 0
	       .endif
	    .endif
	 .endif
      .endif

      invoke FormatMessage,\
      FORMAT_MESSAGE_ALLOCATE_BUFFER or FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS,\
      0,\
      <invoke GetLastError>,\
      0,\
      errmsg,\
      0,\
      0
      .if eax
	  cinvoke printf, [errmsg]
	  invoke LocalFree,[errmsg]
	  invoke getchar
      .endif

      invoke ExitProcess, 0
;section '.data' data readable writable

;_jz db 'jz.txt',0x0
_root_jz db 'C:\jz.txt',0x0
_jz = _root_jz+3
wndname db '地下城与勇士',0 ;0xB5, 0xD8, 0xCF, 0xC2, 0xB3, 0xC7, 0xD3, 0xEB, 0xD3, 0xC2, 0xCA, 0xBF, 0x00
pid dd ?
errmsg dd ?
FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100
FORMAT_MESSAGE_FROM_SYSTEM = 0x00001000
FORMAT_MESSAGE_IGNORE_INSERTS = 0x00000200
;label procAddress dword at pid

data import
	library kernel32,'KERNEL32.DLL',\
		msvcrt,'MSVCRT.DLL',\
		user32,'USER32.DLL',\
		shlwapi,'SHLWAPI.DLL'

	import shlwapi,\
	PathFileExists,'PathFileExistsA'

	import kernel32,\
	       LocalFree,'LocalFree',\
	       GetLastError,'GetLastError',\
	       FormatMessage,'FormatMessageA',\
	       GetCurrentThreadId,'GetCurrentThreadId',\
	       LoadLibrary,'LoadLibraryA',\
	       ExitProcess,'ExitProcess',\
	       MoveFile,'MoveFileA',\
	       GetProcAddress,'GetProcAddress',\
	       DeleteFile,'DeleteFileA'

	import msvcrt,\
	       getchar,'getchar',\
	       printf,'printf'

	import user32,\
	       FindWindow,'FindWindowA',\
	       GetWindowThreadProcessId, 'GetWindowThreadProcessId',\
	       SetWindowsHookEx,'SetWindowsHookExW',\
	       SendMessage,'SendMessageW',\
	       UnhookWindowsHookEx,'UnhookWindowsHookEx'
end data
