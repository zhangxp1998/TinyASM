struct PEB
	reserved dd ?,?,?
	LDR dd ?
ends

struct LIST_ENTRY
       FLink dd ?
       BLink dd ?
ends

struct LDR
       reserved dd ?,?,?

       LoadOrderList LIST_ENTRY
       MemoryOrderList LIST_ENTRY
       InitialOrderList LIST_ENTRY
ends

struct LDR_DATA_TABLE_ENTRY
       LoadOrderList LIST_ENTRY
       MemoryOrderList LIST_ENTRY
       InitialOrderList LIST_ENTRY
       DllBase dd ?
       EntryPoint dd ?
       SizeOfImage dd ?
       FullDllName dd ?,?
       BaseDllName dd ?,?
       Flags dd ?
       unknown dd ?
       HashTableEntry LIST_ENTRY
ends

struct IMAGE_DOS_HEADER
      e_magic		dw	?
      e_cblp		dw	?
      e_cp		dw	?
      e_crlc		dw	?
      e_cparhdr 	dw	?
      e_minalloc	dw	?
      e_maxalloc	dw	?
      e_ss		dw	?
      e_sp		dw	?
      e_csum		dw	?
      e_ip		dw	?
      e_cs		dw	?
      e_lfarlc		dw	?
      e_ovno		dw	?
      e_res		dw   4 dup(?)
      e_oemid		dw	?
      e_oeminfo 	dw	?
      e_res2		dw  10 dup(?)
      e_lfanew		dd	?
ends

struct IMAGE_FILE_HEADER

  .Machine		 dw   ? 
  .NumberOfSections	 dw   ? 
  .TimeDateStamp	 dd   ? 
  .PointerToSymbolTable  dd   ? 
  .NumberOfSymbols	 dd   ? 
  .SizeOfOptionalHeader  dw   ? 
  .Characteristics	 dw   ? 
ends
IMAGE_NUMBEROF_DIRECTORY_ENTRIES = 16
struct IMAGE_OPTIONAL_HEADERS

  Magic 			dw	?
  MajorLinkerVersion		db	?
  MinorLinkerVersion		db	?
  SizeOfCode			dd	?
  SizeOfInitializedData 	dd	?
  SizeOfUninitializedData	dd	?
  AddressOfEntryPoint		dd	?
  BaseOfCode			dd	?
  BaseOfData			dd	?
  ImageBase			dd	?
  SectionAlignment		dd	?
  FileAlignment 		dd	?
  MajorOperatingSystemVersion	dw	?
  MinorOperatingSystemVersion	dw	?
  MajorImageVersion		dw	?
  MinorImageVersion		dw	?
  MajorSubsystemVersion 	dw	?
  MinorSubsystemVersion 	dw	?
  Win32VersionValue		dd	?
  SizeOfImage			dd	?
  SizeOfHeaders 		dd	?
  CheckSum			dd	?
  Subsystem			dw	?
  DllCharacteristics		dw	?
  SizeOfStackReserve		dd	?
  SizeOfStackCommit		dd	?
  SizeOfHeapReserve		dd	?
  SizeOfHeapCommit		dd	?
  LoaderFlags			dd	?
  NumberOfRvaAndSizes		dd	?
  ;.DataDirectory		  IMAGE_DATA_DIRECTORY IMAGE_NUMBEROF_DIRECTORY_ENTRIES dup(<>) 
  ;.DataDirectory		  IMAGE_DATA_DIRECTORY IMAGE_NUMBEROF_DIRECTORY_ENTRIES 
  ;.DataDirectory		  IMAGE_DATA_DIRECTORY [IMAGE_NUMBEROF_DIRECTORY_ENTRIES] dup ? 
  ;DataDirectory		 IMAGE_DATA_DIRECTORY IMAGE_NUMBEROF_DIRECTORY_ENTRIES dup ?
  ;.DataDirectory		  IMAGE_DATA_DIRECTORY rept 16 (?) 
ends

struct IMAGE_NT_HEADERS
  Signature	    dd			 ?
  ;.FileHeader	      IMAGE_FILE_HEADER       <> 
  FileHeader	    IMAGE_FILE_HEADER	 ?
  ;.OptionalHeader    IMAGE_OPTIONAL_HEADER32 <> 
  OptionalHeader    IMAGE_OPTIONAL_HEADERS ?
ends

