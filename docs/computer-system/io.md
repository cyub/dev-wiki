# IO

## Page Cache

在现代计算机系统中，CPU，RAM，DISK的速度不相同，按速度高低排列 为：CPU>RAM>DISK。CPU与RAM之间、RAM与DISK之间的速度差异常常是指数级。同时，它们之间的处理容量也不相同，其差异也是指数级。

为了在速度和容量上折中，**在CPU与RAM之间使用CPU cache以提高访存速度**，**在RAM与磁盘之间，操作系统使用page cache提高系统对文件的访问速度**。

**Page cache是通过将磁盘中的数据缓存到内存中，从而减少磁盘I/O操作，从而提高性能**。此外还要确保在page cache中的数据更改时能够被同步到磁盘上，后者被称为page回写（page writeback）。page回写往往不会立即执行，这样好处是可以减少磁盘的回写次数，提高吞吐量，不足之处就死机器挂掉，page cache中数据就会丢失。一个inode关联一个page cahce, 一个page cache对象包含多个物理page。

当应用程序需要读取文件中的数据时，操作系统先分配一些内存，将数据从存储设备读入到这些内存中，然后再将数据分发给应用程序；当需要往文件中写数据时，操作系统先分配内存接收用户数据，然后再将数据从内存写到磁盘上。文件Cache管理指的就是对这些由操作系统内核分配，并用来存储文件数据的内存管理。

在大部分情况下，内核在读写磁盘时都先通过页面Cache。若页面不在Cache中，新页加入到页面Cache中，并用从磁盘上读来的数据来填充页面。如果内存有足够的内存空间，该页可以在页面Cache长时间驻留，其他进程再访问该部分数据时，不需要访问磁盘。这就是free命令显示内核free值越来越小，cached值越来越大的原因。

同样，在把一页数据写到块设备之前，内核首先检查对应的页是否已经在页面Cache中；如果不在，就在页面Cache增加一个新页面，并用要写到磁盘的数据来填充。数据的I/O传输并不会立即开始执行，而是会延迟几秒左右；这样进程就有机会进一步修改写到磁盘的数据

对于系统的所有文件I/O请求，操作系统都是通过page cache机制实现的.对于操作系统而言，磁盘文件都是由一系列的数据块顺序组成，数据块的大小随系统不同而不同，**x86 linux系统下是4KB(一个标准页面大小)**。内核在处理文件I/O请求时，首先到page cache中查找(page cache中的每一个数据块都设置了文件以及偏移信息)，如果未命中，则启动磁盘I/O，将磁盘文件中的数据块加载到page cache中的一个空闲块，之后再copy到用户缓冲区中。

页面Cache可能是下面的类型：

- 含有普通文件数据的页
- 含有目录的页
- 含有直接从块设备文件（跳过文件系统层）读出的数据页
- 含有用户态进程数据的页，但页中的数据已被交换到磁盘
- 属于特殊文件系统的页，如进程间通信中的特殊文件系统shm

页面Cache中的每页所包含的数据是属于某个文件，这个文件（准确地说是文件的inode）就是该页的拥有者。事实上，所有的read（）和write（）都依赖于页面Cache；唯一的例外是当进程打开文件时，使用了O_DIRECT标志，在这种情况下，页面Cache被跳过，且使用了进程用户态地址空间的缓冲区。有些数据库应用程序使用O_DIRECT标志，这样他们可以使用自己的磁盘缓冲算法。

