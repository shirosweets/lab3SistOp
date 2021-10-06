#Folders
K=kernel
U=user
L=libs
MKFS=mkfs

OBJS = \
	$(K)/bio.o\
	$(K)/console.o\
	$(K)/exec.o\
	$(K)/file.o\
	$(K)/fs.o\
	$(K)/ide.o\
	$(K)/ioapic.o\
	$(K)/kalloc.o\
	$(K)/kbd.o\
	$(K)/lapic.o\
	$(K)/log.o\
	$(K)/main.o\
	$(K)/mp.o\
	$(K)/picirq.o\
	$(K)/pipe.o\
	$(K)/proc.o\
	$(K)/sleeplock.o\
	$(K)/spinlock.o\
	$(K)/string.o\
	$(K)/swtch.o\
	$(K)/syscall.o\
	$(K)/sysfile.o\
	$(K)/sysproc.o\
	$(K)/trapasm.o\
	$(K)/trap.o\
	$(K)/uart.o\
	$(K)/vectors.o\
	$(K)/vm.o\

# Cross-compiling (e.g., on Mac OS X)
# TOOLPREFIX = i386-jos-elf

# Using native tools (e.g., on X86 Linux)
#TOOLPREFIX = 

# Try to infer the correct TOOLPREFIX if not set
ifndef TOOLPREFIX
TOOLPREFIX := $(shell if i386-jos-elf-objdump -i 2>&1 | grep '^elf32-i386$$' >/dev/null 2>&1; \
	then echo 'i386-jos-elf-'; \
	elif objdump -i 2>&1 | grep 'elf32-i386' >/dev/null 2>&1; \
	then echo ''; \
	else echo "***" 1>&2; \
	echo "*** Error: Couldn't find an i386-*-elf version of GCC/binutils." 1>&2; \
	echo "*** Is the directory with i386-jos-elf-gcc in your PATH?" 1>&2; \
	echo "*** If your i386-*-elf toolchain is installed with a command" 1>&2; \
	echo "*** prefix other than 'i386-jos-elf-', set your TOOLPREFIX" 1>&2; \
	echo "*** environment variable to that prefix and run 'make' again." 1>&2; \
	echo "*** To turn off this error, run 'gmake TOOLPREFIX= ...'." 1>&2; \
	echo "***" 1>&2; exit 1; fi)
endif

# If the makefile can't find QEMU, specify its path here
# QEMU = qemu-system-i386

# Try to infer the correct QEMU
ifndef QEMU
QEMU = $(shell if which qemu > /dev/null; \
	then echo qemu; exit; \
	elif which qemu-system-i386 > /dev/null; \
	then echo qemu-system-i386; exit; \
	elif which qemu-system-x86_64 > /dev/null; \
	then echo qemu-system-x86_64; exit; \
	else \
	qemu=/Applications/Q.app/Contents/MacOS/i386-softmmu.app/Contents/MacOS/i386-softmmu; \
	if test -x $$qemu; then echo $$qemu; exit; fi; fi; \
	echo "***" 1>&2; \
	echo "*** Error: Couldn't find a working QEMU executable." 1>&2; \
	echo "*** Is the directory containing the qemu binary in your PATH" 1>&2; \
	echo "*** or have you tried setting the QEMU variable in Makefile?" 1>&2; \
	echo "***" 1>&2; exit 1)
endif

CC = $(TOOLPREFIX)gcc
AS = $(TOOLPREFIX)gas
LD = $(TOOLPREFIX)ld
OBJCOPY = $(TOOLPREFIX)objcopy
OBJDUMP = $(TOOLPREFIX)objdump
CFLAGS = -fno-pic -static -fno-builtin -fno-strict-aliasing \
	-O1 -Wall -MD -ggdb -m32 -Werror -fno-omit-frame-pointer \
	$(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector) \
	-I$(L)
