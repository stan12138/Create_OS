
mov ax, 0x1140
mov ds, ax

;下面显示一些提示信息
mov	ax,	0600h
mov	bx,	0700h
mov	cx,	0
mov	dx,	0184fh
int 10h

mov ax, 0200h
mov dx, 0000h
mov bx, 0000h
int 10h

mov ax, 1301h
mov dx, 0000h
mov cx, [len]
mov bx, 1140h
mov es, bx
mov bp, mess
mov bx, 0002h
int 10h

xor ah, ah
xor dl, dl
int 13h


;下面开始进入保护模式，并开启big real mode
in	al,	92h
or	al,	00000010b
out	92h,	al

cli

db	0x66
lgdt	[gdtptr]

mov	eax,	cr0
or	eax,	1
mov	cr0,	eax

mov	ax,	data_gdt_selector
mov	fs,	ax
mov	eax,	cr0
and	al,	11111110b
mov	cr0,	eax

sti




search_file_in_dir:
	mov word [dir_num], 14     ;根目录有14个扇区
	mov word [dir_order], 19   ;根目录扇区序号从19开始


load_one_dir_sector:
	cmp word [dir_num],  0
	jz find_file_fail        ;剩余扇区数等于0，说明搜索结束
	dec word [dir_num]         ;剩余扇区数--
	mov ax, [dir_order]        ;将要搜索的扇区序号存入ax
	mov cl, 1                  ;将要载入的扇区数存入cl，感觉还应该加入一个存储地址功能
	mov si, 1000h              ;si存储扇区应该读入到内存的段地址，偏移地址是0
	inc word [dir_order]       ;扇区序号++
	call func_read_disk           ;跳转，读入扇区


call search_dir_sector         ;扇区读入结束，开始搜寻扇区

mov edi, 0x100000

call handle_fat_load_file

call load_kernel_success

jmp kill_motor


func_read_disk:          
	mov bl, 18      ;每个柱面18个扇区
	div bl          ;ax/bl
	mov dh, al      ;以下其实就是套公式
	and dh, 1
	shr al, 1
	mov ch, al
	inc ah
	mov al, cl
	mov cl, ah
begin_read:
	mov ah, 02h
	mov bx, si   ;设置数据存储区为0x10000-->es:bx
	mov es, bx
	mov bx, 0
	mov dl, 0    ;千万注意，不能少了这一行，我被坑了一天
	int 13h
	jc begin_read
	ret



search_dir_sector:
	mov word [entry_num], 16           ;每个根目录扇区包含16个目录项
	mov word [entry_order], 0          ;第一个目录项的偏移为0

search_entry:
	cmp word [entry_num], 0            ;比较还剩余几个目录项未搜索
	jz load_one_dir_sector                    ;本扇区搜索结束，搜索下一个扇区
	dec word [entry_num]               ;剩余目录项--
	mov bx, [entry_order]              ;将目录项偏移存入bx
	add word [entry_order], 32         ;每个目录项32字节，生成下一个目录项的偏移
	mov si, file_name                ;将要搜寻的文件名字存储的地址放进si

	mov word [name_len], 11            ;每个目录项的文件名字和后缀共11字节

cmp_name:
	cmp word [name_len], 0             ;检查还剩几个字节未比对
	jz find_file_success                         ;全部11个字节比对结束，搜寻成功，当前目录项就是目标
	dec word [name_len]                ;剩余字节数减一
	lodsb                              ;将一个名字的字节载入al寄存器
	cmp al, byte [es:bx]               ;比对al寄存器的内容与es:bx指向的内存的内容
	jz one_character_succ              ;比对成功，跳转
	jmp search_entry                   ;比对失败，搜索下一个目录项

one_character_succ:
	inc bx                             ;比对成功，偏移加一，比对下一个字节
	jmp cmp_name                       ;跳转进入比对流程

find_file_success:
	add bx, 15                 ;搜寻成功，bx加15得到首簇序号的偏移
	mov di, [es:bx]            ;把首簇的序号存入di寄存器
	mov [first_sector_number], di     ;首簇号要存在内存中
	ret

find_file_fail:
	mov ax, 1301h
	mov cx, [f_len]
	mov dx, 0200h
	mov bx, 0x1140
	mov es, bx
	mov bp, fail_mess
	mov bx, 0004h
	int 10h

	jmp $

handle_fat_load_file:
	mov ax, 1                  ;开始处理fat表，fat表开始于序号为1的扇区
	mov cl, 9                  ;一次性读入全部9个fat扇区
	mov si, 1000h              ;读入到10000h处
	call func_read_disk           ;开始读入fat扇区
	;读完之后，数据依旧存在0x1000:0x0000内存单元中，因此es寄存器要保护，bx寄存器也许是可以使用的，但是最好别乱搞
	;另外，di寄存器存储了首簇序号

	mov ax, [first_sector_number]                ;首簇序号存于ax寄存器中，但是ax寄存器在func_read_disk之后会被修改，所以必须备份，si也要用，只能备份在di中

	jmp get_loader_sector

get_loader_sector:
	cmp ax, 0fffh
	jz file_load_done

	mov cl, 1       ;读取一个扇区
	add ax, 31      ;数据区的簇序号从2开始，2号簇对应的是序号是33的扇区
	mov si, 0x7c0
	call func_read_disk

	call move_sector_to_des

	mov ax, [first_sector_number]    ;将首簇序号恢复到ax寄存器

	mov cl, 2
	div cl
	
	cmp ah, 0
	jz even_num
	jmp odd_num

even_num:
	mov word [odd_flage], 0

	jmp get_next_num
odd_num:
	mov word [odd_flage], 1

	jmp get_next_num


get_next_num:
	mov cl, 3
	mul cl   ;al寄存器存储除2之后的商，al寄存器刚好也是字节乘法的默认寄存器
	;乘法的结果在ax寄存器，代表着要取得的fat表项的偏移
	mov bx, 1000h
	mov es, bx       ;读软盘之后，会修改es寄存器，需要恢复原样
	mov bx, ax
	mov al, [es:bx]  ;一共要取出3个字节，先取出一个字节。这里必须要注意大小端存储的问题，如果是取出两个字节的话
	mov ah, 0        ;要让ax寄存器只存储第一个字节的内容
	inc bx
	mov cl, [es:bx]  ;取出第二个字节
	and cl, 0fh
	mov ch, 0
	shl cx, 8        ;第二个字节的高四位左移8位加上第一个字节构成第一个表项
	add ax, cx       ;得到第一个表项，存储在ax寄存器当中

	mov cl, [es:bx]  ;再次取出第二个字节
	mov ch, 0
	shr cx, 4

	inc bx
	mov dl, [es:bx]  ;取出第三个字节
	mov dh, 0
	shl dx, 4
	add cx, dx       ;取得第二个表项，存储于cx寄存器

	;上述代码已经过debug，确认无误

	cmp word [odd_flage], 0
	jz get_even_fat
	jmp get_odd_fat

get_even_fat:
	mov ax, ax
	mov [first_sector_number], ax
	jmp get_loader_sector

get_odd_fat:
	mov ax, cx
	mov [first_sector_number], ax
	jmp get_loader_sector




file_load_done:
	ret


move_sector_to_des:
	mov cx, 0x7c0
	mov gs, cx
	mov cx, 200h
	mov bx, 0

move_loop:
	mov al, byte [gs:bx]
	mov byte [fs:edi], al

	inc bx
	inc edi

	loop move_loop

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
