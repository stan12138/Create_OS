mov ax, 0x1140
mov ds, ax

push 0000h
push 0f0fh
push 5000h
call clean_screen

push 0000h
push word [len]
push mess
push 0200h
call print

xor ah, ah
xor dl, dl
int 13h
; 重置磁盘驱动器


;开启big real mode
in	al,	92h
or	al,	00000010b
out	92h,	al
; 使用A20快速门开启A20地址线

cli    ;暂时关闭中断

lgdt	[gdtptr]
; 加载GDTR的值进入gdtr

mov	eax,	cr0
or	eax,	1
mov	cr0,	eax
; 设置CR0，开启保护模式

mov	ax,	data_gdt_selector
mov	fs,	ax
; 加载数据段选择子进入fs段寄存器

mov	eax,	cr0
and	al,	11111110b
mov	cr0,	eax
; 关闭CR0  big real mode开启成功
sti


mov edi, 0x100000
push edi
push 1000h
push file_name
push 0x7c0
call load_file_fat12
call load_kernel_success
jmp kill_motor


clean_screen:
; 函数原型：void clean_screen(word 左上(bp+8), word 右下(bp+6), word 颜色(bp+4))
	push bp
	mov bp, sp
	pusha


	mov ax, 0600h

	mov bx, [ss:bp+4]   ;第三个参数
	mov dx, [ss:bp+6]   ;第二个参数
	mov cx, [ss:bp+8]   ;第一个参数

	int 10h

	mov ax, [ss:bp+2]   ;获取返回地址的位置 
	mov [ss:bp+8], ax   ;将返回地址放入第一个参数所在的地方

	popa
	pop bp
	add sp, 6        ;弹出参数

	ret

print: 
; 函数原型: void print(word 光标位置(bp+10), word 字符串长度(bp+8), word 字符串地址(bp+6), word 文字颜色(bp+4))
	push bp
	mov bp, sp
	pusha

	mov ax, 1301h   ;输出
	mov dx, [ss:bp+10]
	mov cx, [ss:bp+8]

	push es        ;如果在函数内部修改了段寄存器，必须要注意保存和恢复，popa，pusha与段寄存器无关

	mov bx, ds
	mov es, bx
	mov bx, [ss:bp+4]
	mov bh, 00h
	push bp
	mov bp, [ss:bp+6]
	int 10h
	pop bp

	pop es

	mov ax, [ss:bp+2]   ;获取返回地址的位置 
	mov [ss:bp+10], ax  ;将返回地址放入第一个参数所在的地方
	popa
	pop bp
	add sp, 8        ;弹出参数

	ret

load_sector:
; 函数原型：void load_sector(word sector_index(bp+8), word sector_num(bp+6), word address(bp+4))
	push bp
	mov bp, sp
	pusha

	mov ax, [ss:bp+8]
	mov cx, [ss:bp+6]
	mov si, [ss:bp+4]
	mov bl, 18
	div bl
	mov dh, al
	and dh, 1
	shr al, 1
	
	mov ch, al
	inc ah
	mov al, cl
	mov cl, ah
	
	push es

	read:
	mov ah, 02h
	mov bx, si
	mov es, bx
	mov bx, 0
	mov dl, 0
	int 13h
	jc read

	pop es

	mov ax, [ss:bp+2]   ;获取返回地址的位置 
	mov [ss:bp+8], ax  ;将返回地址放入第一个参数所在的地方
	popa
	pop bp
	add sp, 6        ;弹出参数

	ret




move_sector:
	; loader特别定制,  void move_sector(dword edi[bp+6], word gs[bp+4])
	push bp
	mov bp, sp
	pusha

	push gs

	mov cx, [ss:bp+4]
	mov gs, cx
	mov cx, 200h
	mov bx, 0

	mov edi, [ss:bp+6]

	move_loop:
		mov al, byte [gs:bx]
		mov byte [fs:edi], al

		inc bx
		inc edi

		loop move_loop

		pop gs

		mov ax, [bp+2]   ;获取返回地址的位置 
		mov [bp+8], ax   ;将返回地址放入第一个参数所在的地方
		popa
		pop bp
		add sp, 6        ;弹出参数

		ret



