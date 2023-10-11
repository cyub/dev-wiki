# NPTL

## 简介

在内核2.6以前的调度实体都是进程，内核并没有真正支持线程。它是通过系统调用clone()来实现的，在调用时候传递CLONE_VM这个标志位，这样新创建的进程（线程）会和当前进程共享进程地址空间，这种实现方式就是LinuxThread。我们创建新进程时候调用的fork函数，最后也是调用的clone()这个系统调用，只不过没有传递CLONE_VM这个标志位，所以fork创建的新进程和当前进程拥有的是两个不同的内存地址空间。

通过LinuxThread方式实现的多线程，并没有遵循没有遵循POSIX标准，特别是在信号处理，调度，进程间通信原语等方面。比如当给一个进程发送信号时候，由于该进程对应的线程自身拥有独立的进程ID，而无法进行响应。LinuxThread的内核对应的管理实体是进程，也称称LWP（轻量级进程），每个线程的pid是不一样的。

为了改进LinuxThread，NTPL(Native POSIX Threads Library)应运而生。

NPTL使用了跟LinuxThread相同的办法，在内核里面线程仍然被当作是一个进程，并且仍然使用了clone()系统调用(在NPTL库里调用)。但是，NPTL需要内核级的特殊支持来实现，比如需要挂起然后再唤醒线程的线程同步原语futex。

NPTL是一个1\*1的线程库，就是说当你使用pthread_create()调用创建一个线程后，在内核里就相应创建了一个调度实体，在linux里就是一个新进程，这个方法最大可能的简化了线程的实现。这种模式属于系统级线程。除此之外NPTL还支持m\*n模型。

## NPTL

### 创建线程

Linux内核中无论是进程还是线程，其底层数据结构都是[task_struct](https://github.com/torvalds/linux/blob/master/include/linux/sched.h#L661)。

```c
struct task_struct {
    ...
	pid_t   pid; // 进程ID或者线程ID
	pid_t   tgid;
    ...
}
```

NPTL为了方便管理线程，引入了线程组的概念，来实现同一组线程具有相同的PID。为此在task_struct结构体中增加了tgid字段来记录组PID。在线程组中的所有线程的tgid字段都指向线程组长（也可称为领头线程的）的PID。在线程中调用getpid()时候返回的是tgid，而不是当前线程的pid。

![](https://static.cyub.vip/images/202108/nptl_tgid.png)

NPTL创建线程时候也是使用clone系统调用，只不过传递flag参数设置了标志位CLONE_THREAD。

### 同步方式

内核增加一个新的互斥同步原语futex（fast usesapace locking system call），意为快速用户空间系统锁。因为进程内的所有线程都使用了相同的内存空间，所以这个锁可以保存在用户空间。这样对这个锁的操作不需要每次都切换到内核态，从而大大加快了存取的速度。NPTL提供的线程同步互斥机制都建立在futex上，所以无论在效率上还是咋对程序的外部影响上都比LinuxThread的方式有了很大的改进。

### 信号处理

因为同一个进程内的线程都属于同一个进程，所以信号处理跟POSIX标准完全统一。当你发送一个SIGSTP信号给进程，这个进程的所有线程都会停止。因为所有线程内用同样的内存空间，所以对一个signal的handler都是一样的，但不同的线程有不同的管理结构所以不同的线程可以有不同的mask。后面这一段对LinuxThread也成立。信号处理总结：

- 默认情况下，信号将由主进程接收处理，就算信号处理函数是由子线程注册的

- Linux 多线程应用中，每个线程可以通过调用pthread_sigmask() 设置本线程的信号掩码。一般情况下，被阻塞的信号将不能中断此线程的执行，除非此信号的产生是因为程序运行出错如SIGSEGV；另外不能被忽略处理的信号SIGKILL 和SIGSTOP 也无法被阻塞。

- 当一个线程调用pthread_create() 创建新的线程时，此线程的信号掩码会被新创建的线程继承。

- 可以使用pthread_kill对指定的线程发送信号

- 忽略信号不同于阻塞信号，忽略信号是指Linux内核已经向应用程序交付了产生的信号，只是应用程序直接丢弃了该信号而已。

- sigprocmask函数只能用于单线程，在多线程中使用pthread_sigmask函数。

- 信号是发给进程的特殊消息，其典型特性是具有异步性。


## 进一步阅读

- [NPTL分析之线程的创建](https://blog.csdn.net/joseph_1118/article/details/47275869)
- [Linux manual page: nptl](https://man7.org/linux/man-pages/man7/nptl.7.html)
- [ Linux线程的实现 & LinuxThread vs. NPTL & 用户级内核级线程 & 线程与信号处理](https://www.cnblogs.com/charlesblc/p/6242518.html)


