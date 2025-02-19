; boot.asm - An experimental operating system I made because my actual one had too much compilation errors
; for 1 o'clock in the morning lmao, anyway, Guide:
; It prints "Hello, World!" on boot and then enters a loop where it:
;   - Displays a prompt ("cmd> ")
;   - Reads a line of input (up to 64 characters)
;   - If the command is "clear", it clears the screen.
;   - If the command is "help", it prints available commands.
;   - If the command is "version", it displays the bootloader's version.
;   - Otherwise, it prints "Unknown command".
;
; Assemble with:
;   nasm -f bin boot.asm -o boot.img
;
; Run with:
;   qemu-system-x86_64 -drive format=raw,file=boot.img
;
; ----------------------------------------------------------------------------

org 0x7c00           ; BIOS loads the boot sector at 0x7C00

start:
    cli             ; Disable interrupts during setup
    xor ax, ax
    mov ds, ax      ; DS = 0 so our data (labels) are correctly referenced

    ; Print welcome message:
    ; "GoodOS GoodCommandLineInterface has been loaded"
    mov si, hello_msg
    call print_string

    ; Print newline (CR + LF)
    mov ah, 0x0E
    mov al, 0x0D   ; Carriage Return
    int 0x10
    mov al, 0x0A   ; Line Feed
    int 0x10

command_loop:
    ; Display the command prompt ("cmd> ")
    mov si, prompt_msg
    call print_string

    ; Read a line of input into input_buffer.
    call read_line

    ; Check if input equals "clear"
    mov si, input_buffer
    mov di, clear_cmd
    call strcmp
    cmp ax, 0
    je do_clear

    ; Check if input equals "help"
    mov si, input_buffer
    mov di, help_cmd
    call strcmp
    cmp ax, 0
    je do_help

    ; Check if input equals "version"
    mov si, input_buffer
    mov di, version_cmd
    call strcmp
    cmp ax, 0
    je do_version

    ; If not recognized, print "Unknown command"
    mov si, unknown_cmd
    call print_string

    jmp command_loop

do_clear:
    call clear_screen
    jmp command_loop

do_help:
    mov si, help_msg
    call print_string
    jmp command_loop

do_version:
    mov si, version_msg
    call print_string
    jmp command_loop

; --------------------------------------------------
; Subroutine: print_string
; Prints a null-terminated string pointed to by SI.
; --------------------------------------------------
print_string:
print_string_loop:
    lodsb               ; Load byte at DS:SI into AL and increment SI
    cmp al, 0         ; Check for end of string
    je print_string_done
    mov ah, 0x0E      ; BIOS teletype output function
    int 0x10          ; Print the character in AL
    jmp print_string_loop
print_string_done:
    ret

; --------------------------------------------------
; Subroutine: read_line
; Reads a line from the keyboard into input_buffer (max 64 chars).
; Echoes each keystroke and terminates on Enter (0x0D).
; Afterwards, prints a newline.
; --------------------------------------------------
read_line:
    mov di, input_buffer
    mov cx, 64           ; Maximum number of characters to read
read_line_loop:
    mov ah, 0x00         ; BIOS: Wait for a key press
    int 0x16             ; Key pressed is returned in AL
    cmp al, 0x0D         ; Check for Enter key (Carriage Return)
    je read_line_done
    ; Echo the character on screen:
    mov ah, 0x0E
    int 0x10
    ; Store the character in the buffer:
    mov [di], al
    inc di
    dec cx
    jz read_line_done   ; If buffer is full, finish input
    jmp read_line_loop
read_line_done:
    mov byte [di], 0     ; Null-terminate the input string
    ; Print newline (CR + LF)
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

; --------------------------------------------------
; Subroutine: strcmp
; Compares two null-terminated strings:
;   - First string at DS:SI.
;   - Second string at DS:DI.
; Returns AX = 0 if equal, nonzero otherwise.
; --------------------------------------------------
strcmp:
strcmp_loop:
    mov al, [si]        ; Get a character from the first string.
    mov bl, [di]        ; Get a character from the second string.
    cmp al, bl
    jne not_equal
    cmp al, 0           ; End-of-string reached?
    je equal
    inc si
    inc di
    jmp strcmp_loop
not_equal:
    mov ax, 1           ; Nonzero means strings differ.
    ret
equal:
    xor ax, ax          ; AX = 0 indicates equality.
    ret

; --------------------------------------------------
; Subroutine: clear_screen
; Clears the screen using BIOS interrupt 0x10, function 0x06.
; --------------------------------------------------
clear_screen:
    mov ah, 0x06
    mov al, 0           ; 0 = clear entire screen.
    mov bh, 0x07        ; Text attribute (white on black).
    xor cx, cx          ; Upper left corner (row 0, col 0).
    ; Lower right corner: row 24, col 79 (80x25 text mode).
    mov dx, 0x184F      ; DX = (24 << 8) | 79.
    int 0x10
    ret

; --------------------------------------------------
; Data Section
; --------------------------------------------------
hello_msg   db "GoodOS GoodCommandLineInterface has been loaded", 0
prompt_msg  db "gcli> ", 0
unknown_cmd db "Unknown command", 0x0D, 0x0A, 0
clear_cmd   db "clear", 0
help_cmd    db "help", 0
version_cmd db "version", 0
help_msg    db "Available commands: clear, help, version", 0x0D, 0x0A, 0
version_msg db "GoodOS MLBLOS v0.1", 0x0D, 0x0A, 0

; Reserve an input buffer of 64 bytes.
input_buffer times 64 db 0

; --------------------------------------------------
; Boot Sector Padding and Signature
; Ensure the boot sector is exactly 512 bytes.
; --------------------------------------------------
times 510 - ($ - $$) db 0
dw 0xAA55
