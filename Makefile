# Available arch options = x86_64
ARCH := x86_64
# Available optimization levelss = Debug, ReleaseSafe, ReleaseFast, ReleaseSmall
OPTIMIZATION_LEVEL := Debug

# Zig compiler flags.
ZIG_FLAGS := -Darch=$(ARCH) -Doptimize=$(OPTIMIZATION_LEVEL)

# Bootloader paths
LIMINE_PATH := boot/limine

# ISO paths
ISO := ZagOS.iso
ISO_DIR := iso
ISO_XORRISO_FLAGS := \
	-as mkisofs \
	-R \
	-r \
	-J \
	-b $(LIMINE_PATH)/limine-bios-cd.bin \
	-no-emul-boot \
	-boot-load-size 4 \
	-boot-info-table \
	-hfsplus \
	-apm-block-size 2048 \
	--efi-boot $(LIMINE_PATH)/limine-uefi-cd.bin \
	-efi-boot-part \
	--efi-boot-image \
	--protective-msdos-label
ISO_TEST := ZagOS_Test.iso

# Kernel paths
KERNEL := kernel/zig-out/bin/kernel
KERNEL_TEST := kernel/zig-out/bin/kernel_test

# Qemu emulator
QEMU := qemu-system-$(ARCH)
QEMU_FLAGS := -m 128M -serial file:serial.log -daemonize
QEMU_RUN_FLAGS := -cdrom $(ISO)
QEMU_DEBUG_FLAGS := $(QEMU_RUN_FLAGS) -s
QEMU_TEST_FLAGS := -cdrom $(ISO_TEST)

# Default target. This must come first!
.PHONY: all
all: $(ISO)

iso-setup:
	# Delete any existing temporary ISO directory.
	rm -rf $(ISO_DIR)

	# Create the EFI boot tree and copy Limine's EFI executables over.
	mkdir -p $(ISO_DIR)/EFI/BOOT
	cp -v $(LIMINE_PATH)/BOOTX64.EFI $(ISO_DIR)/EFI/BOOT/
	cp -v $(LIMINE_PATH)/BOOTIA32.EFI $(ISO_DIR)/EFI/BOOT/

	# Create the limine directories and copy the Limine bootloader binaries.
	mkdir -p $(ISO_DIR)/$(LIMINE_PATH)
	cp -v $(LIMINE_PATH)/limine-bios.sys    \
	      $(LIMINE_PATH)/limine-bios-cd.bin \
	      $(LIMINE_PATH)/limine-uefi-cd.bin \
	      $(ISO_DIR)/$(LIMINE_PATH)/

	# Copy the Limine bootloader configuration file.
	cp -v boot/limine.conf $(ISO_DIR)/boot/limine.conf  

# Creates a bootable ISO image.
$(ISO): $(LIMINE_PATH) iso-setup kernel
	# Copy the kernel binary.
	cp -v $(KERNEL) $(ISO_DIR)

	# Create the bootable ISO.
	xorriso $(ISO_XORRISO_FLAGS) $(ISO_DIR) -o $(ISO)

	# Install Limine stage 1 and 2 for legacy BIOS boot.
	./$(LIMINE_PATH)/limine bios-install $(ISO)

# Creates a bootable ISO image for testing the kernel with
$(ISO_TEST): $(LIMINE_PATH) iso-setup kernel
	# Copy the test kernel binary.
	cp -v $(KERNEL_TEST) $(ISO_DIR)/kernel

	# Create the bootable ISO.
	xorriso $(ISO_XORRISO_FLAGS) $(ISO_DIR) -o $(ISO_TEST)

	# Install Limine stage 1 and 2 for legacy BIOS boot.
	./$(LIMINE_PATH)/limine bios-install $(ISO_TEST)

# Cleans up everything (build artifacts and log files)
.PHONY: clean
clean:
	rm -rf $(LIMINE_PATH) 
	rm -rf kernel/.zig-cache 
	rm -rf kernel/zig-out
	rm -rf $(ISO_DIR) 
	rm $(ISO)
	rm $(ISO_TEST)
	rm serial.log

# Build the kernel binary.
.PHONY: kernel
kernel:
	cd kernel && zig build $(ZIG_FLAGS)

# Download and build the Limine bootloader.
$(LIMINE_PATH):
	# Download the latest Limine binary release for the 9.x branch.
	git clone https://github.com/limine-bootloader/limine.git \
		--branch=v9.x-binary                                  \
		--depth=1                                             \
		$(LIMINE_PATH)

	# Build "limine" utility.
	$(MAKE) -C $(LIMINE_PATH)

# Run the generated ISO image in QEMU.
.PHONY: run
run: $(ISO)
	$(QEMU) $(QEMU_FLAGS) $(QEMU_RUN_FLAGS)

# Run the generated ISO image in QEMU with connectivity enabled
.PHONY: run-debug
run-debug: $(ISO)
	$(QEMU) $(QEMU_FLAGS) $(QEMU_DEBUG_FLAGS)

# Run the generated Test ISO image in QEMU
.PHONY: run-test
run-test: $(ISO_TEST)
	$(QEMU) $(QEMU_FLAGS) $(QEMU_TEST_FLAGS)
