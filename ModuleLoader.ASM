format PE DLL
include 'encoding/utf16.inc'
include 'win32ax.inc'
include 'winternl.inc'

entry DllMain
section '.PoU' readable writable executable
include 'Call.asm'
data export
     export 'ModuleLoader.DLL',\
	 WndProc,'ICanFly'
end data

struc HotkeyEntry ctrl,alt,shift,vk,handler,param
{
	.ctrl db ctrl
	.alt db alt
	.shift db shift
	.vk dd vk
	.handler dd handler
	.param dd param
}

macro Announce playerName,msg,style,color
{
    mov ecx,[SHOP_BASEADDR]
    mov ecx,[ecx+0x4C]
    invoke ANNOUNCE_CALL,msg,color,style,playerName,0,0,0
}

macro GetPlayerName
{
    mov eax,[CHAR_BASEADDR]
    .if eax
	mov eax,[eax+0x374]
    .endif
}

proc UNLINK entry
     mov eax,[entry]
     mov edx,[eax+LIST_ENTRY.FLink]
     .if edx
	 mov ecx,[eax+LIST_ENTRY.BLink]
	 mov [edx+LIST_ENTRY.BLink],ecx
     .endif
     mov edx,[eax+LIST_ENTRY.BLink]
     .if edx
	 mov ecx,[eax+LIST_ENTRY.FLink]
	 mov [edx+LIST_ENTRY.FLink],ecx
     .endif
     ret
endp

proc RELINK entry
     mov eax,[entry]
     mov edx,[eax+LIST_ENTRY.FLink]
     .if edx
	 mov ecx,[eax+LIST_ENTRY.BLink]
	 mov [edx+LIST_ENTRY.BLink],eax
     .endif
     mov edx,[eax+LIST_ENTRY.BLink]
     .if edx
	 mov ecx,[eax+LIST_ENTRY.FLink]
	 mov [edx+LIST_ENTRY.FLink],eax
     .endif
     ret
endp

proc EraseModuleHeader
     local old dd ?
     local new dd PAGE_EXECUTE_READWRITE
     local size dd ?
     mov eax,[ecx+IMAGE_DOS_HEADER.e_lfanew]
     add eax,sizeof.IMAGE_NT_HEADERS
     mov [size],eax
     push ecx
	  lea edx,[old]
	  invoke VirtualProtect,ecx,eax,[new],edx
     pop ecx

     mov eax,[size]
     .while eax>=4
	   mov dword[ecx],0
	   add ecx,4
	   sub eax,4
     .endw

     .while ecx>0
	   mov byte[ecx],0
	   inc ecx
	   dec eax
     .endw
     mov eax,[size]
     sub ecx,eax
     lea edx,[new]
     invoke VirtualProtect,ecx,eax,[old],edx
     ret
endp

proc UnlinkModuleFromPEB
     ;push ebx
     ;mov ebx,ecx
     mov eax,[fs:0x30]
     mov eax,[eax+PEB.LDR]
     add eax,LDR.LoadOrderList
     .while eax
	 .if[eax+LDR_DATA_TABLE_ENTRY.DllBase]=ecx
		push esi
		mov esi,eax
		lea eax,[esi+LDR_DATA_TABLE_ENTRY.LoadOrderList]
		stdcall UNLINK,eax
		lea eax,[esi+LDR_DATA_TABLE_ENTRY.MemoryOrderList]
		stdcall UNLINK,eax
		lea eax,[esi+LDR_DATA_TABLE_ENTRY.InitialOrderList]
		stdcall UNLINK,eax
		lea eax,[esi+LDR_DATA_TABLE_ENTRY.HashTableEntry]
		stdcall UNLINK,eax
		mov eax,esi
		pop esi
		;pop ebx
		ret
	 .endif
	 mov eax,[eax+LIST_ENTRY.FLink]
     .endw
     ;pop ebx
     ret
endp

