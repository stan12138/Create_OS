move_sector:
	; loader特别定制,  void move_sector(dword edi[bp+6], word gs[bp+4])
	; 其中的edi代表转存的目的地，这里是一个偏移，gs代表转存的源，这里是一个段地址
	push bp
	mov bp, sp
	pusha

	push gs

	mov cx, [ss:bp+4]
	mov gs, cx
	mov cx, 200h   ;需要连续转存512字节
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
; tmp_address用来暂存目录项和FAT表，最长会占用9*520字节，filename是要寻找的名字的地址，address是暂时存储文件地址，最多使用512字节
; edi代表文件的最终目的地的偏移，而前述address代表的是暂存地址的段地址
	push bp
	mov bp, sp
	pusha

	; 从此处开始，算是开始执行在目录中搜索文件的任务，此处应该是和其余部分完全隔离，除了约定了一个将找到的文件
	; 的首簇序号放入ax寄存器之外，没有其他任何特别约定
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
	;find_file和find_fail都是目录区搜索结束，成功的话就会把首簇序号放入ax寄存器
	;除此之外，需要把局部变量，es寄存器等恢复或者弹出，保证不影响


	load_fat:
	; 加载所有FAT表
		push word 1
		push word 9
		push word [ss:bp+8]
		call load_sector  ;加载所有FAT表

		push es

		
		mov si, [ss:bp+4]  ;保存loader加载到的地址

		mov bx, [ss:bp+8]  ;在es内存入1000h，用来和bx配合获取FAT项
		mov es, bx

	;循环执行fat解析任务
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
