; =============================================================
; Large Font Clock Application
; Accesses Video Memory Directly (0B800h)
; Hooks Timer Interrupt (1Ch) for Updates
; Only redraws when seconds change to reduce flicker
; =============================================================

.MODEL SMALL
.STACK 200h

; -------------------------------------------------------------
; Data Segment
; -------------------------------------------------------------
.DATA
    ; Configuration
    VideoSeg     dw 0B800h
    StartRow     dw 9
    StartCol     dw 20
    
    ; Colors
    BlockChar    db 219     ; Solid block character (ASCII 219)
    BlockColor   db 0Fh     ; Bright White on Black
    
    ExitMsg      db 'Press ESC to exit...', '$'

    ; Font Data (5x7 bitmasks - Top to Bottom)
    FontTable label byte
    ; 0
    db 0Eh, 11h, 19h, 15h, 13h, 11h, 0Eh
    ; 1
    db 04h, 0Ch, 04h, 04h, 04h, 04h, 0Eh
    ; 2
    db 0Eh, 11h, 01h, 02h, 04h, 08h, 1Fh
    ; 3
    db 1Fh, 02h, 04h, 02h, 01h, 11h, 0Eh
    ; 4
    db 02h, 06h, 0Ah, 12h, 1Fh, 02h, 02h
    ; 5
    db 1Fh, 10h, 1Eh, 01h, 01h, 11h, 0Eh
    ; 6
    db 06h, 08h, 10h, 1Eh, 11h, 11h, 0Eh
    ; 7
    db 1Fh, 01h, 02h, 04h, 08h, 08h, 08h
    ; 8
    db 0Eh, 11h, 11h, 0Eh, 11h, 11h, 0Eh
    ; 9
    db 0Eh, 11h, 11h, 0Fh, 01h, 02h, 0Ch
    ; : (Index 10)
    db 00h, 0Ch, 0Ch, 00h, 0Ch, 0Ch, 00h

; -------------------------------------------------------------
; Code Segment
; -------------------------------------------------------------
.CODE

; Store in code segment for CS: access
OldInt1C_Off dw ?
OldInt1C_Seg dw ?
LastSeconds  db 0FFh        ; Last drawn seconds value (0FFh = never drawn)

start:
    ; Initialize DS
    mov ax, @data
    mov ds, ax

    ; Clear Screen (Mode 3)
    mov ax, 0003h
    int 10h

    ; Hide Cursor
    mov ah, 01h
    mov ch, 20h 
    int 10h

    ; Print Exit Message
    mov ah, 02h
    mov bh, 0
    mov dh, 24
    mov dl, 0
    int 10h
    
    mov dx, OFFSET ExitMsg
    mov ah, 09h
    int 21h

    ; --- Install Interrupt Hook ---
    mov ax, 351Ch
    int 21h
    mov cs:OldInt1C_Seg, es
    mov cs:OldInt1C_Off, bx

    push ds
    push cs
    pop ds
    mov dx, OFFSET TimerHandler
    mov ax, 251Ch
    int 21h
    pop ds

MainLoop:
    mov ah, 01h
    int 16h
    jz MainLoop
    
    mov ah, 00h
    int 16h
    cmp al, 27
    je RestoreAndExit
    jmp MainLoop

RestoreAndExit:
    mov dx, cs:OldInt1C_Off
    mov ax, cs:OldInt1C_Seg
    mov ds, ax
    mov ax, 251Ch
    int 21h

    mov ax, 0003h
    int 10h

    mov ah, 4Ch
    mov al, 0
    int 21h

; -------------------------------------------------------------
; Helpers
; -------------------------------------------------------------

BCDToDigits PROC NEAR
    mov ah, al
    and al, 0F0h
    shr al, 4
    and ah, 0Fh
    ret
BCDToDigits ENDP

; DrawDigit
; Input: BL = Digit Index (0-10), DI = Video offset
; Assumes: DS = @data, ES = 0B800h
DrawDigit PROC NEAR
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    xor bh, bh
    mov al, 7
    mul bl
    mov si, OFFSET FontTable
    add si, ax
    
    mov cx, 7
DrawRowLoop:
    push cx
    push di
    
    lodsb
    
    mov cx, 5
DrawPixelLoop:
    test al, 10h
    jz DrawSpace
    
    mov dl, BlockChar
    mov dh, BlockColor
    mov es:[di], dx
    jmp NextPixel

DrawSpace:
    mov word ptr es:[di], 0020h

NextPixel:
    add di, 2
    shl al, 1
    loop DrawPixelLoop
    
    pop di
    add di, 160
    pop cx
    loop DrawRowLoop

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawDigit ENDP

; -------------------------------------------------------------
; Timer Handler (Interrupt 1Ch)
; -------------------------------------------------------------
TimerHandler PROC FAR
    pushf
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    cld

    ; Read current seconds from CMOS
    mov al, 0
    out 70h, al
    in al, 71h
    
    ; Compare with last drawn value
    cmp al, cs:LastSeconds
    jne DoDraw              ; Different second, need to redraw
    jmp SkipDraw            ; Same second, skip

DoDraw:
    ; Save new seconds value
    mov cs:LastSeconds, al

    ; Set up segments
    mov bx, @data
    mov ds, bx
    mov bx, 0B800h
    mov es, bx

    ; Convert and save seconds
    call BCDToDigits
    mov cl, al
    mov ch, ah
    push cx

    ; Read and save minutes
    mov al, 2
    out 70h, al
    in al, 71h
    call BCDToDigits
    mov cl, al
    mov ch, ah
    push cx

    ; Read hours
    mov al, 4
    out 70h, al
    in al, 71h
    call BCDToDigits
    mov cl, al
    mov ch, ah

    ; Calculate starting video offset
    mov ax, StartRow
    mov bx, 80
    mul bx
    add ax, StartCol
    shl ax, 1
    mov di, ax

    ; Draw HH:MM:SS
    mov bl, cl
    call DrawDigit
    
    add di, 12
    mov bl, ch
    call DrawDigit

    add di, 12
    mov bl, 10
    call DrawDigit

    pop cx
    add di, 8
    mov bl, cl
    call DrawDigit

    add di, 12
    mov bl, ch
    call DrawDigit

    add di, 12
    mov bl, 10
    call DrawDigit

    pop cx
    add di, 8
    mov bl, cl
    call DrawDigit

    add di, 12
    mov bl, ch
    call DrawDigit

SkipDraw:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    popf

    jmp dword ptr cs:[OldInt1C_Off]
TimerHandler ENDP

END start