proc RelinkModuleToPEB
     push esi
     mov esi,ecx
     lea eax,[esi+LDR_DATA_TABLE_ENTRY.LoadOrderList]
     stdcall RELINK,eax
     lea eax,[esi+LDR_DATA_TABLE_ENTRY.MemoryOrderList]
     stdcall RELINK,eax
     lea eax,[esi+LDR_DATA_TABLE_ENTRY.InitialOrderList]
     stdcall RELINK,eax
     lea eax,[esi+LDR_DATA_TABLE_ENTRY.HashTableEntry]
     stdcall RELINK,eax
     pop esi
     ret
endp

proc DllMain hinstDLL,dwReason,lpvReserved
    .if [dwReason] = DLL_PROCESS_ATTACH
	mov eax,[hinstDLL]
	mov [hCurrentMod],eax
	invoke DisableThreadLibraryCalls,eax
    .endif

    mov al,1
    ret
endp

proc WndProc nCode,isByCurrentThread,lParam
     mov ecx,[lParam]
     .if [ecx+CWPSTRUCT.msg] = 0
	 call initialize
     .endif
     invoke CallNextHookEx,0,[nCode],[isByCurrentThread],[lParam]
     ret
endp

proc initialize
   ;ccall WriteLog,.dbgFormat,KeyboardProc
   mov ecx,[hCurrentMod]
   call UnlinkModuleFromPEB
   mov [unlinkedLdr],eax
   ;mov ecx,[hCurrentMod]
   ;stdcall EraseModuleHeader
   invoke SetWindowsHookEx,WH_KEYBOARD,KeyboardProc,[hCurrentMod],<invoke GetCurrentThreadId>
   .if eax
       mov [hhook],eax
       GetPlayerName
       Announce eax,.greeting,52,LIGHT_GREEN
       ;ccall WriteLog,.dbgFormat,KeyboardProc
   .endif

   ret
   .greeting du "来自ASM的公告...",0
   ;.dbgFormat db '0x%X',NEW_LINE,0
endp

proc KeyboardProc code,wParam,lParam
	mov eax,[lParam]
	and eax,0x40000000
	.if eax=0 ;if key is not down before
		push ebx
		push esi
		push edi
		mov ebx,[wParam];vk code
		mov esi,beginHk
		mov edi,endHk
		.beginLoop:
			cmp esi,edi
			jge .endLoop
			.if [esi+HotkeyEntry.vk]=ebx
				push VK_CONTROL
				call IsKeyDown
				.if al=[esi+HotkeyEntry.ctrl]
					push VK_MENU
					call IsKeyDown
					.if al=[esi+HotkeyEntry.alt]
						push VK_SHIFT
						call IsKeyDown
						.if al=[esi+HotkeyEntry.shift]
							invoke esi+HotkeyEntry.handler,[esi+HotkeyEntry.param]
							jmp .endLoop
						.endif
					.endif
				.endif
			.endif
			add esi,sizeof.HotkeyEntry
			jmp .beginLoop
		.endLoop:
		pop edi
		pop esi
		pop ebx
	.endif

	.finish:
	invoke CallNextHookEx,0,[code],[wParam],[lParam]
	ret
;.text db 'KeyboardProc() %d 0x%X',NEW_LINE,0
;.failCtrl db 'CTRL %d %d',NEW_LINE,0
;.failAlt db 'ALT %d %d',NEW_LINE,0
;.failSft db 'SHIFT %d %d',NEW_LINE,0
endp

proc IsKeyDown vk
	invoke GetAsyncKeyState,[vk]
	test ax,0x8000
	setnz al
	ret
endp

proc UnloadModule param
     ;GetPlayerName
     mov ecx,[unlinkedLdr]
     stdcall RelinkModuleToPEB
     Announce 0,.exitGreeting,37,GREEN
     invoke UnhookWindowsHookEx,[hhook]
     ret
.exitGreeting du "尝试退出咯~\(≧▽≦)/~",0
;.format db 'Hotkey triggered...exiting...',NEW_LINE,0
endp

proc WriteLog c str,format
     push esi
     cinvoke fopen,logfile,access
     .if eax
	 mov esi,eax
	 lea eax,[format]
	 cinvoke vfprintf,esi,[str],eax
	 cinvoke fclose,esi
     .endif
     pop esi
     ret