ASFLAGS = -m32 -gdwarf-2 -Wa,-divide -I$(L)
# FreeBSD ld wants ``elf_i386_fbsd''
LDFLAGS += -m $(shell $(LD) -V | grep elf_i386 2>/dev/null | head -n 1)

# Disable PIE when possible (for Ubuntu 16.10 toolchain)
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]no-pie'),)
CFLAGS += -fno-pie -no-pie
endif
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]nopie'),)
CFLAGS += -fno-pie -nopie
endif

$(K)/xv6.img: $(K)/bootblock $(K)/kernel
	dd if=/dev/zero of=$(K)/xv6.img count=10000
	dd if=$(K)/bootblock of=$(K)/xv6.img conv=notrunc
	dd if=$(K)/kernel of=$(K)/xv6.img seek=1 conv=notrunc

$(K)/xv6memfs.img: $(K)/bootblock $(K)/kernelmemfs
	dd if=/dev/zero of=$(K)/xv6memfs.img count=10000
	dd if=$(K)/bootblock of=$(K)/xv6memfs.img conv=notrunc
	dd if=$(K)/kernelmemfs of=$(K)/xv6memfs.img seek=1 conv=notrunc

$(K)/bootblock: $(K)/bootasm.S $(K)/bootmain.c
	$(CC) $(CFLAGS) -fno-pic -O -nostdinc -I. -c -o $(K)/bootmain.o $(K)/bootmain.c
	$(CC) $(CFLAGS) -fno-pic -nostdinc -I. -c -o $(K)/bootasm.o $(K)/bootasm.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 -o $(K)/bootblock.o $(K)/bootasm.o $(K)/bootmain.o
	$(OBJCOPY) -S -O binary -j .text $(K)/bootblock.o $(K)/bootblock
	./$(K)/sign.pl $(K)/bootblock

entryother: $(K)/entryother.S
	$(CC) $(CFLAGS) -fno-pic -nostdinc -I. -c -o $(K)/entryother.o $(K)/entryother.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7000 -o $(K)/bootblockother.o $(K)/entryother.o
	$(OBJCOPY) -S -O binary -j .text $(K)/bootblockother.o entryother

initcode: $(U)/initcode.S
	$(CC) $(CFLAGS) -nostdinc -I. -c -o $(U)/initcode.o $(U)/initcode.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0 -o initcode.out $(U)/initcode.o
	$(OBJCOPY) -S -O binary initcode.out initcode

$(K)/kernel: $(OBJS) $(K)/entry.o entryother initcode $(K)/kernel.ld
	$(LD) $(LDFLAGS) -T $(K)/kernel.ld -o $(K)/kernel $(K)/entry.o $(OBJS) -b binary initcode entryother

# kernelmemfs is a copy of kernel that maintains the
# disk image in memory instead of writing to a disk.
# This is not so useful for testing persistent storage or
# exploring disk buffering implementations, but it is
# great for testing the kernel on real hardware without
# needing a scratch disk.
MEMFSOBJS = $(filter-out $(K)/ide.o,$(OBJS)) $(K)/memide.o
$(K)/kernelmemfs: $(MEMFSOBJS) $(K)/entry.o entryother initcode $(K)/kernel.ld $(K)/fs.img
	mv $(K)/fs.img fs.img
	$(LD) $(LDFLAGS) -T $(K)/kernel.ld -o $(K)/kernelmemfs $(K)/entry.o $(MEMFSOBJS) -b binary initcode entryother fs.img
# memide.c needs fs.img to be in the main folder

tags: $(OBJS) $(K)/entryother.S $(U)/_init
	etags *.S *.c

$(K)/vectors.S: $(K)/vectors.pl
	./$(K)/vectors.pl > $(K)/vectors.S

ULIB = $(L)/ulib.o $(L)/usys.o $(L)/printf.o $(L)/umalloc.o

$(U)/_%: $(U)/%.o $(ULIB)
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $@ $^

