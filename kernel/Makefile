all: system
	objcopy -I pe-x86-64 -S -R ".eh_frame" -R ".comment" -O binary system ../kernel.bin

system:	head.o main.o show.o
	ld -b pe-x86-64 -o system head.o main.o show.o -T Kernel.lds

head.o:	head.S
	gcc -E  head.S > head.s1
	as --64 -o head.o head.s1
	
main.o:	main.c
	gcc  -mcmodel=large -fno-builtin -m64 -c main.c
	objcopy --remove-section .pdata main.o


show.o: show.c
	gcc -mcmodel=large -fno-builtin -m64 -c show.c
	objcopy --remove-section .pdata show.o