# DOS Large Font Clock (x86 Assembly)

A memory-resident digital clock application for MS-DOS, written in x86 Assembly (TASM).

## Overview
This application displays a large-font digital clock (HH:MM:SS) on the DOS screen. It demonstrates direct hardware manipulation and interrupt handling in a 16-bit real-mode environment.

## Features
- **Large Fonts**: Custom 5x7 block characters drawn directly to video memory.
- **Interrupt Driven**: Hooks INT 1Ch (System Timer Tick) for background updates approx 18.2 times/second.
- **Direct Video Access**: Writes directly to the VGA text buffer at segment `0xB800` for high performance.
- **Clean Exit**: Restores the original interrupt vector and video mode upon exiting.

## Technical Details
- **Architecture**: 16-bit Real Mode x86 Assembly.
- **Assembler**: Borland Turbo Assembler (TASM) 4.1.
- **Memory Model**: SMALL (One code segment, one data segment).
- **Time Source**: Reads directly from the CMOS Real-Time Clock (RTC) ports `0x70` and `0x71`.

## Build Instructions
To build this application, you need Borland Turbo Assembler (TASM) and Turbo Linker (TLINK).

1.  **Assemble**:
    ```bash
    tasm /zi clock.asm
    ```
2.  **Link**:
    ```bash
    tlink clock.obj
    ```

## Usage
Run the executable from the DOS command prompt:
```bash
clock.exe
```
- The clock will appear centered on the screen.
- Press **ESC** to exit the application and return to DOS.

## File Structure
- `clock.asm`: Main source code.
- `README.md`: This documentation file.
- `timehook.md`: A detailed technical reference guide used during development, explaining the INT 1Ch timer interrupt hook mechanism.

## Further Reading
For a deep dive into the interrupt hooking mechanism used in this project, specifically how **INT 1Ch** is intercepted safely in Real Mode, please refer to [timehook.md](timehook.md).

