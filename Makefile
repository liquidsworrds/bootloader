# $@ = target file
# $< = first dependency
# $^ = all dependencies

# First rule is the one executed when no parameters are fed to the Makefile
all: run

kernel.bin: kernel_entry.o kernel.o
	ld -m elf_i386 -o $@ -Ttext 0x1000 $^ --oformat binary

kernel_entry.o: ./kernel/kernel_entry.asm
	nasm $< -f elf -o $@

kernel.o: ./kernel/kernel.c
	gcc -m32 -ffreestanding -c $< -o $@

boot.bin: ./bootloader/boot.asm
	nasm $< -f bin -o $@

os_image.bin: boot.bin kernel.bin
	cat $^ > $@

run: os_image.bin
	qemu-system-i386 -fda $<

clean:
	$(RM) *.bin *.o *.dis