load_file_fat12:
; loader特别定制
; 函数原型：void load_file_fat12(dword edi(bp+10), word tmp_address(bp+8), word filename(bp+6), word address(bp+4)) 
; tmp_address用来暂存目录项和FAT表，最长会占用9*520字节，filename是要寻找的名字的地址，address是最后要存储的文件地址
	push bp
	mov bp, sp
	pusha

	push es  ;在后面使用了es寄存器，那么就要先保存

	;我决定将此处的三个循环变量改造为局部变量，使用堆栈存储
	push word 19   ;目录扇区序号   sp+4-------di+4
	push word 0    ;扇区内目录项偏移    sp+2------di+2
	push word 0    ;目录项内文件名字字母序号   sp----di

	mov di, sp

	search_dir:
		cmp word [ss:di+4], 33    ;如果所有目录扇区已搜索完成，失败
		jz find_fail           ;jz是当前述二者相等时会执行
		
		push word [ss:di+4] ;当前依旧是有效目录扇区，那么开始准备读入扇区
		push word 0001h  ;扇区序号是[sp+4]，读入1个扇区
		push word [ss:bp+8]  ;读入到0x1000:0000 即0x10000
		call load_sector

		inc word [ss:di+4]  ;下一个扇区序号是加一

		mov word [ss:di+2], 0  ;准备开始在已经加载的扇区内搜索各个目录项
	search_one_sector:
		cmp word [ss:di+2], 520 ;目录项搜索完毕就失败，检查下一个扇区
		jz search_dir        

		mov si, [ss:bp+8]
		mov es, si     ;将es寄存器设置为目录扇区在内存中的段地址
		mov bx, [ss:di+2]  ;将当前目录项的起始偏移载入bx

		add word [ss:di+2], 32  ;生成下一个目录项的偏移

		mov word [ss:di], 0    ;生成要搜索的字母的偏移0

		mov si, [ss:bp+6]  ;将目标文件名载入si

	search_one_entry:
		cmp word [ss:di], 11   ;比较当前搜索的字母的序号，如果等于11代表检查成功
		jz find_file

		inc word [ss:di]   ;字母序号加一
		lodsb      ;从ds:si加载一个字节进入al，自增si
		cmp al, byte [es:bx]   ;比较目标字母和当前字母是否一致
		jz one_character_success  ;如果一致自增bx之后，开始比较下一个字母
		jmp search_one_sector  ;不一致搜索下一个目录项

	one_character_success: 
		inc bx
		jmp search_one_entry
	find_file:
		add sp, 6 ;弹出3个局部变量

		; pop es

		add bx, 15 ;检查文件名成功之后，bx加15就是这个目录项中存储首簇序号的位置
		mov ax, [es:bx]  ;将首簇序号加载进入ax寄存器

		pop es

		jmp load_fat

	find_fail:
		add sp, 6 ;弹出3个局部变量

		pop es

		jmp $


	load_fat:
		push word 1
		push word 9
		push word [ss:bp+8]
		call load_sector  ;加载所有FAT表

		push es

		
		mov si, [ss:bp+4]  ;保存loader加载到的地址

		mov bx, [ss:bp+8]  ;在es内存入1000h，用来和bx配合获取FAT项
		mov es, bx

	parse_fat:
		push ax   ;保存首簇序号到堆栈

		cmp ax, 0fffh
		jz file_load_done

		add ax, 31
		push ax
		push 1
		push si
		call load_sector ;读取一个loader扇区

		mov edi, [ss:bp+10]
		push edi
		push si
		call move_sector

		add edi, 200h
		mov [ss:bp+10], edi

		pop ax    ;恢复首簇地址，并重新压入
		push ax

		mov cl, 2
		div cl

		mov cl, 3
		mul cl	

		mov bx, ax
		mov al, [es:bx]
		mov ah, 0

		inc bx
		mov ch, [es:bx]
		and ch, 0fh
		mov cl, 0
		add ax, cx

		mov cl, [es:bx]
		mov ch, 0
		shr cx, 4

		inc bx
		mov dl, [es:bx]
		mov dh, 0
		shl dx, 4
		add cx, dx

		mov bx, ax

		pop ax
		; push ax   此处不需要再次push ax
		mov dl, 2
		div dl
		cmp ah, 0
		jz get_even_fat
		jmp get_odd_fat

	get_even_fat:
		mov ax, bx
		jmp parse_fat

	get_odd_fat:
		mov ax, cx
		jmp parse_fat


	file_load_done:
		pop ax   ;弹出首簇序号

		pop es

		mov ax, [ss:bp+2]   ;获取返回地址的位置 
		mov [ss:bp+12], ax  ;将返回地址放入第一个参数所在的地方
		popa
		pop bp
		add sp, 10        ;弹出参数

		ret


