global long_mode_start

section .text
bits 64
long_mode_start:

         ; print "DEBASA OS" to the screen
        mov dword [0xb8546], 0x30453144
        mov dword [0xb854a], 0x30413142
        mov dword [0xb854e], 0x30413153
        mov dword [0xb8552], 0x304f3120 
        mov dword [0xb8556], 0x00003053
        hlt
