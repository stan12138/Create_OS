import math

class FAT12 :
	"""
	支持创建空白的光盘映像
	支持写入mbr
	支持写入文件
	支持列出光盘的信息

	默认支持3.5英寸的1.44M软盘的光盘映像
	默认每个簇只包含1个扇区
	(未考虑其他种类和尺寸的映像，相当有可能会出问题)
	文件写入时不检查重名
	文件属性都是归档文件
	文件都会被放在根目录
	文件没有时间戳和日期

	写入文件时，会自动检查是否存在重名，如果有重名，会删除旧文件，写入新文件

	本工具只是功能实现，没有做任何的优化，所以。。。。。。
	"""
	def __init__(self, filename="a.img", length=1474560):
		self.filename = filename
		self.length = length

		self.zero = b"\x00"      #一个字节的空白内容的二进制

		self.sector_length = 512 #每个扇区的长度，单位：字节。特别的这里每个簇只有1个扇区
		self.sec_len = self.sector_length #扇区长度的简写，接下来都用这个
		self.mbr_num = 1         #主引导扇区长度一个扇区
		self.fat1_num = 9        #第一个FAT表长度9个扇区
		self.fat2_num = 9        #第二个FAT表长度9个扇区
		self.dir_num = 14        #根目录区长度14个扇区

		self.data_sector_base = 2  #数据区的第一个簇的序号是2


	def create_empty_img(self) :
		"""
		创建一个空白的映像文件
		"""
		content = self.zero*self.length
		with open(self.filename, "wb") as fi :
			fi.write(content)

	def set_mbr(self, mbr_name) :
		"""
		设置映像的主引导扇区
		"""
		with open(mbr_name, "rb") as fi :
			mbr_content = fi.read()

		with open(self.filename, "rb") as fi :
			content = fi.read()

		content = mbr_content + content[self.mbr_num*self.sec_len:]

		content += self.zero*(self.length-len(content)) #似乎曾经观察到空白文件读不出内容？

		with open(self.filename, "wb") as fi :
			fi.write(content)

	def info(self) :
		"""
		获取光盘映像的信息
		"""
		file_info = self.parse_dir()
		fat_list = self.parse_fat()
		#print(file_info)
		all_info = []

		for one_file in file_info :
			one_info = {}
			one_info["name"] = one_file[0]
			one_info["len"] = one_file[2]
			#print(one_file)
			if one_file[1]>1 :
				sec_list = [one_file[1]]
			else :
				sec_list = []
			value = fat_list[one_file[1]]
			while value <= 0xfef and value>0x2 :
				sec_list.append(value)
				value = fat_list[sec_list[-1]]
			one_info["sector"] = sec_list
			all_info.append(one_info)
		print("file info :")
		use = 0
		for info in all_info :
			print(info)
			use += len(info["sector"])

		print("already use %s data sectors"%use)
		print("left %s data sectors can use"%(2847-use))
		print("left %s bytes can use"%((2847-use)*512))

	def delete(self, filename) :
		info = self.parse_dir()
		file_dir_order = -1
		file_first_fat = -1
		find = False

		for one_file in info :
			if filename.upper()==one_file[0] :
				find = True
				file_dir_order = one_file[-1]
				file_first_fat = one_file[1]
				break
		if find :
			dir_begin = (self.mbr_num+self.fat1_num+self.fat2_num)*512 + 32*file_dir_order
			dir_end = dir_begin+32
			with open(self.filename, "rb") as fi :
				content = fi.read()
			new_content = content[:dir_begin]+self.zero*32+content[dir_end:]
			with open(self.filename, "wb") as fi :
				fi.write(new_content)

			fat_list = self.parse_fat()
			while file_first_fat<=0xfef and file_first_fat>0x1 :
				f1 = fat_list[file_first_fat]
				fat_list[file_first_fat] = 0
				file_first_fat = f1
			self.write_fat(fat_list)



	def add(self, file) :
		"""
		向光盘映像中加入一个文件
		如果光盘映像中存在同名文件，就会被删除，然后添加
		"""
		self.delete(file)
		with open(file, 'rb') as fi :
			file_content = fi.read()    #文件内容
			
		file_length = len(file_content) #文件长度
		file_sec_num = math.ceil(file_length/512)  #存储这个文件需要的扇区数目
		fat_list = self.parse_fat()  #解析映像文件得到的fat表的内容列表
		will_use_sec_list = []   #存储这个文件要用到的扇区的序号列表
		#print(len(sector_use_list))
		for i in range(self.data_sector_base, 2850) : #1.44M的软盘只有2847个数据扇区，第一个扇区的序号是2，最后一个是2849
			if fat_list[i]==0 :
				will_use_sec_list.append(i)
				file_sec_num -= 1
				if file_sec_num==0 :
					break
		if file_sec_num != 0 :
			print('has not enough space, only %s Bytes free'%(length-num*512))
			return False
		new_fat = self.create_new_fat(fat_list, will_use_sec_list)
		#print(file_length, file_sec_num, will_use_sec_list, new_fat)
		self.write_file(file_content, will_use_sec_list)
		self.write_fat(new_fat)
		first_sec = will_use_sec_list[0]
		self.write_dir(file, first_sec, file_length)

	def write_fat(self, fat_list) :
		"""
		根据给出的fat的列表，自动转换生成新的fat二进制内容，并完成写入
		"""
		with open(self.filename, "rb") as fi :
			content = fi.read()
		fat_content = self.number2fat(fat_list)

		content = content[:self.sec_len*self.mbr_num]+fat_content+fat_content+content[(self.mbr_num+self.fat1_num+self.fat2_num)*self.sec_len:]
		with open(self.filename, "wb") as fi :
			fi.write(content)

	def write_dir(self, filename, first_sector, length) :
		"""
		给出要写入的文件的名字和首簇号，文件长度，自动写入目录
		"""
		name = filename[:filename.index(".")].upper().encode("ascii")
		suffix = filename[filename.index(".")+1:].upper().encode("ascii")

		if len(name)>8 or len(suffix)>3 :
			print("file name too long")
			return False

		name_content = name + b"\x20"*(8-len(name))  #文件名大写，采用8字节存储，不足用20H填充
		suffix_content = suffix + b"\x20"*(3-len(suffix)) #后缀大写，采用3字节存储，不足用20H填充

		attri_content = b"\x20"  #文件属性设置为归档文件

		keep_content = self.zero*10  #10个字节的保留区

		time_content = self.zero*2   #2字节时间戳，简化起见，不设置
		date_content = self.zero*2   #2字节日期，简化起见，不设置

		begin_content = first_sector.to_bytes(2, byteorder="little")
		#首簇号从2开始, 2字节小端存储
		length_content = length.to_bytes(4, byteorder="little")
		#文件长度4字节，小端存储


		dir_content = name_content+suffix_content+attri_content
		dir_content += keep_content+time_content+date_content
		dir_content += begin_content+length_content

		with open(self.filename, "rb") as fi :
			content = fi.read()

		dir_begin = (self.mbr_num+self.fat1_num+self.fat2_num)*self.sec_len
		dir_end = (self.mbr_num+self.fat1_num+self.fat2_num+self.dir_num)*self.sec_len

		origin_dir_content = content[dir_begin:dir_end]
		l = self.dir_num*self.sec_len
		for i in range(int(l/32)) :
			if origin_dir_content[32*i]==0 :
				origin_dir_content = origin_dir_content[:32*i]+dir_content+origin_dir_content[32*(i+1):]
				break
		content = content[:dir_begin]+origin_dir_content+content[dir_end:]
		with open(self.filename, "wb") as fi :
			fi.write(content)

	def write_file(self, file_content, sector_list) :
		"""
		将文件内容写入文件的数据区，根据生成的文件扇区使用列表
		"""
		with open(self.filename, 'rb') as fi :
			content = fi.read()
		# print(sector_list)
		# print(len(content))
		base = self.mbr_num+self.fat1_num+self.fat2_num+self.dir_num-self.data_sector_base
		#生成绝对扇区序号的基
		for index, sector in enumerate(sector_list)  :
			begin = (sector+base)*self.sec_len
			end = (sector+base+1)*self.sec_len
			part_of_file = file_content[index*self.sec_len:(index+1)*self.sec_len]
			part_of_file += (self.sec_len-len(part_of_file))*self.zero
			content = content[:begin] + part_of_file + content[end:]
		# 	print(index, sector, len(content))
		# print(len(content))
		with open(self.filename, "wb") as fi :
			fi.write(content)


	def create_new_fat(self, origin_fat_list, file_fat_list) :
		"""
		根据旧的fat列表和要存入的文件的fat占用列表生成新的fat列表
		"""
		for i in range(2, len(origin_fat_list)) :
			if i in file_fat_list :
				index_i = file_fat_list.index(i)
				if i==file_fat_list[-1] :
					origin_fat_list[i] = 0xfff
				else :
					origin_fat_list[i] = file_fat_list[index_i+1]
		return origin_fat_list

		
		
	def parse_fat(self) :
		"""
		解析一个映像的fat，生成扇区占用列表
		"""
		with open(self.filename, 'rb') as fi :
			content = fi.read()
			

		fat_content = content[self.mbr_num*self.sec_len:(self.mbr_num+self.fat1_num)*self.sec_len]
		content = 0
		return self.fat2number(fat_content)

	def parse_dir(self) :
		"""
		解析光盘映像的根目录区
		"""
		with open(self.filename, "rb") as fi:
			content = fi.read()

		begin = (self.mbr_num+self.fat1_num+self.fat2_num)*self.sec_len
		end = (self.mbr_num+self.fat1_num+self.fat2_num+self.dir_num)*self.sec_len
		dir_content = content[begin:end]

		l = self.dir_num*self.sec_len
		file_info = []
		for i in range(int(l/32)) :
			if dir_content[32*i]==0 :
				pass
			else :
				name = dir_content[32*i:(32*i+8)].replace(b"\x20",b"")
				suffix = dir_content[(32*i+8):(32*i+11)].replace(b"\x20",b"")
				first_sector = int.from_bytes(dir_content[(32*i+26):(32*i+28)],byteorder="little")
				#print(dir_content[(32*i+28):32*i])
				file_length = int.from_bytes(dir_content[(32*i+28):32*(i+1)], byteorder="little")
				one_info = [name.decode("ascii")+"."+suffix.decode("ascii"), first_sector, file_length, i]
				file_info.append(one_info)
		return file_info

	def fat2number(self, fat_content) :
		"""
		将原始的二进制形式的fat解析为序号列表
		"""
		fat_list = [one for one in fat_content]
		sector_list = []
		num = len(fat_list)
		for i in range(int(num/3)) :
			a,b,c = fat_list[3*i:3*(i+1)]
			
			b1 = b>>4
			b2 = b&0x0f
			
			sector_list.append((b2<<8)+a)
			sector_list.append((c<<4)+b1)
		return sector_list
		
	def number2fat(self, fat_sector_list) :
		"""
		将序号列表形式的fat表还原为二进制的fat内容
		"""
		label_num = len(fat_sector_list)
		fat_content = b''
		for i in range(int(label_num/2)) :
			a = fat_sector_list[2*i]
			b = fat_sector_list[2*i+1]

			a1 = a & 0x0ff
			a2 = a >> 8

			b1 = b >> 4
			b2 = b & 0x00f
			b2 = b2 << 4

			fat_content += a1.to_bytes(1, byteorder="little")
			fat_content += (b2+a2).to_bytes(1, byteorder="little")

			fat_content += b1.to_bytes(1, byteorder="little")

			
		fat_content += self.zero*(self.fat1_num*self.sec_len-len(fat_content))
		
		return fat_content
	
