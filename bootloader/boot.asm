org 0x7c00

jmp start
nop
BS_OEMName	db	'StanBoot'
BPB_BytesPerSec	dw	512
BPB_SecPerClus	db	1
BPB_RsvdSecCnt	dw	1
BPB_NumFATs	db	2
BPB_RootEntCnt	dw	224
BPB_TotSec16	dw	2880
BPB_Media	db	0xf0
BPB_FATSz16	dw	9
BPB_SecPerTrk	dw	18
BPB_NumHeads	dw	2
BPB_HiddSec	dd	0
BPB_TotSec32	dd	0
BS_DrvNum	db	0
BS_Reserved1	db	0
BS_BootSig	db	0x29
BS_VolID	dd	0
BS_VolLab	db	'boot loader'
BS_FileSysType	db	'FAT12   '

start :
	mov ax, 0600h
	mov	bx,	2000h
	mov	cx,	0500h
	mov	dx,	0a0ah
	int 10h

	mov ax, 0200h
	mov dx, 0000h
	mov bx, 0000h
	int 10h

	mov ax, 1301h
	mov dx, 0000h
	mov cx, [len]
	mov bx, 0000h
	mov es, bx
	mov bp, mess
	mov bx, 0082h
	int 10h

	xor ah, ah
	xor dl, dl
	int 13h


search_loader:
	mov word [dir_num], 14     ;根目录有14个扇区
	mov word [dir_order], 19   ;根目录扇区序号从19开始
begin_search:
	cmp word [dir_num],  0
	jz find_loader_fail        ;剩余扇区数等于0，说明搜索结束
	dec word [dir_num]         ;剩余扇区数--
	mov ax, [dir_order]        ;将要搜索的扇区序号存入ax
	mov cl, 1                  ;将要载入的扇区数存入cl，感觉还应该加入一个存储地址功能
	mov si, 1000h              ;si存储扇区应该读入到内存的段地址，偏移地址是0
	inc word [dir_order]       ;扇区序号++
	call read_sector           ;跳转，读入扇区

	call search_sector         ;扇区读入结束，开始搜寻扇区


;read_sector和begin_read是读入扇区的函数，可以接受三个参数，ax扇区序号，cl扇区数目，si指定扇区存储位置的段地址
;偏移地址都从0开始

read_sector:          
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
	int 13h
	jc begin_read
	ret

search_sector:
	mov word [entry_num], 16           ;每个根目录扇区包含16个目录项
	mov word [entry_order], 0          ;第一个目录项的偏移为0

search_entry:
	cmp word [entry_num], 0            ;比较还剩余几个目录项未搜索
	jz begin_search                    ;本扇区搜索结束，搜索下一个扇区
	dec word [entry_num]               ;剩余目录项--
	mov bx, [entry_order]              ;将目录项偏移存入bx
	add word [entry_order], 32         ;每个目录项32字节，生成下一个目录项的偏移
	mov si, loader_name                ;将要搜寻的文件名字存储的地址放进si

	mov word [name_len], 11            ;每个目录项的文件名字和后缀共11字节

cmp_name:
	cmp word [name_len], 0             ;检查还剩几个字节未比对
	jz success                         ;全部11个字节比对结束，搜寻成功，当前目录项就是目标
	dec word [name_len]                ;剩余字节数减一
	lodsb                              ;将一个名字的字节载入al寄存器
	cmp al, byte [es:bx]               ;比对al寄存器的内容与es:bx指向的内存的内容
	jz one_character_succ              ;比对成功，跳转
	jmp search_entry                   ;比对失败，搜索下一个目录项

one_character_succ:
	inc bx                             ;比对成功，偏移加一，比对下一个字节
	jmp cmp_name                       ;跳转进入比对流程

find_loader_fail:
	mov ax, 1301h
	mov cx, [f_len]
	mov dx, 0200h
	mov bx, 0
	mov es, bx
	mov bp, fail_mess
	mov bx, 0084h
	int 10h

	jmp $

success:
	add bx, 15                 ;搜寻成功，bx加15得到首簇序号的偏移
	mov di, [es:bx]            ;把首簇的序号存入si寄存器

begin_handle_fat:
	mov ax, 1                  ;开始处理fat表，fat表开始于序号为1的扇区
	mov cl, 9                  ;一次性读入全部9个fat扇区
	mov si, 1000h              ;读入到10000h处
	call read_sector           ;开始读入fat扇区
	;读完之后，数据依旧存在0x1000:0x0000内存单元中，因此es寄存器要保护，bx寄存器也许是可以使用的，但是最好别乱搞
	;另外，si寄存器存储了首簇序号

parse_fat:
	mov word [double_fat_num], 1536
	mov word [fat_sec_order], 0
	mov ax, di                ;首簇序号存于ax寄存器中，但是ax寄存器在read_sector之后会被修改，所以必须备份，si也要用，只能备份在di中
	mov si, 1140h

	jmp get_loader_sector

get_loader_sector:
	cmp ax, 0fffh
	jz loader_read_done

	mov cl, 1       ;读取一个扇区
	add ax, 31      ;数据区的簇序号从2开始，2号簇对应的是序号是33的扇区
	call read_sector
	add si, 20h

	mov ax, di    ;将首簇序号恢复到ax寄存器

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
	mov di, ax
	jmp get_loader_sector

get_odd_fat:
	mov ax, cx
	mov di, ax
	jmp get_loader_sector

loader_read_done:
	jmp 0x1140:0x00



mess: db "hello, stan!"
len: dw $-mess
fail_mess: db "can not find loader"
f_len: dw $-fail_mess

loader_name: db "LOADER  BIN", 0


dir_order: dw 19
dir_num: dw 14

entry_num: dw 16
entry_order: dw 0

double_fat_num: dw 1536
fat_sec_order: dw 0

odd_flage: dw 0

name_len: dw 11

times 510-($-$$) db 0
dw 0xaa55	