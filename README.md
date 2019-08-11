这里用来记录实现OS的过程。

主要参考书目是[一个64位操作系统的设计与实现](https://book.douban.com/subject/30222325/)以及[x86汇编：从实模式到保护模式](https://book.douban.com/subject/20492528/)，当然还有一些关于汇编语言的参考书。

这里会包含一份OS笔记，另外相关的是汇编的笔记，但是后者暂时存放在[archive](https://github.com/stan12138/archive/tree/master/study_notes)仓库中。

至于上述OS笔记，这份笔记其实已经比较早就开始写了，直到今天决定单独分离出来。笔记整体暂时不是特别有条理，因为不是连续写的，有很多东西其实并没有什么参考意义。。。

### 环境依赖

整个工作中需要的工具包含以下：

平台：win 64位

NASM编译器：win 64位版本(应该是64位版本，太久了我都忘了.....)

mingw64：mingw-w64，应该按照我的archive仓库里面的编译与编译器部分所述，下载那个既能编译32位又能编译64位的编译器版本，当然实际上我们一直都是在64位模式下工作的。

python3：python3都行。

### 代码使用说明及运行流程

现在的安排不一定合理，后面可能会改进，但是现状如下：

包含`bootloader, conf, img, kernel, lib, log, output, tmp, tools`这么几个文件夹。

其中的内容与功能如下：

~~~python
./bootloader:   boot.asm, loader.asm, Makefile     #存放bootloader的代码，以及编译脚本
./conf: hOS.bxrc    #bochs的配置文件
./img:  a.img     #1.44M软盘映像文件
./kernel:  一系列文件，包含了字体，显示，简单的图形功能，另外包含了一个Makefile
./lib:  按照规划应该把kernel里面的库文件放到这里面，但是还没做
./log:  bochs的日志输出
./output:  编译产生的boot.bin  loader.bin  kernel.bin
./tmp: 内核编译产生的中间文件
./tools:  fat.py   #软盘映像的fat12文件系统辅助工具
~~~

工作目录下，应该包含这些文件夹，如果缺了其中某个，请自行创建。

运行流程：

1. 在bootloader目录下运行Makefile： `migw32-make`

2. 在kernel目录下运行Makefile:  `mingw32-make`

3. 将output目录下产生的文件写入软盘映像，这一步需要借助python和`fat.py`的帮助，执行下述代码：

    ~~~python
    from fat import FAT12
    
    f = FAT12("../img/a.img")
    f.create_empty_img()
    f.set_mbr("../output/boot.bin")
    f.add("../output/loader.bin")
    f.add("../output/kernel.bin")
    f.info()
    ~~~

    执行上述代码之后，应该能看到信息，给出了文件系统里已经存放的文件长度，扇区信息等，如果确认loader和kernel都存在，那应该就没问题了。

4. 运行`bochs.exe`，load配置文件，start，应该就能看到正确执行。





### 基本流程

bootloader文件夹中包含了基本的`bootloader`代码。

bootloader的功能很简单，其中boot的功能包含了给出一些提示信息，最重要的任务是从磁盘上把loader加载进入内存。这一步涉及到了如何在磁盘上提取loader，其实很简单，直接使用BIOS的功能就能获取指定扇区，但是`boot.asm`里面把这一个步骤做了复杂化：在软盘上构建了一个FAT12文件系统，然后在boot里面构建了一个FAT12的文件系统解析器，通过文件系统获取loader。

当加载loader进入内存之后，就可以跳转进入loader。

loader首先完成的任务是给出一些提示信息。接下来需要跳转进入保护模式，然后通过Unreal mode以及FAT12文件系统，将内核代码搬运至高地址空间。

内核搬运完成之后，接下来只需要依次跳转进入保护模式，64位模式，接下来跳转进入内核即可。bootloader的任务就完成了。



### 代码说明与地址安排

MBR也即boot代码会被CPU加载进入0x7c00的位置，一共512字节。

在使用我自己写的汇编FAT12解析器的时候，我会一次性将9个FAT表扇区加载进入0x10000开始的位置

loader被我加载到了0x11400处







### 进度

2019.8.11  当前在做的事情主要是修改，完善和规范bootloader。主要的改进是采用函数式的设计，函数的设计要尽量和c的汇编规范一致，采用堆栈传输参数，同时要保持寄存器，不必约定任何寄存器，局部变量使用堆栈进行存储，返回值依赖约定的寄存器。主要改造对象是输出函数，清屏函数，读磁盘的函数，以及最重要的FAT12文件系统解析函数。现在的进展是前三者已经基本完成，函数设计规范的细节也已经确定了下来，但是最后的FAT12文件系统解析函数尚未完成，旧版本的逻辑十分混乱，正在清理，重写。因为尚未完成，所以就不再上传现在写完的函数了，我希望近期可以尽快完成(但是现在并没有什么心情的感觉.....)