endp
proc EnableInvincibility param
     mov ecx,[CHAR_BASEADDR]
     .if ecx
	 mov dword[ecx+0x838],1
	 inc dword[ecx+0x928]
	 ;GetPlayerName
	 Announce 0,.msg,37,GREEN
     .endif
     ret
.msg du "开启霸体无敌!",0
endp

proc EnableTransparency switch
     mov ecx,[CHAR_BASEADDR]
     .if ecx
	 invoke INVINCI_CALL,1,[switch],0,-1
	 Announce 0,.msg,37,GREEN
     .endif
     ret
.msg du "开关透明!",0
endp

proc AdjustRank param
     mov ecx,[RANK_BASEADDR]
     add ecx,0x110
     stdcall Encrypt,ecx,500000
     Announce 0,.msg,37,GREEN
     ret
.msg du "炒鸡评分!",0
endp

proc EnumDungeonEntities Callback
     mov ecx,[CHAR_BASEADDR]
     .if ecx
	 mov ecx,[ecx+0xB8]
	 .if ecx
	     push esi
	     push edi
	     mov esi,[ecx+0xC0]
	     mov edi,[ecx+0xC4]
	     .while esi<edi
		    mov ecx,[esi]
		    call [Callback]
		    add esi,4
	     .endw
	     pop edi
	     pop esi
	 .endif
     .endif
     ret
endp

proc ItemVac
     .if dword[ecx+0x94]=289
	 PickupItem ecx
	 Announce 0,.msg,37,GREEN
     .endif
     ret
.msg du "全屏捡污!",0
endp

proc AmplifyDamage param
     stdcall Encrypt,STATS_COEFF,0.003
     Announce 0,.msg,37,GREEN
     ret
.msg du "神秘倍攻！",0
endp

proc SellUnwantedEquips param
     mov ecx,[BAGPACK_BASEADDR]
     .if ecx
	 mov ecx,[ecx+0x58]
	 .if ecx
	     push edi
	     push esi
		  mov esi,ecx
		  mov edi,9
		  .while edi<65
			 mov ecx,[esi+edi*4]
			 .if ecx
			     .if dword[ecx+0x160]>=0 & dword[ecx+0x160]<=2
				 mov eax,[ecx+0x24]
				 .if dword[eax]=0x627F4F20
				 .else
					stdcall SellItem,edi,1
				 .endif
			      .endif
			 .endif
			 inc edi
		  .endw
	     pop esi
	     pop edi
	     Announce 0,.msg,37,GREEN
	 .endif
     .endif
     ret
.msg du "一键卖污！",0
endp

proc AdvanceRoom dir
     stdcall AdvanceRoomCall,[dir]
     Announce 0,.msg,37,GREEN
     ret
.msg du "顺图",0
endp

proc InstantKill
     .if dword[ecx+0x94]=529
	 invoke GO_DIE_CALL,0
     .endif
     ret
endp

proc ZeroHealth
     .if dword[ecx+0x750]
	 .if dword[ecx+0x94]=529 | dword[ecx+0x94]=273
	     local health dq 0
	     mov eax,[ecx]
	     call dword[eax+0x5E4]
	     lea edx,[health]
	     stdcall Encrypt64,eax,edx
	     Announce 0,.msg,37,GREEN
	 .endif
     .endif
     ret
.msg du "0血秒杀！",0
endp


proc InfiniteDurability param
     mov eax,[CHAR_BASEADDR]
     .if eax
	 push ebx
	 push esi
	 mov ecx,[eax+WEAPON]
	 .if ecx
	     add ecx,DURABILITY_CAP
	     stdcall Encrypt,ecx,0
	 .endif
	 mov esi,[CHAR_BASEADDR]
	 mov ebx,TOP
	 .while ebx<=BELT
		mov ecx,[esi+ebx]
		.if ecx
		    add ecx,DURABILITY_CAP
		    stdcall Encrypt,ecx,0
		.endif
		add ebx,4
	 .endw
	 pop esi
	 pop ebx
	 Announce 0,.msg,37,GREEN
     .endif
     ret
.msg du "免耐久已开启！换角色需再次开启",0
endp

