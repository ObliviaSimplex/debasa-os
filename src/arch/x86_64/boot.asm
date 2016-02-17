global start
extern long_mode_start
        
section .text
bits 32
start:
        ; initialize stack pointer
        mov esp, stack_top

        call check_multiboot
        call check_cpuid
        call check_long_mode

        call set_up_page_tables
        call enable_paging

        call set_up_SSE
        
        ; load the 64-bit GDT
        lgdt [gdt64.pointer]

        ; update selectors
        mov ax, gdt64.data      ; new
        mov ss, ax              ; stack selector
        mov ds, ax              ; data selector
        mov es, ax              ; extra selector

        jmp gdt64.code:long_mode_start ; to set the code selector in 64bit mode

        ; print "OK", in white on green
        mov dword [0xb8000], 0x2f4b2f4f        
        ; print "DEBASA OS" to the screen ;; moved to 64bit boot code
        ; mov dword [0xb8546], 0x30453144
        ; mov dword [0xb854a], 0x30413142
        ; mov dword [0xb854e], 0x30413153
        ; mov dword [0xb8552], 0x304f3120 
        ; mov dword [0xb8556], 0x00003053         
        
        hlt
        
        

;;;      Prints "ERR: " and the given error code to the screen and hangs 
error:
        mov dword [0xb8000], 0x4f524f45
        mov dword [0xb8004], 0x4f3a4f52
        mov dword [0xb8008], 0x4f204f20 
        mov byte  [0xb800a], al 

check_multiboot:
        cmp eax, 0x36d76289
        jne .no_multiboot
        ret
.no_multiboot:
        mov al, "0"
        jmp error

check_cpuid:
        ; check if CPUID is supported by attempting to flip the ID
        ; bit (bit 21) in the FLAGS register. If we can flip it, then
        ; CPUID is available.

        ; Copy FLAGS to EAX via stack
        pushfd
        pop eax

        ; Copy to ECX as well for comparing later on
        mov ecx, eax

        ; Flip the ID bit
        xor eax, 1 << 21

        ; copy EAX to FLAGS via the stack
        push eax
        popfd

        ; copy FLAGS back to EAX (with the flipped bit if CPUID is sup.)
        pushfd
        pop eax

        ; Restore FLAGS from the old version stored in ECX (flipping the
        ; ID bit back if it was ever flipped).
        push ecx
        popfd

        ; Compare EAX and ECX. If they are equal then that means the bit
        ; wasn't flipped, and CPUID isn't supported
        cmp eax, ecx
        je .no_cpuid
        ret

.no_cpuid:
        mov al, "1"
        jmp error


check_long_mode:
        ; test if extended processor info is available
        mov eax, 0x80000000     ; implicit argument for cpuid
        cpuid
        cmp eax, 0x80000001     ; it needs to be at least 0x80000001
        jb .no_long_mode        ; if it's less, the CPU is too old for long

        ; use extended info to test if long mode is available
        mov eax, 0x80000001     ; argument for extended processor info
        cpuid                   ; returns various feature bits in ecx, edx
        test edx, 1 << 29       ; test if the LM-bit is set in the D-reg
        jz .no_long_mode        ; If it's not set, there is no long mode
        ret

.no_long_mode:
        mov al, "2"
        jmp error

        
set_up_page_tables:
        ; map first P4 entry to P3 table
        mov eax, p3_table
        or eax, 0b11            ; present + writeable
        mov [p4_table], eax

        ; map first P3 entry to P2 table
        mov eax, p2_table
        or eax, 0b11
        mov [p3_table], eax

        mov ecx, 0

.map_p2_table:
        ; map ecx-th P2 entry to a huge page that starts at address
        ; 2MiB*ecx
        mov eax, 0x200000       ; 2MiB
        mul ecx                 ; start address of ecx-th page
        or eax, 0b10000011      ; present + writeable + huge
        mov [p2_table + ecx * 8], eax ; map ecx-th entry

        inc ecx                 ; increase counter
        cmp ecx, 512            ; if counter == 512, the whole P2 is mapped
        jne .map_p2_table
                
        ret

enable_paging:
        ; load P4 to cr3 register (cpu uses this to access P4 table)
        mov eax, p4_table
        mov cr3, eax

        ; enable PAE-flag in cr4 (physical address extension)
        mov eax, cr4
        or eax, 1 << 5
        mov cr4, eax

        ; set the long mode bit in the EFER MSR (model specific register)
        mov ecx, 0xC0000080
        rdmsr
        or eax, 1 << 8
        wrmsr

        ; enable paging in the cr0 register
        mov eax, cr0
        or eax, 1 << 31
        mov cr0, eax

        ret


set_up_SSE:
        ; this bit of code is from OSDev Wiki:
        ; check for SSE
        mov eax, 0x1
        cpuid
        test edx, 1<<25
        jz .no_SSE

        ; enable SSE
        mov eax, cr0
        and ax, 0xFFFB          ; clear coprocessor emulation CR0.EM
        or ax, 0x2              ; set coprocessor monitoring CRO.MP
        mov cr0, eax
        mov eax, cr4
        or ax, 3<<9             ; set CR4.OSFXSR and CR4.OSXMMEXCPT at same time
        mov cr4, eax

        ret

.no_SSE:
        mov al, "a"
        jmp error

section .rodata
gdt64:
        dq 0                    ; zero entry
.code: equ $ - gdt64                                                 ; new
        dq (1<<44) | (1<<47) | (1<<41) | (1<<41) | (1<<43) | (1<<53) ; code seg
.data: equ $ - gdt64                                                 ; new
        dq (1<<44) | (1<<47) | (1<<41)                               ; data seg
.pointer:
        dw $ - gdt64 - 1
        dq gdt64
        
;;; to reserve space for stack memory

section .bss
align 4096
p4_table:
        resb 4096
p3_table:
        resb 4096
p2_table:
        resb 4096

stack_bottom:
        resb 64
stack_top:
        
        
