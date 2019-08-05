OUTPUT_DIR = ../output/
TMP_DIR = ../tmp/

all: $(TMP_DIR)system 
	objcopy -I pe-x86-64 -S -R ".eh_frame" -R ".comment" -O binary $(TMP_DIR)system $(OUTPUT_DIR)kernel.bin

$(TMP_DIR)system:	$(TMP_DIR)head.o $(TMP_DIR)main.o $(TMP_DIR)show.o
	ld -b pe-x86-64 -o $(TMP_DIR)system $(TMP_DIR)head.o $(TMP_DIR)main.o $(TMP_DIR)show.o -T Kernel.lds

$(TMP_DIR)head.o:	head.S
	gcc -E  head.S > $(TMP_DIR)head.s1
	as --64 -o $(TMP_DIR)head.o $(TMP_DIR)head.s1
	
$(TMP_DIR)main.o:	main.c
	gcc  -mcmodel=large -fno-builtin -m64 -c main.c -o $(TMP_DIR)main.o
	objcopy --remove-section .pdata $(TMP_DIR)main.o


$(TMP_DIR)show.o: show.c
	gcc -mcmodel=large -fno-builtin -m64 -c show.c -o $(TMP_DIR)show.o
	objcopy --remove-section .pdata $(TMP_DIR)show.o