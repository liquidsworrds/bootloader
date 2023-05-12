[org 0x7c00]

KERNEL_OFFSET  equ 0x1000
VIDEO_MEMORY   equ 0xb800
WHITE_ON_BLACK equ 0x0f

mov [BOOT_DRIVE], dl ; bios stores bootdrive in dl
mov bp, 0x8000
mov sp, bp

mov bx, MSG_RMODE
call print

call load_kernel
call switch_to_pm
jmp $


[bits 16]

load_kernel:
    mov bx, MSG_LOAD_KERNEL
    call print
    call print_newline

    mov bx, KERNEL_OFFSET
    mov dh, 16
    mov dl, [BOOT_DRIVE]
    call disk_read
    ret

[bits 32]
    
BEGIN_PM:
    mov ebx, MSG_PMODE
    call print_pm
    call KERNEL_OFFSET
    jmp $

print_pm:
    pusha
    mov edx, VIDEO_MEMORY

.loop:
    mov al, [ebx]
    mov ah, WHITE_ON_BLACK

    cmp al, 0
    je .done
    
    mov [edx], ax   ; Store character and attribute in video memory
    add ebx, 1      ; Next character
    add edx, 2      ; Next video memory position

    jmp .loop

.done:
    popa 
    ret

disk_read:

    push dx         ; Store how many sectors were requested to be read to the stack

    mov ah, 0x02    ; BIOS read sector function
    mov al, dh      ; Reads dh sectors
    mov ch, 0x00    ; Select cylinder 0
    mov dh, 0x00    ; Select head 0
    mov cl, 0x02    ; Start reading from sector 2

    int 0x13

    jc disk_error   ; Carry flag is set if error

    pop dx          ; Retrieve dx
    cmp dh, al      ; AL -> sectors read  
    jne disk_error  ; DH -> sectors expected
    ret

[bits 16]

disk_error:
    jmp disk_loop

sector_error:
    jmp disk_loop

disk_loop:

    mov bx, DISK_ERR_MSG
    call print
    jmp $

print:
    pusha

.loop:
    mov al, [bx]
    cmp al, 0
    je .done

    add bx, 1
    jmp .loop

.done:
    popa
    ret

print_newline:
    pusha

    mov ah, 0x0e
    mov al, 0x0a        ; Newline
    int 0x10

    mov al, 0x0d        ; Carriage return
    int 0x10

    popa
    ret
    
; GDT    

gdt_start:
    dq 0x0

gdt_code:
    dw 0xffff
    dw 0x0
    db 0x0
    db 10011010b
    db 11001111b
    db 0x0

gdt_data:
    dw 0xffff
    dw 0x0
    db 0x0
    db 10011010b
    db 11001111b
    db 0x0

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

; Switching to 32bit protected mode

switch_to_pm:
    cli                     ; Disables interrupts
    lgdt [gdt_descriptor]   ; Load the gdt 

    mov eax, cr0
    or  eax, 0x1            ; Sets the first bit to cr0 to enable protected mode
    mov cr0, eax

    jmp CODE_SEG:init_pm    ; Jumps to the new segment (32 bit)


[bits 32]

init_pm:
    mov ax, DATA_SEG        ; Updating the segment registers
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov ebp, 0x9000         ; Updating stack 
    mov esp, ebp

    call BEGIN_PM

; Variables
BOOT_DRIVE db 0
DISK_ERR_MSG db "Disk read error!", 0
MSG_PMODE db "Started in 16 bit real mode", 0
MSG_RMODE db "Started in 32 bit protected mode", 0
MSG_LOAD_KERNEL db "Loading the kernel", 0

times 510-($-$$) db 0
dw 0xaa55