$(U)/_forktest:  $(U)/forktest.o $(ULIB)
	# forktest has less library code linked in - needs to be small
	# in order to be able to max out the proc table.
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $(U)/_forktest $(U)/forktest.o $(L)/ulib.o $(L)/usys.o

$(MKFS)/mkfs: $(MKFS)/mkfs.c $(L)/fs.h
	gcc -Werror -Wall -O1 -o $(MKFS)/mkfs $(MKFS)/mkfs.c

# Prevent deletion of intermediate files, e.g. cat.o, after first build, so
# that disk image changes after first build are persistent until clean.  More
# details:
# http://www.gnu.org/software/make/manual/html_node/Chained-Rules.html
.PRECIOUS: %.o

UPROGS=\
	$(U)/_cat\
	$(U)/_cpubench\
	$(U)/_echo\
	$(U)/_forktest\
	$(U)/_grep\
	$(U)/_init\
	$(U)/_iobench\
	$(U)/_kill\
	$(U)/_ln\
	$(U)/_ls\
	$(U)/_mkdir\
	$(U)/_rm\
	$(U)/_sh\
	$(U)/_stressfs\
	$(U)/_usertests\
	$(U)/_wc\
	$(U)/_zombie\

$(K)/fs.img: $(MKFS)/mkfs $(UPROGS)
	./$(MKFS)/mkfs ./$(K)/fs.img $(UPROGS)

-include *.d

clean: uklclean mkfsclean

uklclean: ukclean lclean

ukclean: uclean kclean

uclean:
	rm -f $(UPROGS) $(U)/*.o $(U)/*.d

kclean:
	rm -f $(K)/*.o $(K)/*.d $(K)/*.img \
	$(K)/initcode $(K)/bootblock $(K)/kernel $(K)/vectors.S \
	entryother initcode initcode.out \
	$(K)/kernelmemfs fs.img

lclean:
	rm -f $(L)/*.o $(L)/*.d

mkfsclean:
	rm -f $(MKFS)/mkfs

# run in emulators

bochs : $(K)/fs.img $(K)/xv6.img
	if [ ! -e .bochsrc ]; then ln -s dot-bochsrc .bochsrc; fi
	bochs -q

# try to generate a unique GDB port
GDBPORT = $(shell expr `id -u` % 5000 + 25000)
# QEMU's gdb stub command line changed in 0.11
QEMUGDB = $(shell if $(QEMU) -help | grep -q '^-gdb'; \
	then echo "-gdb tcp::$(GDBPORT)"; \
	else echo "-s -p $(GDBPORT)"; fi)
ifndef CPUS
CPUS := 2
endif
QEMUOPTS = -drive file=$(K)/fs.img,index=1,media=disk,format=raw \
	-drive file=$(K)/xv6.img,index=0,media=disk,format=raw -smp $(CPUS) -m 512 $(QEMUEXTRA)

qemu: $(K)/fs.img $(K)/xv6.img
	$(QEMU) -serial mon:stdio $(QEMUOPTS)

qemu-memfs: $(K)/xv6memfs.img
	$(QEMU) -drive file=$(K)/xv6memfs.img,index=0,media=disk,format=raw -smp $(CPUS) -m 256

qemu-nox: $(K)/fs.img $(K)/xv6.img
	$(QEMU) -nographic $(QEMUOPTS)

.gdbinit: .gdbinit.tmpl
	sed "s/localhost:1234/localhost:$(GDBPORT)/" < $^ > $@

qemu-gdb: $(K)/fs.img $(K)/xv6.img .gdbinit
	@echo "*** Now run 'gdb'." 1>&2
	$(QEMU) -serial mon:stdio $(QEMUOPTS) -S $(QEMUGDB)

qemu-nox-gdb: $(K)/fs.img $(K)/xv6.img .gdbinit
	@echo "*** Now run 'gdb'." 1>&2
	$(QEMU) -nographic $(QEMUOPTS) -S $(QEMUGDB)