load_kernel_success:
	mov ax, 1301h
	mov dx, 0200h
	mov cx, [len_mess2]
	mov bx, 1140h
	mov es, bx
	mov bp, mess2
	mov bx, 0002h
	int 10h	

	mov ax, 0b800h
	mov gs, ax
	mov ah, 0fh
	mov al, 'S'
	mov [gs:((80+39)*2)], ax

	ret


kill_motor:
	mov dx, 03f2h
	mov al, 0
	out dx, al

show_some_message1:
	mov ax, 1301h
	mov dx, 0300h
	mov cx, [memory_mess_len]
	mov bx, 1140h
	mov es, bx
	mov bp, memory_mess
	mov bx, 0002h
	int 10h

mov ebx, 0
mov ax, 0
mov es, ax
mov di, 0x7e00

get_memory_info:
	mov eax, 0xe820
	mov ecx, 20
	mov edx, 0x534d4150
	int 15h
	jc get_memory_info_fail
	add di, 20

	cmp ebx, 0
	jne get_memory_info
	jmp get_memory_info_done



get_memory_info_fail:

	mov ax, 0x1140
	mov ds, ax


	mov ax, 1301h
	mov dx, 0400h
	mov cx, [memory_fail_mess_len]
	mov bx, 1140h
	mov es, bx
	mov bp, memory_fail_mess
	mov bx, 0004h
	int 10h

	jmp $

get_memory_info_done:

	mov ax, 0x1140
	mov ds, ax

	mov ax, 1301h
	mov dx, 0400h
	mov cx, [memory_ok_mess_len]
	mov bx, 1140h
	mov es, bx
	mov bp, memory_ok_mess
	mov bx, 0002h
	int 10h


get_vbe_controler_info:
	mov ax, 0
	mov es, ax
	mov di, 8000h
	mov ax, 4f00h
	int 10h

	cmp ax, 004fh
	jz get_vbe_controler_info_success

get_vbe_controler_info_fail:
	mov ax, 0x1140
	mov ds, ax


	mov ax, 1301h
	mov dx, 0500h
	mov cx, [vbe_control_fail_len]
	mov bx, 1140h
	mov es, bx
	mov bp, vbe_control_fail
	mov bx, 0004h
	int 10h

	jmp $	

get_vbe_controler_info_success:
	mov ax, 0x1140
	mov ds, ax


	mov ax, 1301h
	mov dx, 0500h
	mov cx, [vbe_control_ok_len]
	mov bx, 1140h
	mov es, bx
	mov bp, vbe_control_ok
	mov bx, 0002h
	int 10h


set_vbe_mode:
	mov ax, 4f02h
	mov bx, 0x4143
	int 10h

	cmp ax, 004fh
	jnz set_vbe_mode_fail

	jmp back_to_protect_mode


set_vbe_mode_fail:
	mov ax, 0x1140
	mov ds, ax


	mov ax, 1301h
	mov dx, 0600h
	mov cx, [vbe_mode_fail_len]
	mov bx, 1140h
	mov es, bx
	mov bp, vbe_mode_fail
	mov bx, 0004h
	int 10h

	jmp $	


