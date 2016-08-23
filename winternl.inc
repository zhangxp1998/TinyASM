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

