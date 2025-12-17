# DOS Timer Interrupt Hook Reference
*A Technical Guide to Hooking INT 1Ch in x86 Real Mode*

---

## 1. Overview
**INT 1Ch** is the "User Timer Tick" interrupt. It is invoked approximately **18.2 times per second** by the system's hardware timer interrupt (INT 08h). Hooking this interrupt allows applications to perform periodic background tasks—such as updating a clock display—without interfering with the critical system timekeeping functions of INT 08h.

### Key Concepts

#### Interrupt Vector Table (IVT)
The IVT resides in the first 1024 bytes of memory (`0000:0000` to `0000:03FF`). Each entry is a 4-byte far pointer (Offset:Segment) to an interrupt handler.
*   **INT 1Ch Address**: `0000:0070`

#### Interrupt Chaining
"Chaining" refers to the practice of calling the original interrupt handler either before or after your custom code executes. This ensures that other resident programs or system services that also rely on this interrupt continue to function correctly.

---

## 2. Critical Requirements

When writing an interrupt handler in assembly, you must strictly adhere to the following rules to prevent system crashes.

### I. Save and Restore All Registers
Your handler can interrupt the CPU at any moment. The interrupted program expects all registers to remain unchanged.

```assembly
pushf       ; Save flags
push ax
push bx
push cx
push dx
push si
push di
push ds
push es

; ... Your Handler Code ...

pop es      ; Restore in reverse order
pop ds
pop di
pop si
pop dx
pop cx
pop bx
pop ax
popf        ; Restore flags
```

### II. Handle Direction Flag
The Direction Flag (DF) determines whether string operations (`LODSB`, `STOSW`, etc.) increment or decrement pointers. The state of DF is unknown when your handler starts. Always clear it if you use string instructions.

```assembly
cld         ; Clear Direction Flag (Forward processing)
```

### III. Manage Segments Explicitly
You cannot assume `DS` points to your data segment. You must explicitly load your segment addresses. Variables stored in the code segment (CS) must be accessed with a segment override.

```assembly
; Accessing a variable stored in the Code Segment
mov ax, cs:OldInt1C_Off

; Setting up DS for your data
mov ax, @data
mov ds, ax
```

### IV. Chain Correctly
Use a specific `JMP` instruction to chain to the old handler. Do **not** use `RETF` or `IRET` if you intend to chain, as this effectively terminates the interrupt chain prematurely or corrupts the stack if not handled perfectly.

```assembly
; Correct Chaining Logic
jmp dword ptr cs:[OldInt1C_Off]
```

---

## 3. Implementation Patterns

### Standard Handler Template
Below is a robust template for a safe interrupt handler.

```assembly
; defined in .DATA or .CODE
OldInt1C_Off dw ?
OldInt1C_Seg dw ?

MyHandler PROC FAR
    ; 1. Save Environment
    pushf
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    cld             ; Enforce forward direction

    ; 2. Setup Context
    mov ax, @data
    mov ds, ax
    mov ax, 0B800h  ; Example: access video memory
    mov es, ax

    ; 3. Perform Custom Logic
    ; (Keep this section short and fast!)

    ; 4. Restore Environment
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    popf

    ; 5. Chain to Old Handler
    jmp dword ptr cs:[OldInt1C_Off]
MyHandler ENDP
```

### Installing the Hook
Use DOS function **35h** to get the current vector, and **25h** to set your new one.

```assembly
; Get current vector (Save it!)
mov ax, 351Ch
int 21h
mov cs:OldInt1C_Seg, es
mov cs:OldInt1C_Off, bx

; Set new vector
push ds
mov ax, cs      ; If handler is in CS
mov ds, ax
mov dx, OFFSET MyHandler
mov ax, 251Ch
int 21h
pop ds
```

### Restoring the Hook
**Critically important**: You must restore the original vector before your program exits.

```assembly
push ds
mov dx, cs:OldInt1C_Off
mov ax, cs:OldInt1C_Seg
mov ds, ax
mov ax, 251Ch
int 21h
pop ds
```

---

## 4. Performance & Common Pitfalls

### Performance Tips
*   **Minimize Logic**: The handler runs ~18 times/second. Keep it extremely lightweight.
*   **Conditional Updates**: Only write to video memory if the data has actually changed (e.g., specific second changed) to reduce flicker.
*   **Avoid Blocking**: Never wait for I/O operations (like VSync) inside the interrupt.

### Visual Checklist
- [x] **Stack Parity**: Are all `PUSH` instructions matched with a `POP`?
- [x] **Segment Overrides**: Are you using `CS:` to access variables if `DS` isn't set?
- [x] **Chain via JMP**: Are you jumping to the old vector instead of `CALL`ing it?
- [x] **Restore Vector**: Is the restoration code guaranteed to run on exit?