proc AdjustCriticalHitrate param
     mov ecx,[CHAR_BASEADDR]
     .if ecx
	 push ebx
	 mov ecx,[ecx+RING]
	 .if ecx
	     lea ebx,[ecx+PHY_CRITICAL_HITRATE]
	     stdcall Encrypt,ebx,80.0
	     add ebx,MAG_CRITICAL_HITRATE-PHY_CRITICAL_HITRATE
	     stdcall Encrypt,ebx,80.0
	     Announce 0,.msg,37,GREEN
	 .endif
	 pop ebx
     .endif
     ret
.msg du "已大幅度增加暴击率！查看面板生效！",0
endp

proc FastHeal param
     mov ecx,[CHAR_BASEADDR]
     .if ecx
	 push ebx
	 mov ecx,[ecx+WEAPON]
	 .if ecx
	     lea ebx,[ecx+HP_RECOVER_RATE]
	     stdcall Encrypt,ebx,125000
	     add ebx,MP_RECOVER_RATE-HP_RECOVER_RATE
	     stdcall Encrypt,ebx,30000
	     Announce 0,.msg,37,GREEN
	 .endif
	 pop ebx
     .endif
     ret
.msg du "大回复术！查看面板生效！",0
endp

proc IncreaseStats base,delta
     stdcall Decrypt,[base]
     add eax,[delta]
     stdcall Encrypt,[base],eax
     ret
endp

proc AdjustSpeed param
     mov ecx,[CHAR_BASEADDR]
     .if ecx
	 push ebx
	 mov ebx,[ecx+SHOULDER]
	 .if ecx
	     local delta dd ?
	     mov eax,200
	     imul[param]
	     mov [delta],eax
	     lea ecx,[ebx+MOVEMENT_SPEED]
	     stdcall IncreaseStats,ecx,[delta]
	     lea ecx,[ebx+ATTACK_SPEED]
	     stdcall IncreaseStats,ecx,[delta]
	     lea ecx,[ebx+CASTING_SPEED]
	     stdcall IncreaseStats,ecx,[delta]
	     Announce 0,.msg,37,GREEN
	 .endif
	 pop ebx
     .endif
     ret
.msg du "调整三速！",0
endp

proc IgnoreTeamates
     .if dword[ecx+0x750]=0
	 .if dword[ecx+0x94]=273
	     push ebx
	     lea ebx,[ecx+0x198]
	     stdcall Encrypt,ebx,0
	     Announce dword[ecx+0x374],.msg,37,GREEN
	     pop ebx
	 .endif
     .endif
     ret
.msg du "无视队友！",0
endp

proc GetOptimalCompletionCount count
     mov edx,[count]
     xor ecx,ecx
     xor eax,eax
     .while ecx<4
	    shr edx,cl
	    .if dl>al
		mov al,dl
	    .endif
	    shr edx,8
	    inc ecx
     .endw
     ret
endp

proc ClearAcceptedQuests param
     mov ecx,[QUEST_BASEADDR]
     .if ecx
	 push esi
	 push edi
	 mov esi,[ecx+0x8]
	 mov edi,[ecx+0xC]
	 .while esi<edi
		mov ecx,[esi]
		.if dword[ecx+0x1D4]
		    lea edx,[esi+0x4]
		    stdcall Decrypt,edx
		    stdcall GetOptimalCompletionCount,eax
		    ;local optCount dd ?
		    ;mov [optCount],eax
		    ;ccall WriteLog,.format,eax
		    ;mov eax,[optCount]
		    .if eax
			mov ecx,[esi]
			stdcall CompleteQuest,dword[ecx],eax
			mov ecx,[esi]
			mov edx,[ecx+0x8]
			.if dword[ecx+0x1C]=7
			    lea edx,[ecx+0x8]
			.endif
			Announce .msg,edx,37,GREEN
		    .endif
		.endif
		add esi,0xC
	 .endw
	 pop edi
	 pop esi
     .endif
     ret
.msg du "完成任务",0
;.format db "%d",NEW_LINE,0
endp