back_to_protect_mode:
	cli
	mov ax, 0x1140
	mov ds, ax

	db	0x66
	lgdt [gdtptr]

	mov eax, cr0
	or eax, 1
	mov cr0, eax

	jmp dword code_gdt_selector:get_in_protect+0x11400
	;事实证明这个语法是可以使用的

section s32
bits 32

get_in_protect:

	mov ax, data_gdt_selector
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov ss, ax
	mov esp, 7e00h

	mov	dword	[0x90000],	0x91007
	mov	dword	[0x90800],	0x91007		

	mov	dword	[0x91000],	0x92007

	mov	dword	[0x92000],	0x000083

	mov	dword	[0x92008],	0x200083

	mov	dword	[0x92010],	0x400083

	mov	dword	[0x92018],	0x600083

	mov	dword	[0x92020],	0x800083

	mov	dword	[0x92028],	0xa00083

	mov eax, gdtptr64


	lgdt	[gdtptr64+0x11400]
	mov	ax,	0x10
	mov	ds,	ax
	mov	es,	ax
	mov	fs,	ax
	mov	gs,	ax
	mov	ss,	ax

	mov	esp,	7E00h

;=======	open PAE

	mov	eax,	cr4
	bts	eax,	5
	mov	cr4,	eax

;=======	load	cr3

	mov	eax,	0x90000
	mov	cr3,	eax

;=======	enable long-mode

	mov	ecx,	0C0000080h		;IA32_EFER
	rdmsr

	bts	eax,	8
	wrmsr

;=======	open PE and paging

	mov	eax,	cr0
	bts	eax,	0
	bts	eax,	31
	mov	cr0,	eax

	jmp	code_gdt_selector64:0x100000


section mess_data

mess: db "hello, welcome to loader!"
len: dw $-mess
mess2: db "kernel load done...."
len_mess2: dw $-mess2
fail_mess: db "can not find kernel"
f_len: dw $-fail_mess


memory_mess: db "motor already kill, now begin get memory info...."
memory_mess_len: dw $-memory_mess

memory_fail_mess: db "get memory info fail, will dead in here...."
memory_fail_mess_len: dw $-memory_fail_mess

memory_ok_mess: db "get memory info ok...."
memory_ok_mess_len: dw $-memory_ok_mess

vbe_control_fail: db "get vbe controler info fail, will dead in here..."
vbe_control_fail_len: dw $-vbe_control_fail

vbe_control_ok: db "get vbe controler info success, will go to get vbe mode info..."
vbe_control_ok_len: dw $-vbe_control_ok

vbe_mode_fail: db "set vbe mode fail, going to dead here..."
vbe_mode_fail_len: dw $-vbe_mode_fail


file_name: db "KERNEL  BIN", 0

first_sector_number: dw 0

dir_order: dw 19
dir_num: dw 14

entry_num: dw 16
entry_order: dw 0


odd_flage: dw 0

name_len: dw 11


section gdt32

first_gdt:		dd	0,0
code_gdt:	dd	0x0000FFFF,0x00CF9A00
data_gdt:	dd	0x0000FFFF,0x00CF9200

gdtlen	equ	$ - first_gdt
gdtptr	dw	gdtlen - 1
	dd	first_gdt+0x11400

code_gdt_selector	equ	code_gdt - first_gdt
data_gdt_selector	equ	data_gdt - first_gdt


section gdt64

first_gdt64: dq	0x0000000000000000
code_gdt64:	 dq	0xff2098ffffff0000
data_gdt64:	 dq	0xff0092ffffff0000

gdtlen64	equ	$ - first_gdt64
gdtptr64	dw	gdtlen64 - 1
		dd	first_gdt64+0x11400

code_gdt_selector64	equ	code_gdt64 - first_gdt64
data_gdt_selector64	equ	data_gdt64 - first_gdt64
