clean_screen:
; 函数原型：void clean_screen(word 左上(bp+8), word 右下(bp+6), word 颜色(bp+4))
	push bp
	mov bp, sp
	pusha

	mov ax, 0600h

	mov bx, [bp+4]   ;第三个参数
	mov dx, [bp+6]   ;第二个参数
	mov cx, [bp+8]   ;第一个参数

	int 10h

	mov ax, [bp+2]   ;获取返回地址的位置 
	mov [bp+8], ax   ;将返回地址放入第一个参数所在的地方
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
	mov dx, [bp+10]
	mov cx, [bp+8]

	push es        ;如果在函数内部修改了段寄存器，必须要注意保存和恢复，popa，pusha与段寄存器无关

	mov bx, 0000h
	mov es, bx
	mov bx, [bp+4]
	mov bh, 00h
	push bp
	mov bp, [bp+6]
	int 10h
	pop bp

	pop es

	mov ax, [bp+2]   ;获取返回地址的位置 
	mov [bp+10], ax  ;将返回地址放入第一个参数所在的地方
	popa
	pop bp
	add sp, 8        ;弹出参数

	ret

load_sector:
; 函数原型：void load_sector(word sector_index(bp+8), word sector_num(bp+6), word address(bp+4))
	push bp
	mov bp, sp
	pusha

	mov ax, [bp+8]
	mov cx, [bp+6]
	mov si, [bp+4]
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

	mov ax, [bp+2]   ;获取返回地址的位置 
	mov [bp+8], ax  ;将返回地址放入第一个参数所在的地方
	popa
	pop bp
	add sp, 6        ;弹出参数

	ret


load_file_fat12:
; 函数原型：void load_file_fat12(word tmp_address(bp+8), word filename(bp+6), word address(bp+4)) 
; tmp_address用来暂存目录项和FAT表，最长会占用9*520字节，filename是要寻找的名字的地址，address是最后要存储的文件地址
	push bp
	mov bp, sp
	pusha

	;我决定将此处的三个循环变量改造为局部变量，使用堆栈存储
	push word 19   ;目录扇区序号   sp+4-------di+4
	push word 0    ;扇区内目录项偏移    sp+2------di+2
	push word 0    ;目录项内文件名字字母序号   sp----di

	mov di, sp

	search_dir:
		cmp word [di+4], 33    ;如果所有目录扇区已搜索完成，失败
		jz find_fail           ;jz是当前述二者相等时会执行
		
		push word [di+4] ;当前依旧是有效目录扇区，那么开始准备读入扇区
		push word 0001h  ;扇区序号是[sp+4]，读入1个扇区
		push word [bp+8]  ;读入到0x1000:0000 即0x10000
		call load_sector

		inc word [di+4]  ;下一个扇区序号是加一

		mov word [di+2], 0  ;准备开始在已经加载的扇区内搜索各个目录项
	search_one_sector:
		cmp word [di+2], 520 ;目录项搜索完毕就失败，检查下一个扇区
		jz search_dir        

		mov si, 1000h
		mov es, si     ;将es寄存器设置为目录扇区在内存中的段地址
		mov bx, [di+2]  ;将当前目录项的起始偏移载入bx

		add word [di+2], 32  ;生成下一个目录项的偏移

		mov word [di], 0    ;生成要搜索的字母的偏移0


		mov si, 0        
		mov ds, si     ;设置ds为0，这是为了后面loadsb
		mov si, [bp+6]  ;将目标文件名载入si

	search_one_entry:
		cmp word [di], 11   ;比较当前搜索的字母的序号，如果等于11代表检查成功
		jz find_file

		inc word [di]   ;字母序号加一
		lodsb      ;从ds:si加载一个字节进入al，自增si
		cmp al, byte [es:bx]   ;比较目标字母和当前字母是否一致
		jz one_character_success  ;如果一致自增bx之后，开始比较下一个字母
		jmp search_one_sector  ;不一致搜索下一个目录项

	one_character_success: 
		inc bx
		jmp search_one_entry
	find_file:
		add sp, 6 ;弹出3个局部变量

		add bx, 15 ;检查文件名成功之后，bx加15就是这个目录项中存储首簇序号的位置
		mov ax, [es:bx]  ;将首簇序号加载进入ax寄存器
		jmp load_fat

	find_fail:
		add sp, 6 ;弹出3个局部变量
		jmp $


	load_fat:
		push word 1
		push word 9
		push word [bp+8]
		call load_sector  ;加载所有FAT表

		
		mov si, [bp+4]  ;保存loader加载到的地址

		mov bx, [bp+8]  ;在es内存入1000h，用来和bx配合获取FAT项
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
		add si, 20h  ;下一个扇区si加20h即 200h->520B

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
		push ax
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

		mov ax, [bp+2]   ;获取返回地址的位置 
		mov [bp+8], ax  ;将返回地址放入第一个参数所在的地方
		popa
		pop bp
		add sp, 6        ;弹出参数

		ret