proc StatsBoost param
     mov ecx,[CHAR_BASEADDR]
     .if
	mov ecx,[ecx+TOP]
	.if ecx
	    push esi
	    mov esi,ecx
	    lea ecx,[esi+FOUR_STATS]
	    stdcall Encrypt,ecx,833
	    lea ecx,[esi+PHY_ATK]
	    stdcall Encrypt,ecx,1000
	    lea ecx,[esi+MAG_ATK]
	    stdcall Encrypt,ecx,1000
	    lea ecx,[esi+EXOC]
	    stdcall Encrypt,ecx,130
	    lea ecx,[esi+ELEMENTAL_DMG]
	    stdcall Encrypt,ecx,800
	    lea ecx,[esi+PHY_PIERC_ATK]
	    stdcall Encrypt,ecx,1000
	    lea ecx,[esi+MAG_PIERC_ATK]
	    stdcall Encrypt,ecx,1000
	    lea ecx,[esi+INDEPENDENT_ATK]
	    stdcall Encrypt,ecx,500
	    lea ecx,[esi+REFINE_INDP_ATK]
	    stdcall Encrypt,ecx,500
	    lea ecx,[esi+ABNORMAL_STATUS_RESI]
	    stdcall Encrypt,ecx,1000
	    lea ecx,[esi+IMMOBILITY]
	    stdcall Encrypt,ecx,1000
	    lea ecx,[esi+MISS_RATE]
	    stdcall Encrypt,ecx,2000
	    lea ecx,[esi+HITRATE_DEC]
	    stdcall Encrypt,ecx,-200.0
	    lea ecx,[esi+BONUS_DMG_APC]
	    stdcall Encrypt,ecx,1000.0
	    lea ecx,[esi+BONUS_DMG_BLD]
	    stdcall Encrypt,ecx,1000.0
	    pop esi
	    Announce 0,.msg,37,GREEN
	.endif
     .endif
     ret
.msg du "神秘炒鸡BUFF！查看面板生效",0
endp

proc ToggleAutoPickup param
     .if [.timer]
	invoke KillTimer,0,[.timer]
	mov [.timer],0
	Announce 0,.msgOff,37,GREEN
	ret
     .endif
     invoke SetTimer,0,0,200,.TimerProc
     mov [.timer],eax
     Announce 0,.msgOn,37,GREEN
     ret
     proc .TimerProc hwnd,uMsg,idEvent,dwTime
	  mov ecx,[CHAR_BASEADDR]
	  .if ecx
	      mov ecx,[ecx+0xB8]
	      .if ecx
		  push esi
		  push edi
		  mov esi,[ecx+0xC0]
		  mov edi,[ecx+0xC4]
		  .while esi<edi
			 mov ecx,[esi]
			 .if dword[ecx+0x94]=289
			     PickupItem ecx
			 .endif
			 add esi,4
		  .endw
		  pop edi
		  pop esi
	      .endif
	  .endif
	  ret
     endp
.timer dd 0
.msgOff du "自动全屏捡污已关闭！",0
.msgOn du "自动全屏捡污已开启！",0
endp

proc InstKill param
     stdcall ObjSkillCall,0,39002,0,0,0,0,33
     Announce 0,.msg,37,GREEN
     ret
.msg du "已击杀房间内所有敌人！(╰_╯)#",0
endp

proc ClearChallengeQuests param
     push esi
     push edi
	 mov esi,[CHAL_QUEST_BASEADDR]
	 mov edi,[CHAL_QUEST_BASEADDR+0x4]
	 .while esi<edi
		mov ecx,[esi]
		.if dword[ecx+0x1D4]
		    lea edx,[esi+0x4]
		    stdcall Decrypt,edx
		    stdcall GetOptimalCompletionCount,eax
		    .if eax
			mov ecx,[esi]
			stdcall CompleteQuest,dword[ecx],eax
			mov ecx,[esi]
			mov edx,[ecx+0x8]
			Announce .msg,edx,37,GREEN
		    .endif
		.endif
		add esi,0xC
	 .endw
     pop edi
     pop esi
     ret
.msg du "完成挑战任务",0
endp

