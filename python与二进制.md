## Python与二进制

因为之前的fat12的python工具的制作过程就涉及到了python和二进制内容的交互，接下来我计划做的一些事情也会涉及到这些，所以就写一个简单的笔记。



python3中新增了一个类型叫做bytes

hex是一个字符编码函数，可以把一个对象编码为16进制形式，转换产生一个字符串。

bytes就代表二进制内容，其实它就相当于一个字节序列，或者称之小整数序列都可以，他的长度就是字节数，每个位置的索引都会的到一字节的内容，返回一个整数。

一个bytes可以被解码

bytes常量的创建，可以使用`b'spam'`这样的形式，当然每个字符是一个字节

一个非常重要的，常见的操作就是将一个整数转换为一个bytes，以及将bytes转换为整数

那么明显，整数到bytes应该是需要指定转换为多少个字节的，以及字节序是大小端，还有就是要不要符号位。自然，正常情况下，我们处理的都是正数，符号位也设置为False，如果处理的是负数会怎么样呢？负数自然是必须要带符号位，否则就无法工作。另外要注意的就是数字不能超出字节数的最大范围，否则就是溢出。

而bytes到整数的转换明显只需要给出字节序和符号位就行了。

~~~python
a = 16
aim = a.to_bytes(2, byteorder='little', signed=False)

b = b'\xa0\x00'
a = int.from_bytes(b, byteorder='little', signed=False)
~~~

但是根据我的测试，bytes应该是不能直接执行位操作的，左右移位，之类的。



接下来的一个重要问题是如果计划直接观察二进制，那么应该怎么输出？也就是说需要把bytes转化为二进制，或者16进制的字符串。

此时应该使用`hex()或者bin()`