![](https://static.cyub.vip/images/202012/page-cache.jpg)

从硬盘读取文件时，同样不是直接把硬盘上文件内容读取到用户态内存，而是先拷贝到内核的page cache，然后再“拷贝”到用户态内存，这样用户就可以访问该文件。因为涉及到硬盘操作，所以第一次读取一个文件时，不会有性能提升；不过，如果一个文件已经存在page cache中，再次读取该文件时就可以直接从page cache中命中读取不涉及硬盘操作，这时性能就会有很大提高。

下面用dd比较下异步（缺省模式）和同步写硬盘的速度差别：

```
$ dd if=/dev/urandom of=async.txt bs=64M count=16 iflag=fullblock
16+0 records in
16+0 records out
1073741824 bytes (1.1 GB, 1.0 GiB) copied, 7.618 s, 141 MB/s
$ dd if=/dev/urandom of=sync.txt bs=64M count=16 iflag=fullblock oflag=sync
16+0 records in
16+0 records out
1073741824 bytes (1.1 GB, 1.0 GiB) copied, 13.2175 s, 81.2 MB/s
```

**如何查看一个文件占用page cache情况?**

我们可以借助[vmtouch](https://hoytech.com/vmtouch/)工具

## Cache同步方式

Cache的同步方式有两种，即**Write Through（写穿）** 和 **Write back（写回）** 。

对应到Linux的Page Cache上所谓Write Through就是指write(2)操作将数据拷贝到Page Cache后立即和下层进行同步的写操作，完成下层的更新后才返回，可以理解为写穿透page cache直抵磁盘。

而Write back正好相反，指的是写完Page Cache就可以返回了，可以理解为写到page cache就返回了。Page Cache到下层的更新操作是异步进行的。

Linux下Buffered IO默认使用的是Write back机制，即文件操作的写只写到Page Cache就返回，之后Page Cache到磁盘的更新操作是异步进行的。Page Cache中被修改的内存页称之为脏页（`Dirty Page`），脏页在特定的时候被一个叫做`pdflush`(Page Dirty Flush)的内核线程写入磁盘，写入的时机和条件如下：

> 当空闲内存低于一个特定的阈值时，内核必须将脏页写回磁盘，以便释放内存。 当脏页在内存中驻留时间超过一个特定的阈值时，内核必须将超时的脏页写回磁盘。 用户进程调用sync(2)、fsync(2)、fdatasync(2)系统调用时，内核会执行相应的写回操作。

**如果程序crash，异步模式(write back)会丢失数据吗？**

如果OS没有crash或者重启的话，仅仅是写数据的程序crash，那么已经成功写入到page cache中的dirty pages是会被pdflush在合适的时机被写回到硬盘，不会丢失数据； 如果OS也crash或者重启的话，因为page cache存放在内存中，一旦断电就丢失了，那么就会丢失数据。

**那么如何避免因为系统重启或者机器突然断电，导致数据丢失问题呢？**

可以借助于WAL（Write-Ahead Log）技术。WAL技术在数据库系统中比较常见，在数据库中一般又称之为redo log，Linux 文件系统ext3/ext4称之为journaling。WAL作用是：写数据库或者文件系统前，先把相关的metadata和文件内容写入到WAL日志中，然后才真正写数据库或者文件系统。WAL日志是append模式，所以，对WAL日志的操作要比对数据库或者文件系统的操作轻量级得多。如果对WAL日志采用同步写模式，那么WAL日志写成功，即使写数据库或者文件系统失败，可以用WAL日志来恢复数据库或者文件系统里的文件。

## mmap - Memory Map

同一块文件数据，在内存中保存了两份(内核必须将页面缓存的内容复制到用户缓冲区中），这既占用了不必要的内存空间、冗余的拷贝、以及造成的CPU cache利用率不高。针对此问题，操作系统提供了内存映射机制（linux中mmap、windows中Filemapping）。如下图：

![mmap](https://static.cyub.vip/images/202009/mmap.gif?ynotemdtimestamp=1601743305233)

当使用文件映射时，内核将程序的虚拟页面直接映射到页面缓存中。在使用mmap调用时，系统并不是马上为其分配内存空间，而仅仅是添加一个VMA到该进程中，当程序访问到目标空间时，产生**缺页中断**。在缺页中断中，从page caches中查找要访问的文件块，若未命中，则启动磁盘I/O从磁盘中加载到page caches。然后将文件块在page caches中的物理页映射到进程mmap地址空间。

**当程序退出或关闭文件时，系统是否会马上清除page caches中的相应页面呢？**

答案是否定的。由于该文件可能被其他进程访问，或该进程一段时间后会重新访问，因此，在物理内存足够的情况下，系统总是将其保持在page caches中，这样可以提高系统的整体性能(提高page caches的命中率，尽量少的访问磁盘)。只有当系统物理内存不足时，内核才会主动清理page caches。

当进程调用write修改文件时，由于page cache的存在，修改并不是马上更新到磁盘，而只是暂时更新到page caches中，同时mark 目标page为dirty，当内核主动释放page caches时，才将更新写入磁盘(主动调用sync时，也会更新到磁盘)。

内存映射文件的写入不一定是对磁盘文件的即时（同步）写入。有的操作系统定期检查文件的内存映射页面是否已被修改，以便选择是否更新到物理文件。当关闭文件时，所有内存映射的数据会写到磁盘，并从进程虚拟内存中删除。

**多个进程可以允许并发地内存映射同一文件，以便允许数据共享**。任何一个进程的写入会修改虚拟内存的数据，并且其他映射同一文件部分的进程都可看到。

虚拟映射只支持文件。我们可以通过`/proc/<pid>/maps`查看进行pid的mmap文件。

## Zero Copy

**零拷贝(Zero Copy)技术是直接从内核空间（DMA的）到内核空间（Socket的)、然后发送网卡**。

传统的网络I/O操作流程，大体上分为以下4步：

1. OS从硬盘把数据读到内核区的PageCache。
2. 用户进程把数据从内核区Copy到用户区。
3. 然后用户进程再把数据写入到Socket，数据流入内核区的Socket Buffer上。
4. OS再把数据从Buffer中Copy到网卡的Buffer上，这样完成一次发送。


![](https://static.cyub.vip/images/202009/sendfile.png)

![](https://static.cyub.vip/images/202009/network_io2.webp)

从上图可以看出，传统网络IO会历经两次Context Switch，四次数据拷贝。实际上IO读写，需要进行IO中断，需要CPU响应中断(带来上下文切换)，尽管后来引入DMA来接管CPU的中断请求，但四次copy是存在“不必要的拷贝”的。

同一份数据在内核buffer与用户buffer之间重复拷贝，效率低下。其中2，3两步没有必要，完全可以直接在内核空间完成数据拷贝。这也是sendfile所解决的问题，经过sendfile优化后，整个I/O过程变成了下面的样子：

![](https://static.cyub.vip/images/202009/sendfile.png)

![](https://static.cyub.vip/images/202009/sendfile2.webp)

从上图可以看出，通过sendfile 系统调用，提供了零拷贝。磁盘数据通过 DMA 拷贝到内核态 Buffer 后，直接通过 DMA 拷贝到 NIC Buffer(socket buffer)，无需 CPU 拷贝，所以称为零拷贝。除了减少数据拷贝外，因为整个读文件 - 网络发送由一个 sendfile 调用完成，整个过程只有两次上下文切换，因此大大提高了性能。


### 零拷贝应用场景

1. 如Tomcat、Nginx、Apache等web服务器返回静态资源等，将数据用网络发送出去，都运用了sendfile

2. Kafka中的Consumer从broker中获取消息时候，broker使用到了sendfile

### mmap 和 sendfile比较

1. 都是Linux内核提供、实现零拷贝的API

2. sendfile 是将读到内核空间的数据，转到socket buffer，进行网络发送

3. mmap将磁盘文件映射到内存，支持读和写，对内存的操作会反映在磁盘文件上

**什么是DMA？**

本质上，DMA技术就是我们在主板上放⼀块独立的芯片。在进行内存和I/O设备的数据传输的时候，我们不再通过CPU来控制数据传输，而直接通过 DMA控制器（DMA?Controller，简称DMAC）。这块芯片，我们可以认为它其实就是一个协处理器（Co-Processor）)

## IO模式

### 1.1 用户空间和内核空间
　　现在操作系统都采用虚拟寻址，处理器先产生一个虚拟地址，通过地址翻译成物理地址（内存的地址），再通过总线的传递，最后处理器拿到某个物理地址返回的字节。

　　对32位操作系统而言，它的寻址空间（虚拟存储空间）为4G（2的32次方）。操作系统的核心是内核，独立于普通的应用程序，可以访问受保护的内存空间，也有访问底层硬件设备的所有权限。为了保证用户进程不能直接操作内核（kernel），保证内核的安全，操心系统将虚拟空间划分为两部分，一部分为内核空间，一部分为用户空间。针对linux操作系统而言，将最高的1G字节（从虚拟地址0xC0000000到0xFFFFFFFF），供内核使用，称为内核空间，而将较低的3G字节（从虚拟地址0x00000000到0xBFFFFFFF），供各个进程使用，称为用户空间。

补充：地址空间就是一个非负整数地址的有序集合。如{0,1,2...}。

### 1.2 进程上下文切换（进程切换）
　　为了控制进程的执行，内核必须有能力挂起正在CPU上运行的进程，并恢复以前挂起的某个进程的执行。这种行为被称为进程切换（也叫调度）。因此可以说，任何进程都是在操作系统内核的支持下运行的，是与内核紧密相关的。

　　从一个进程的运行转到另一个进程上运行，这个过程中经过下面这些变化：
1. 保存当前进程A的上下文。

　　上下文就是内核再次唤醒当前进程时所需要的状态，由一些对象（程序计数器、状态寄存器、用户栈等各种内核数据结构）的值组成。

　　这些值包括描绘地址空间的页表、包含进程相关信息的进程表、文件表等。
　　
2. 切换页全局目录以安装一个新的地址空间。

3. 恢复进程B的上下文。

　　可以理解成一个比较耗资源的过程。
　　
### 1.3 进程的阻塞

正在执行的进程，由于期待的某些事件未发生，如请求系统资源失败、等待某种操作的完成、新数据尚未到达或无新工作做等，则由系统自动执行阻塞原语(Block)，使自己由运行状态变为阻塞状态。可见，进程的阻塞是进程自身的一种主动行为，也因此只有处于运行态的进程（获得CPU），才可能将其转为阻塞状态。当进程进入阻塞状态，是不占用CPU资源的。

### 1.4 文件描述符
文件描述符（File descriptor）是计算机科学中的一个术语，是一个用于表述指向文件的引用的抽象化概念。

文件描述符在形式上是一个非负整数。实际上，它是一个索引值，指向内核为每一个进程所维护的该进程打开文件的记录表。当程序打开一个现有文件或者创建一个新文件时，内核向进程返回一个文件描述符。在程序设计中，一些涉及底层的程序编写往往会围绕着文件描述符展开。但是文件描述符这一概念往往只适用于UNIX、Linux这样的操作系统。

### 1.5 直接I/O和缓存I/O

**缓存I/O** 又被称作标准 I/O，大多数文件系统的默认 I/O 操作都是缓存 I/O。在 Linux 的缓存 I/O 机制中，以write为例，数据会先被拷贝进程缓冲区，在拷贝到操作系统内核的缓冲区中，然后才会写到存储设备中。

![](http://static.cyub.vip/images/201811/cache-io.png)

直接I/O的write：（少了拷贝到进程缓冲区这一步）

![](http://static.cyub.vip/images/201811/non-cache-io.png)

write过程中会有很多次拷贝，直到数据全部写到磁盘。

## I/O模式

对于一次IO访问（这回以read举例），数据会先被拷贝到操作系统内核的缓冲区中，然后才会从操作系统内核的缓冲区拷贝到应用程序的缓冲区，最后交给进程。所以说，当一个read操作发生时，它会经历两个阶段：
1. 等待数据准备 (Waiting for the data to be ready)
2. 将数据从内核拷贝到进程中 (Copying the data from the kernel to the process)

正式因为这两个阶段，linux系统产生了下面五种网络模式的方案：
- 阻塞 I/O（blocking IO）
- 非阻塞 I/O（nonblocking IO）
- I/O 多路复用（ IO multiplexing）
- 信号驱动 I/O（ signal driven IO）
- 异步 I/O（asynchronous IO）

### block I/O模型（阻塞I/O）

阻塞I/O模型示意图：

![](https://static.cyub.vip/images/202012/block-io.png)
<!-- ![](https://static.cyub.vip/images/201811/block-io.png) -->

read为例：

（1）进程发起read，进行recvfrom系统调用；

（2）内核开始第一阶段，准备数据（从磁盘拷贝到缓冲区），进程请求的数据并不是一下就能准备好；准备数据是要消耗时间的；

（3）与此同时，进程阻塞（进程是自己选择阻塞与否），等待数据ing；

（4）直到数据从内核拷贝到了用户空间，内核返回结果，进程解除阻塞。

也就是说，内核准备数据和数据从内核拷贝到进程内存地址这两个过程都是阻塞的。

### 2.2 non-block（非阻塞I/O模型）
可以通过设置socket使其变为non-blocking。当对一个non-blocking socket执行读操作时，流程是这个样子：

![](https://static.cyub.vip/images/202012/noblock-io.png)
<!-- ![](https://static.cyub.vip/images/201811/non-block-io.jpg) -->

1. 当用户进程发出read操作时，如果kernel中的数据还没有准备好；

2. 那么它并不会block用户进程，而是立刻返回一个error，从用户进程角度讲 ，它发起一个read操作后，并不需要等待，而是马上就得到了一个结果；

3. 用户进程判断结果是一个error时，它就知道数据还没有准备好，于是它可以再次发送read操作。一旦kernel中的数据准备好了，并且又再次收到了用户进程的system call；

4. 那么它马上就将数据拷贝到了用户内存，然后返回。

所以，nonblocking IO的特点是用户进程在内核准备数据的阶段需要不断的主动询问数据好了没有。

### 2.3 I/O多路复用

I/O多路复用实际上就是用select, poll, epoll监听多个io对象，当io对象有变化（有数据）的时候就通知用户进程。好处就是单个进程可以处理多个socket。当然具体区别我们后面再讨论，现在先来看下I/O多路复用的流程：

![](https://static.cyub.vip/images/202012/io-mux.png)

<!-- ![](https://static.cyub.vip/images/201811/io-mux.png) -->

1. 当用户进程调用了select，那么整个进程会被block；

2. 而同时，kernel会“监视”所有select负责的socket；

3. 当任何一个socket中的数据准备好了，select就会返回；

4. 这个时候用户进程再调用read操作，将数据从kernel拷贝到用户进程。
所以，I/O 多路复用的特点是通过一种机制一个进程能同时等待多个文件描述符，而这些文件描述符（套接字描述符）其中的任意一个进入读就绪状态，select()函数就可以返回。

这个图和blocking IO的图其实并没有太大的不同，事实上，还更差一些。因为这里需要使用两个system call (select 和 recvfrom)，而blocking IO只调用了一个system call (recvfrom)。但是，用select的优势在于它可以同时处理多个connection。

所以，如果处理的连接数不是很高的话，使用select/epoll的web server不一定比使用多线程 + 阻塞 IO的web server性能更好，可能延迟还更大。

select/epoll的优势并不是对于单个连接能处理得更快，而是在于能处理更多的连接。）

在IO multiplexing Model中，实际中，对于每一个socket，一般都设置成为non-blocking，但是，如上图所示，整个用户的process其实是一直被block的。只不过process是被select这个函数block，而不是被socket IO给block。

**select & poll & epoll比较:**

1. 每次调用 select 都需要把所有要监听的文件描述符拷贝到内核空间一次，fd很大时开销会很大。 epoll 会在epoll_ctl()中注册，只需要将所有的fd拷贝到内核事件表一次，不用再每次epoll_wait()时重复拷贝
2. 每次 select 需要在内核中遍历所有监听的fd，直到设备就绪； epoll 通过 epoll_ctl 注册回调函数，也需要不断调用 epoll_wait 轮询就绪链表，当fd或者事件就绪时，会调用回调函数，将就绪结果加入到就绪链表。

3. **select 能监听的文件描述符数量有限，默认是1024**； epoll 能支持的fd数量是最大可以打开文件的数目，具体数目可以在/proc/sys/fs/file-max查看
**select , poll 在函数返回后需要查看所有监听的fd，看哪些就绪**，而**epoll只返回就绪的描述符**，所以应用程序只需要就绪fd的命中率是百分百。

### 2.4 信号驱动IO

 当进程发起一个IO操作，会向内核注册一个信号处理函数，然后进程返回不阻塞；当内核数据就绪时会发送一个信号给进程，进程便在信号处理函数中调用IO读取数据。

![](https://static.cyub.vip/images/202012/signal-io.png)

异步 I/O 与信号驱动 I/O 的区别在于，**异步 I/O 的信号是通知应用进程 I/O 完成，而信号驱动 I/O 的信号是通知应用进程可以开始 I/O**。

###  2.5 asynchronous I/O（异步 I/O）

![](https://static.cyub.vip/images/202012/async-io.png)

<!-- ![](https://static.cyub.vip/images/201811/asynchronous-io-2.png) -->

1. 用户进程发起read操作之后，立刻就可以开始去做其它的事。

2. 而另一方面，从kernel的角度，当它受到一个asynchronous read之后，首先它会立刻返回，所以不会对用户进程产生任何block。

3. 然后，kernel会等待数据准备完成，然后将数据拷贝到用户内存，当这一切都完成之后，kernel会给用户进程发送一个signal，告诉它read操作完成了。



　　
### 小结

1. blocking和non-blocking的区别

调用blocking IO会一直block住对应的进程直到操作完成，而non-blocking IO在kernel还准备数据的情况下会立刻返回。

2. synchronous IO和asynchronous IO的区别
在说明synchronous IO和asynchronous IO的区别之前，需要先给出两者的定义。POSIX的定义是这样子的：

- A synchronous I/O operation causes the requesting process to be blocked until that I/O operation completes;
- An asynchronous I/O operation does not cause the requesting process to be blocked;

两者的区别就在于synchronous IO做”IO operation”的时候会将process阻塞。按照这个定义，之前所述的blocking IO，non-blocking IO，IO multiplexing都属于synchronous IO。

有人会说，non-blocking IO并没有被block啊。这里有个非常“狡猾”的地方，定义中所指的”IO operation”是指真实的IO操作，就是例子中的recvfrom这个system call。non-blocking IO在执行recvfrom这个system call的时候，如果kernel的数据没有准备好，这时候不会block进程。但是，当kernel中数据准备好的时候，recvfrom会将数据从kernel拷贝到用户内存中，这个时候进程是被block了，在这段时间内，进程是被block的。

而asynchronous IO则不一样，当进程发起IO 操作之后，就直接返回再也不理睬了，直到kernel发送一个信号，告诉进程说IO完成。在这整个过程中，进程完全没有被block。

3. non-blocking IO和asynchronous IO的区别

可以发现non-blocking IO和asynchronous IO的区别还是很明显的。

- 在non-blocking IO中，虽然进程大部分时间都不会被block，但是它仍然要求进程去主动的check，并且当数据准备完成以后，也需要进程主动的再次调用recvfrom来将数据拷贝到用户内存。

- 而asynchronous IO则完全不同。它就像是用户进程将整个IO操作交给了他人（kernel）完成，然后他人做完后发信号通知。在此期间，用户进程不需要去检查IO操作的状态，也不需要主动的去拷贝数据。


## 资料

- [5种IO模型、阻塞IO和非阻塞IO、同步IO和异步IO](https://blog.csdn.net/tjiyu/article/details/52959418)
　　
　　