proc SubmitChallengeQuest param
     .if [currentQuest]=0
	 mov eax,[CHAL_QUEST_BASEADDR]
	 mov [currentQuest],eax
	 invoke SetTimer,0,0,140,.TimerProc
	 mov [submitTimer],eax
     .endif
     ret

     proc .TimerProc hwnd,uMsg,idEvent,dwTime
	  mov eax,[currentQuest]
	  .if eax<=[CHAL_QUEST_BASEADDR+0x4]
	      mov ecx,[eax]
	      .if dword[ecx+0x1D4]
		  lea edx,[eax+0x4]
		  stdcall Decrypt,edx
		  stdcall GetOptimalCompletionCount,eax
		  mov ecx,[currentQuest]
		  mov ecx,[ecx]
		  .if eax=0
		      stdcall SubmitQuest,dword[ecx]
		      mov ecx,[currentQuest]
		      mov ecx,[ecx]
		      mov edx,[ecx+0x8]
		      Announce .msg,edx,37,GREEN
		  .endif
		  add [currentQuest],0xC
		  ret
	      .endif
	  .endif
	  push ebx
	       SEND_BUFFER_CALL 700,0
	       SEND_ENCRYPT_CALL ebx,4
	       SEND_PACKET_CALL
	  pop ebx
	  invoke KillTimer,0,[submitTimer]
	  mov [currentQuest],0
	  ret
     endp
.msg du "提交挑战任务",0
endp

proc AttackEnemy
     .if dword[ecx+0x750]
	 .if dword[ecx+0x94]=529 | dword[ecx+0x94]=273
	      local float dd 0
	      push 33

	      mov eax,[ecx+0x1B8+0x8]
	      mov [float],eax
	      cvtss2si eax,[float]
	      push eax

	      mov eax,[ecx+0x1B8+0x4]
	      mov [float],eax
	      cvtss2si eax,[float]
	      push eax

	      mov eax,[ecx+0x1B8]
	      mov [float],eax
	      cvtss2si eax,[float]
	      push eax

	      push 0
	      push 70023
	      push 0
	      call ObjSkillCall
	 .endif
     .endif
     ret
endp

proc RemoveCD param
     mov ecx,[CHAR_BASEADDR]
     .if ecx
	 push esi
	 push edi
	 mov edi,ecx
	 mov esi,0x3BD8
	 .while esi<=0x4FD8
		mov ecx,[edi+esi]
		.if ecx
		     lea edx,[ecx+0x6F0];skill level offset
		     stdcall Decrypt,edx
		     .if eax
			 local lvOffset dd 0
			 dec eax
			 shl eax,3
			 mov [lvOffset],eax
			 mov ecx,[edi+esi]
			 mov ecx,[ecx+0x300]
			 lea ecx,[ecx+eax]
			 stdcall Encrypt,ecx,0

			 mov eax,[lvOffset]
			 mov ecx,[edi+esi]
			 mov ecx,[ecx+0x250]
			 lea ecx,[ecx+eax]
			 stdcall Encrypt,ecx,0

		     .endif
		.endif
		add esi,4
	 .endw
	 pop edi
	 pop esi
	 Announce .msg,edx,37,GREEN
     .endif
     ret
.msg du "无CD模式已开启！",0
endp

proc EightGates param
     inc [gateIndex]
     .if [gateIndex]>8
	 mov [gateIndex],0
     .endif
     mov eax,[gateIndex]
     stdcall Encrypt,STATS_COEFF-0x8,dword[gateValue+eax*4]
     Announce .msg,edx,37,GREEN
     ret
.msg du "八门遁甲！",0
endp

VK_OEM_3 = 0xC0
NEW_LINE = 0x0A
hCurrentMod dd ?
submitTimer dd ?
hhook dd ?
currentQuest dd ?
unlinkedLdr dd ?
gateIndex dd ?
gateValue:
dd 0.01
dd 0.02
dd 0.03
dd 0.04
dd 0.05
dd 0.06
dd 0.07
dd 0.08
dd 0.09
logfile db 'C:\fasm.log',0
access db 'a+',0

struct HotkeyEntry
	ctrl db ?
	alt db ?
	shift db ?
	vk dd ?
	handler dd ?
	param dd ?
ends

