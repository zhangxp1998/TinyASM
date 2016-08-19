proc Encrypt Addr,value
     mov eax,[Addr]
     and eax,0xF
     shr eax,2;divide eax by 4
     mov eax,[ENC_CALLS+eax*4]

     mov ecx,[Addr]
     lea edx,[ecx+4]
     push edx
     lea edx,[value]
     push edx
     call eax
     ret
endp

proc Encrypt64 Addr,pValue
     mov eax,[ENC_CALLS]
     sub eax,0xD0

     mov ecx,[Addr]
     lea edx,[ecx+8]
     push edx
     push [pValue]
     call eax
     ret
endp

proc Decrypt Addr
     local value dd ?
     mov eax,[Addr]
     and eax,0xF
     shr eax,2;divide eax by 4
     mov eax,[DEC_CALLS+eax*4]

     mov ecx,[Addr]
     lea edx,[value]
     push edx
     lea edx,[ecx+4]
     push edx
     call eax
     mov eax,[value]
     ret
endp

proc Decrypt64 Addr,pValue
     mov eax,[DEC_CALLS]
     add eax,0x320

     push [pValue]
     mov ecx,[Addr]
     lea edx,[ecx+8]
     push edx
     call eax
     ret
endp

macro SEND_BUFFER_CALL value,b
{
	mov ecx,[PACKET_BASEADDR]
	push b
	push value
	call [BUFFER_CALL]
}

macro SEND_ENCRYPT_CALL value,len
{

	push value
	mov ecx,[PACKET_BASEADDR]
	if len eq 1
	call dword[ENCRYPT_PACKET_CALL]
	else if len eq 2
	call dword[ENCRYPT_PACKET_CALL+4]
	else
	call dword[ENCRYPT_PACKET_CALL+8]
	end if

}

proc SEND_ENCRYPT_CALL_LL value,len
     mov ecx,[PACKET_BASEADDR]
     mov eax,[len]
     add [ecx+0x2BCC2C],eax
     push [len]
     lea eax,[value]
     push eax
     call [ENCRYPT_PACKET_CALL_LL]
     ret
endp

macro SEND_PACKET_CALL
{
	call [PACKET_CALL]
}

macro GetItemId itemObj
{
	mov ecx,obj
	mov eax,[ecx]
	call [eax+0x4C]
}

macro PickupItem itemObj
{
	push itemObj
	mov ecx,[BAGPACK_BASEADDR]
	call [PICKUP_CALL]
}
LEFT = 0
RIGHT = 1
UP = 2
DOWN = 3

proc AdvanceRoomCall dir
     push -1
     push -1
     push [dir]
     mov ecx,[SHOP_BASEADDR-0x8]
     mov ecx,[ecx+0x20A024]
     call [ADVANCE_ROOM_CALL]
     ret
endp

proc SellItem index,quantity
     SEND_BUFFER_CALL 22,0
     SEND_ENCRYPT_CALL dword 0,1
     SEND_ENCRYPT_CALL [index],2
     SEND_ENCRYPT_CALL [quantity],2
     mov eax,[index]
     add eax,[quantity]
     SEND_ENCRYPT_CALL eax,4
     SEND_PACKET_CALL
     ret
endp

proc CompleteQuest id,count
     .while [count]>0
	    SEND_BUFFER_CALL 33,0
	    SEND_ENCRYPT_CALL 33,2
	    SEND_ENCRYPT_CALL [id],2
	    SEND_ENCRYPT_CALL -1,1
	    SEND_ENCRYPT_CALL -1,1
	    SEND_PACKET_CALL
	    dec [count]
     .endw
     ret
endp