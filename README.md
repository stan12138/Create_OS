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

2019.8.14  现在已经把bootloader中的清屏，输出，读入扇区，FAT12文件系统解析等功能构造为函数，函数的参数按照C语言规范，使用堆栈进行传输，同时在函数内部，局部变量也使用堆栈进行处理，另外函数内部还会保存所有的通用寄存器，隔离函数内外的作用域，防止过多的寄存器约定。截止到现在为止，对于Boot的改造还是成效不错的，但是改造并不彻底，其中的数据段寄存器存在着严重的模糊问题，例如在函数内部对于局部变量的寻址应该是用栈段寄存器作为数据段寄存器，于是代码变得越来越复杂，本来五六行代码就可以搞得的输出现在已经复杂到几十行了，并且段寄存器的问题还没修正完。我有点精疲力尽了，感觉我似乎在偏离规范，自说自话，所以先暂时搁置。对于Loader而言，问题变得更加复杂，在Loader中数据段寄存器的问题尤为突出，并且它在加载kernel的时候还牵扯到转存的问题，而转存的时候又特别使用了Big real mode里面设置好的fs寄存器，总之loader的fat12文件系统解析和扇区转存尚未完成，估计是要搁置了，暂时。现在已经把改造的函数写入`tools/function.asm`，这里面的函数在boot里面基本都测试完了，但是现在我还不想整合进去。

2019.8.15 昨天解决了上述问题，我刚知道原来内存寻址的时候段寄存器也是可以使用诸如`ss`这样的特殊段寄存器，而不是只能用`ds/es`.......然后现在基本上我已经把函数内部的寻址都加上了段寄存器，这样就万无一失了。现状是在函数内部，需要保持`bp`寄存器，也就是说一般情况下不要用bp，一定要用的话就要自行保持，然后函数内部提取参数，处理返回地址等都需要`bp`的帮助。然后函数内部如果需要使用局部变量，也应用堆栈来保存，此时提取局部变量需要使用其他的寄存器，例如`di`，此时要注意不要在其他地方随意使用这个寄存器。另外，如果在函数内部应用了某些段寄存器，需要自行保持状态，并在合适的位置恢复。还有就是`ds`寄存器，这个寄存器在函数内部尽量不要使用，函数内部某些情况下的寻址如果是依赖ds寄存器的值的话，也是需要在函数外面设置的，总之它类似于一个全局变量。现在的状态是：已经完成了`clean_screen`，`print`，`load_sector`，`load_fat12_file`，`move_sector`这几个函数，其中的`load_fat12_file`有一个普通版，还有一个为了loader的特殊版本，而`move_sector`则是专门为了big real mode下的loader定制的，它会额外的使用一个全局变量:`fs`寄存器。这些函数被分开放置到`tools`文件夹下，同时也被整合进了bootloader。

2019.8.24 基本搞懂了页表部分，重新整理了原本凌乱的笔记。后面应该会转向内核了。