struct CWPSTRUCT
	lParam dd ?
	wParam dd ?
	msg dd ?
	hwnd dd ?
ends
;section '.import' import readable writable
data import
     library kernel32,'KERNEL32.DLL',\
	     user32,'USER32.DLL',\
	     kernelbase,'KERNELBASE.DLL',\
	     msvcrt,'MSVCRT.DLL',\
	     ntdll,'NTDLL.DLL'

     import user32,\
     CallNextHookEx,'CallNextHookEx',\
     SetWindowsHookEx,'SetWindowsHookExW',\
     UnhookWindowsHookEx,'UnhookWindowsHookEx',\
     GetAsyncKeyState,'GetAsyncKeyState',\
     SetTimer,'SetTimer',\
     KillTimer,'KillTimer'

     import kernel32,\
     GetCurrentThreadId,'GetCurrentThreadId',\
     DisableThreadLibraryCalls,'DisableThreadLibraryCalls',\
     VirtualProtect,'VirtualProtect'
     ;import kernelbase,\

     ;OutputDebugString,'OutputDebugStringA',\
     ;OutputDebugStringW,'OutputDebugStringW'

     ;import msvcrt,\
     ;printf,'printf',\
     ;fopen,'fopen',\
     ;vfprintf,'vfprintf',\
     ;fclose,'fclose'

     ;import ntdll,\
     ;sprintf,'sprintf'

end data

section '.reloc' data discardable readable fixups
;if ~ $-$$
	;dd	 0,8 ;empty fixups section if no other fixups
;end if
section '.const' data readable
beginHk:;CTRL ALT SHIFT VK CallBack,Param
HotkeyEntry 1,0,0,VK_F12,UnloadModule,0
HotkeyEntry 0,1,0,VK_F3,EnableInvincibility,0
HotkeyEntry 0,1,0,VK_OEM_3,EnableTransparency,1
HotkeyEntry 0,1,1,VK_OEM_3,EnableTransparency,0
HotkeyEntry 0,0,0,VK_F5,AdjustRank,0
HotkeyEntry 0,0,0,VK_CAPITAL,EnumDungeonEntities,ItemVac
HotkeyEntry 0,1,0,VK_F1,AmplifyDamage,0
HotkeyEntry 0,0,0,VK_F7,SellUnwantedEquips,0
HotkeyEntry 0,1,0,VK_LEFT,AdvanceRoom,LEFT
HotkeyEntry 0,1,0,VK_RIGHT,AdvanceRoom,RIGHT
HotkeyEntry 0,1,0,VK_UP,AdvanceRoom,UP
HotkeyEntry 0,1,0,VK_DOWN,AdvanceRoom,DOWN
HotkeyEntry 0,0,0,VK_INSERT,EnumDungeonEntities,InstantKill
HotkeyEntry 0,1,0,'Z',StatsBoost,0
HotkeyEntry 0,1,0,'X',EightGates,0
HotkeyEntry 0,1,0,'C',EnumDungeonEntities,ZeroHealth
HotkeyEntry 0,1,0,'W',EnumDungeonEntities,IgnoreTeamates
HotkeyEntry 0,1,0,'D',EnumDungeonEntities,AttackEnemy
HotkeyEntry 0,1,0,'E',InstKill,0
HotkeyEntry 0,0,0,VK_OEM_3,InfiniteDurability,0
HotkeyEntry 0,1,0,'1',AdjustCriticalHitrate,0
HotkeyEntry 0,1,0,'2',FastHeal,0
HotkeyEntry 0,1,0,'3',RemoveCD,0
HotkeyEntry 0,1,0,'4',ClearChallengeQuests,0
HotkeyEntry 0,1,0,'5',SubmitChallengeQuest,0
HotkeyEntry 0,1,0,VK_OEM_PLUS,AdjustSpeed,1
HotkeyEntry 0,1,0,VK_OEM_MINUS,AdjustSpeed,-1
HotkeyEntry 0,0,0,VK_F1,ClearAcceptedQuests,0
HotkeyEntry 0,0,0,VK_F6,ToggleAutoPickup,
endHk:
include 'BaseAddresses.ASM'
