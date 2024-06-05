## 如何评价Go语言？

- 简洁
    - 语法简洁，没有传统语言的继承，try-catch异常处理机制
    - 并发编程模式简单，通过通道控制
    - 但支持类型断言，泛型(1.18开始)
- 并发
    - 采用混合调度模型
    - 采用通道进行数据同步
- 内存安全
    - 自带垃圾回收功能
- 良好的工具生态
    - 自带格式化工具
    - 内置性能调优诊断工具

## Go的调度机制（GMP模型）

### GMP指的是什么？

- G（Goroutine）：Goroutine，即协程，为用户级的轻量级线程，每个 Goroutine对象中的 sched 保存着其上下文信息(sp、pc等信息）。G是参与调度与执行的最小单位，是并发的关键。
- M（Machine）：是对内核级线程的抽象封装。M负责执行G。
- P（Processor）：即为 G 和 M 的调度对象，用来调度 G 和 M 之间的关联关系，其数量可通过 GOMAXPROCS()或者GOMAXPROC环境变量来设置，默认为核心数。Linux中P的数量是通过CPU亲和性的系统调用获取。每个P都拥有一个本地可运行G的队列(Local ruanble queue，简称为LRQ)，该队列最多可存放256个G。P的runnext字段也存放了一个G，属于快速路径。

### GMP调度流程

- 每个P有个局部队列(LRQ)，局部队列保存待执行的goroutine(流程2)，当M绑定的P的的局部队列已经满了之后就会把goroutine放到全局队列(流程2-1)
- 每个P和一个M绑定，**M是真正的执行P中goroutine的实体(流程3)** ，M从绑定的P中的局部队列获取G来执行
- 当M绑定的P的局部队列为空时，M会从全局队列获取到本地队列来执行G(流程3.1)，当从全局队列中没有获取到可执行的G时候，M会从其他P的局部队列中偷取G来执行(流程3.2)，这种从其他P偷的方式称为**work stealing**
- 当G因系统调用阻塞(属于系统调用阻塞）时会阻塞M，此时P会和M解绑即**hand off**，并寻找新的idle的M，若没有idle的M就会新建一个M(流程5.1)
- 当G因channel(属于用户态阻塞)或者network I/O阻塞时，不会阻塞M，M会寻找其他runnable的G；当阻塞的G恢复后会重新进入runnable进入P队列等待执行(流程5.3)

#### work stealing 机制

获取 P 本地队列，当从绑定 P 本地 runq 上找不到可执行的 g，尝试从全局链表中拿，再拿不到从 netpoll 和事件池里拿，最后会从别的 P 里偷任务。P此时去唤醒一个 M。P 继续执行其它的程序。M 寻找是否有空闲的 P，如果有则将该 G 对象移动到它本身。接下来 M 执行一个调度循环（调用 G 对象->执行->清理线程→继续找新的 Goroutine 执行）。可以看出来work stealing机制包含了两阶段调度模型。

#### hand off 机制

当本线程 M 因为 G 进行的系统调用阻塞时，线程释放绑定的 P，把 P 转移给其他空闲的 M 执行。

细节：当发生上线文切换时，需要对执行现场进行保护，以便下次被调度执行时进行现场恢复。Go 调度器 M 的栈保存在 G 对象上，只需要将 M 所需要的寄存器（SP、PC 等）保存到 G 对象上就可以实现现场保护。当这些寄存器数据被保护起来，就随时可以做上下文切换了，在中断之前把现场保存起来。如果此时G 任务还没有执行完，M 可以将任务重新丢到 P 的任务队列，等待下一次被调度执行。当再次被调度执行时，M 通过访问 G 的 vdsoSP、vdsoPC 寄存器进行现场恢复（从上次中断位置继续执行）。

### GMP 调度过程中存在哪些阻塞?

- I/O（其中网络层级IO已经实现用户级阻塞，不会handleoff M)
- block on syscall（系统级阻塞，会handoff M)
- channel/select(用户级阻塞)
- 等待锁
- runtime.Gosched() (主动handoff M)

### GMP 中为什么需要P?

GM 调度存在的问题：

1. 单一全局互斥锁（Sched.Lock）和集中状态存储
2. Goroutine 传递问题（M 经常在 M 之间传递”可运行”的 goroutine）
3. 每个 M 做内存缓存，导致内存占用过高，数据局部性较差
4. 频繁 syscall 调用，导致严重的线程阻塞/解锁，加剧额外的性能损耗

### Go中协作式抢占式调度存在的问题，以及后面如何解决了？

Go1.14 版本之前，Gorountine需要栈分裂时候，才能触发调度。这种方式存在问题有：

- 某些 Goroutine 可以长时间占用线程，造成其它 Goroutine 的饥饿（比如for循环）
- 垃圾回收需要暂停整个程序（Stop-the-world，STW），最长可能需要几分钟的时间，导致整个程序无法工作。

Go1.14之后开始支持基于信号的抢占式调度。为了防止执行信号的handle函数，发生栈溢出，每个Goroutine都有一个专门的信号栈。从细节来看具体原因是go1.14和go.1.13的调度器有一定的不同。

两者都支持抢占式调度，当go runtime启动时候，都会创建一个独立的M，称为sysmon，它既不关联P也不执行G，它是系统级线程。sysmon会检查go runtime中长时间运行的G，并进行抢占。

go1.13版本中，sysmon如果发现某个G运行时间超过10ms就会将该G标记为可抢占状态，此外G在运行过程中有一个函数栈分裂处理的逻辑，该处理逻辑会查看其是否被标记为可抢占状态，如果是那么其会让出其关联的M。

示例代码中for循序不会出现栈分裂的情况，所以G即使运行超过10ms也不会被抢占。由于所有的P关联的G都运行着for死循环，且不会被抢占，那么就没有多余的P可以执行fmt.Println语句了。

由于go1.13是基于函数栈分裂实现的抢占式调度，所以也称为半抢占式调度(即未完全实现抢占式调度）或协作抢占式调度。

go1.14版本为了解决类似示例代码中问题，引入了信号机制实现抢占式调度。sysmon发现某个G运行时间超过10ms，就会给该G发送一个信号（SIGURG），该G收到抢占调度信号后，会让出M。

### Sysmon 有什么作用?

Go Runtime 在启动程序的时候，会创建一个独立的 M 作为监控线程，称为 sysmon，它是一个系统级的 daemon 线程。这个sysmon 独立于 GPM 之外，也就是说不需要P就可以运行。sysmon监控线程的功能有：

- 用于网络轮询器中，唤醒准备就绪的fd关联的goroutine
- 如果超过2分钟没有GC，则强制执行GC一次
- 抢占运行时间太长Goroutine（超过10ms的g，会进行retake)
- handle off长时间运行系统调用的M，即将M和P解绑，P重新找到空闲的M，执行任务，若没有空闲的M，则会创建一个。
- 定时器与滴答器的调度处理
- 打印schedule trace信息

## defer 语法特点有哪些，底层实现机制？

### 概念

defer语法是用来定义一个延迟函数，遵循LIFO顺序。defer在运行过程遵循下面三条官方规则：

- defer函数的传入参数在定义时就已经明确
    
    ```go
    func main() {
    	i := 1
    	defer fmt.Println(i) // 只会打印出来1
    	i++
    	return
    }
    ```
    
- defer函数是按照后进先出的顺序执行
    
    ```go
    func main() {
    	for i := 1; i <= 5; i++ {
    		defer fmt.Print(i) // 依次输出54321
    	}
    }
    ```
    
- defer函数可以读取和修改函数的命名返回值
    
    ```go
    func main() {
    	fmt.Println(test()) // 输出101
    }
    
    func test() (i int) {
    	defer func() {
    		i++
    	}()
    	return 100
    }
    ```
    

### 原理

![https://static.cyub.vip/images/202105/defer_profile.png](https://static.cyub.vip/images/202105/defer_profile.png)

**简单描述**：

- 底层结构_defer结构体，多个defer函数构成_defer链表，后面的defer函数会插入链表头部，最后该链表挂载到G上面，执行时候从链表头部依次执行
- 为了减少创建_defer结构体的内存分配，Go采用了两层defer缓冲池，分别为per-P级别，这个是无锁的，goroutine有限从当前P中取。剩下一个是全局的defer缓存。

**详细描述**：

defer语法对应的底层数据结构是_defer结构体，多个defer函数会构建成一个_defer链表，后面加入的defer函数会插入链表的头部，该链表链表头部会链接到G上。当函数执行完成返回的时候，会从_defer链表头部开始依次执行defer函数。这也就是defer函数执行时会LIFO的原因。

创建_defer结构体是需要进行内存分配的，为了减少分配_defer结构体时资源消耗，Go底层使用了**两级defer缓冲池（defer pool）**，用来缓存上次使用完的_defer结构体，这样下次可以直接使用，不必再重新分配内存了。defer缓冲池一共有两级：per-P级defer缓冲池和全局defer缓冲池。当创建_defer结构体时候，优先从当前M关联的P的缓冲池中取得_defer结构体，即从per-P缓冲池中获取，这个过程是无锁操作。如果per-P缓冲池中没有，则在尝试从全局defer缓冲池获取，若也没有获取到，则重新分配一个新的_defer结构体。

**测试题目：**

```go
func main() {
	for i := 1; i <= 5; i++ {
		defer fmt.Print(i) // 54321
	}
	fmt.Println(test1()) // 2
	fmt.Println(test2()) // 1
	fmt.Println(test3()) // 2
}

// 测试1
func test1() (i int) {
	i = 1
	defer func() {
		i = i + 1
	}()
	return i
}

func test2() (r int) {
	i := 1
	defer func() {
		i = i + 1
	}()
	return i
}

func test3() (r int) {
	defer func(r int) {
		r = r + 2
	}(r)
	return 2
}
```

### 适用场景

- 用户资源的释放操作
- 修改命名返回值
- 和recover关键字一起用于panic捕获

## select可以用于做什么?

通道选择器，常用语gorotine的退出。golang 的 select 就是监听 IO 操作，当 IO 操作发生时，触发相应的动作，每个case语句里必须是一个IO操作，确切的说，应该是一个面向channel的IO操作。

1. 监听exit通道
2. or-done模式

## 映射

### map是否是并发安全的，如何实现顺序读取，如何实现并发的map?

### map中底层设计的知识点，key长度过长会不会影响map的读写效率？

![https://static.cyub.vip/images/202106/map_access.png](https://static.cyub.vip/images/202106/map_access.png)

访问映射涉及到key定位的问题，首先需要确定从哪个桶找，确定桶之后，还需要确定key-value具体存放在哪个单元里面（每个桶里面有8个坑位）。key定位详细流程如下：

1. 首先需根据hash函数计算出key的hash值
2. 该key的hash值的低`hmap.B`位的值是该key所在的桶
3. 该key的hash值的高8位，用来快速定位其在桶具体位置。一个桶中存放8个key，遍历所有key，找到等于该key的位置，此位置对应的就是值所在位置
4. 根据步骤3取到的值，计算该值的hash，再次比较，若相等则定位成功。否则重复步骤3去`bmap.overflow`中继续查找。
5. 若`bmap.overflow`链表都找个遍都没有找到，则返回nil。

**删除map中元素时候并不会释放内存**。删除时候，会清空映射中相应位置的key和value数据，并将对应的tophash置为emptyOne。此外会检查当前单元旁边单元的状态是否也是空状态，如果也是空状态，那么会将当前单元和旁边空单元状态都改成emptyRest。

Go语言中映射扩容采用渐进式扩容，避免一次性迁移数据过多造成性能问题。当对映射进行新增、更新时候会触发扩容操作然后进行扩容操作（删除操作只会进行扩容操作，不会进行触发扩容操作），每次最多迁移2个bucket。扩容方式有两种类型：

1. 等容量扩容
2. 双倍容量扩容

### sync.Map的适合场景，如果是写多读少且支持并发怎么设计？

sync.Map适用于读多写少的场景。对于写多的场景，会导致 read map 缓存失效，需要加锁，导致冲突变多；而且由于未命中 read map 次数过多，导致 dirty map 提升为 read map，这是一个 O(N) 的操作，会进一步降低性能。

- sync.Map采用空间换时间策略。其底层结构存在两个map，分别是read map和dirty map。当读取操作时候，优先从read map中读取，是不需要加锁的，若key不存在read map中时候，再从dirty
map中读取，这个过程是加锁的。当新增key操作时候，只会将新增key添加到dirty map中，此操作是加锁的，但不会影响read map的读操作。当更新key操作时候，如果key已存在read map中时候，只需无锁更新更新read map就行，同时负责加锁处理在dirty map中情况了。总之sync.Map会优先从read map中读取、更新、删除，因为对read map的读取不需要锁
- 当sync.Map读取key操作时候，若从read map中一直未读到，若dirty map中存在read map中不存在的keys时，则会把dirty map升级为read map，这个过程是加锁的。这样下次读取时候只需要考虑从read map读取，且读取过程是无锁的

### 为什么不使用sync.Mutex+map实现并发的map呢？

这个问题可以换个问法就是sync.Map相比sync.Mutex+map实现并发map有哪些优势？

sync.Map优势在于当key存在read map时候，如果进行Store操作，可以使用原子性操作更新，而sync.Mutex+map形式每次写操作都要加锁，这个成本更高。

另外并发读写两个不同的key时候，写操作需要加锁，而读操作是不需要加锁的。

## 通道

### channel有哪几种类型？有哪些特点？底层数据是怎么样的？是否是并发安全的，以及怎么做到并发安全的？

channel收发遵循FIFO原则，其底层是hchan结构指针，创建通道使用make关键字。对于有缓存的通道，其底层是固定大小的循环队列。由于对通道读取、写入时候会加锁，所以是并发安全的。当channel因为缓冲区不足而阻塞队列时候，则使用双向链表存储。Go语言中，不要通过共享内存来通信，而要通过通信实现内存共享。Go的CSP(Communicating Sequential Process)并发模型，中文可以叫做通信顺序进程，是通过 goroutine 和 channel 来实现的。

**通道类型有：**

- 有缓存通道/无缓冲通道
- 读写通道/只读通道/只写通道

**特点有：**

- 读写nil通道，永远阻塞。关闭nil通道会panic
- 读一个已关闭的通道，如果缓存区为空时候，则返回一个零值。可以使用for-range或者逗号ok
- 写一个已关闭的通道，会panic

### 内置的cap函数可以用于哪些内容？

- array
- slice
- channel

## Go如何避免内存的对象频繁分配和回收的问题？

可以考虑使用对象缓存池sync.Pool

## Go如何进行并发竞态检测，如何避免竞态问题？

Go支持go run/test/build 使用-race选项进行竞态检查。可以使用锁、信号量等同步手段保护临界区，或者原子操作等手段避免竞态问题。

## 如何实现循环队列？

channel或者atomic实现。

## 锁

### 锁种类

- 写锁-sync.Mutex，属于排他锁（或互斥锁）
- 读写锁-sync.RWMutex，属于共享锁

这两种锁的对象单元都是goroutine，底层用到类似信号机制。在runtime时也有mutex锁，底层使用futex系统调用，锁的对象是线程M，它还会阻止相关联的 G 和 P 被重新调度。

所有锁使用时候需要指针传递，也就是nocopy机制。此外Go内置的锁也不是可重入的。


### sync.Mutex的工作模式

Mutex 一共有下面几种状态：

- mutexLocked — 表示互斥锁的锁定状态；
- mutexWoken — 表示从正常模式被从唤醒；
- mutexStarving — 当前的互斥锁进入饥饿状态；
- waitersCount — 当前互斥锁上等待的 Goroutine 个数；

正常模式和饥饿模式：

对于两种模式，正常模式下的性能是最好的，goroutine 可以连续多次获取锁，饥饿模式解决了取锁公平的问题，但是性能会下降，这其实是性能和公平的一个平衡模式。

- 正常模式（非公平锁）
    
    正常模式下，所有等待锁的 goroutine 按照 FIFO（先进先出）顺序等待。唤醒的 goroutine 不会直接拥有锁，而是会和新请求 goroutine 竞争锁。新请求的goroutine 更容易抢占：因为它正在 CPU 上执行，所以刚刚唤醒的 goroutine有很大可能在锁竞争中失败。在这种情况下，这个被唤醒的 goroutine 会加入到等待队列的前面。
    
- 饥饿模式（公平锁）
    
    为了解决了等待 goroutine 队列的长尾问题。饥饿模式下，直接由 unlock 把锁交给等待队列中排在第一位的 goroutine (队头)，同时，饥饿模式下，新进来的 goroutine 不会参与抢锁也不会进入自旋状态，会直接进入等待队列的尾部。这样很好的解决了老的 goroutine 一直抢不到锁的场景。
    

饥饿模式的触发条件：当一个 goroutine 等待锁时间超过 1 毫秒时，或者当前队列只剩下一个 goroutine 的时候，Mutex 切换到饥饿模式。

Mutex运行自旋的条件有：

- 锁已被占用，并且锁不处于饥饿模式。
- 积累的自旋次数小于最大自旋次数（active_spin=4）。
- CPU 核数大于 1。有空闲的 P。
- 当前 Goroutine 所挂载的 P 下，本地待运行队列为空。

### RWMutex实现原理？以及在使用过程中需要注意事项？

RWMutex是读写锁，用于解决读者-写者问题，并且是写者优先的锁。如果有写者提出申请资源，在申请之前已经开始读取操作的可以继续执行读取，但是如果再有读者申请读取操作，则不能够读取，只有在所有的写者写完之后才可以读取。写者优先解决了读者优先造成写饥饿的问题

```go
type RWMutex struct {
	w           Mutex  // 互斥锁
	writerSem   uint32 // writers信号量
	readerSem   uint32 // readers信号量
	readerCount int32  // reader数量
	readerWait  int32  // writer申请锁时候，已经申请到锁的reader的数量
}
```

对于读者优先（readers-preference）的读写锁，只需要一个**readerCount**记录所有读者，就可以轻易实现。**Go中的RWMutex实现的是写者优先（writers-preference）的读写锁**，那就需要用到**readerWait**来记录写者申请锁时候，已经获取到锁的读者数量。

这样当后续有其他读者继续申请锁时候，可以读取readerWait是否大于0，大于0则说明有写者已经申请锁了，按照写者优先（writers-preference）原则，该读者需要排到写者之后，但是我们还需要记录这些排在写者后面读者的数量呀，毕竟写着将来释放锁的时候，还得一个个唤醒这些读者。这种情况下既要读取readerWait，又要更新排队的读者数量readerCount，这是两个操作，无法原子化。RWMutex在实现时候，通过将readerCount转换成负数，一方面表明有写者申请了锁，另一方面readerCount还可以继续记录排队的读者数量，解决刚描述的无法原子化的问题，真是巧妙！

错误的使用场景：

- RLock/RUnlock、Lock/Unlock未成对出现
- 复制sync.RWMutex作为函数值传递
- 不可重入导致死锁

## sync.WaitGroup用法以及实现原理？

sync.WaitGroup用于等待一组协程完成。

sync.WaitGroup维护了2个计数器，一个是请求计数器，每次执行Add时候，该计数器会加1，另外一个是等待计数器，每次执行Wait时候，该计数器会加1。当执行Done时候，会将请求计数器减一，当请求计数器为0时候，会唤醒等待的等待者。

需要注意的时候Add()和Wait() 不能并发调用。

## sync.Once用法

sync.Once用来执行且执行一次动作，常常用于单例对象初始化场景。

## 什么是CAS?

CAS全称为Compare And Swap，中文翻译为比较交换，是一条原子指令，对应cmpxchg指令，其原理是先比较两个值是否相等，然后原子地更新某个位置的值。基于CAS我们可以实现一个自旋锁，无锁堆栈。基于CAS实现的无锁数据结构中，需要注意[ABA问题](https://github.com/cyub/code-examples/tree/master/go/concurrent-programming#lock-free-stack)。

## sync.Pool的用法以及实现原理？

频繁地分配，回收内存会给GC带来一定负担，严重时候，会引起CPU的毛刺现象，而通过sync.Pool可以将暂时不用的对象缓存起来，等下次需要时候直接使用，不用再次经过内存分配，复用对象的内存，减轻GC的压力，提升系统的性能。

sync.Pool提供了临时对象缓存池，存在池子的对象可能在任何时刻被自动移除，我们对此不能做任何预期。sync.Pool可以并发使用，它通过复用对象来减少对象内存分配和GC的压力。当负载大的时候，临时对象缓存池会扩大，缓存池中的对象会在每2个GC循环中清除。

sync.Pool拥有两个对象存储容器：local pool和victim cache。local pool与victim cache相似，相当于primary cache。当获取对象时，优先从local pool中查找，若未找到则再从victim cache中查找，若也未获取到，则调用New方法创建一个对象返回。当对象放回sync.Pool时候，会放在local pool中。当GC开始时候，首先将victim cache中所有对象清除，然后将local pool容器中所有对象都会移动到victim cache中，所以说缓存池中的对象会在每2个GC循环中清除。

若G关联的per-P级poolLocal的双端队列中没有取出来对象，那么就尝试从其他P关联的poolLocal中偷一个。若从其他P关联的poolLocal没有偷到一个，那么就尝试从victim cache中取。

若步骤4中也没没有取到缓存对象，那么只能调用pool.New方法新创建一个对象。

## 如何避免死锁？

死锁检测，活锁，银行家算法

## Go中内存逃逸是怎么回事？怎么检测内存逃逸？有哪些内存逃逸的场景？

Go 语言中决定一个变量分配栈上还是堆是Go编译器决定的，如果变量分配到堆上那么我们就说着变量发生了逃逸。我们设置-gcflags=”-m”来检测内存逃逸。内存逃逸的场景一般有：

1. 函数返回局部变量的指针(一般会，并不绝对）
2. 闭包中捕获变量会发生更改时候
3. 切片变量过大时候

## 实现一个并发安全的set？

```go
type inter interface{}
type Set struct {
m map[inter]bool
sync.RWMutex
}

func New() *Set {
return &Set{
m: map[inter]bool{},
}
}
func (s *Set) Add(item inter) {
s.Lock()
defer s.Unlock()
s.m[item] = true
}
```

## 主协程如何等其余协程完再操作?

sync.Waitgroup

## struct结构能不能比较？

这个设计到Go语言中[可比较性规则](https://go.dev/ref/spec#Comparison_operators)。

- 切片、映射、函数不可比较，但都可以和nil比较
- 当通道元素类型一样时候，可以比较，即使缓冲大小不一样
- 指针类型只有指向的变量的类型一样时候，才能够比较。但都可以和nil比较
- 接口类型都可以相互比较，只有底层类型和底层值一样时候，才会相等
- 数组类型，只有元素类型和数组大小一样时候，才可以进行比较
- 如果结构体中所有字段都是可以比较的，那么该结构体就是可以比较的。注意：字段比较时候需要按照相同顺序依次比较。
    
    ```go
    var t1 = struct {
    		A string
    		B string
    	}{}
    	var t2 = struct {
    		B string
    		A string
    	}{}
    	var t3 = struct {
    		A string
    		B string
    		c int // unexport
    	}{}
    	fmt.Println(t1 == t2) // 不能比较
    	fmt.Println(t1 == t3) // 不能比较
    
    // invalid operation: t1 == t2 (mismatched types struct{A string; B string} and struct{B string; A string})
    // invalid operation: t1 == t3 (mismatched types struct{A string; B string} and struct{A string; B string; c int})
    ```
    

## Go里面的值传递和指针传递？

函数参数传递方式一般有两种:值传递和引用传递。其中值传递中可以传递指针，这种情况可以称为指针传递。指针传递不等于引用传递，尽管两者都可以改变原始值。

Go语言中所有都是值传递。切片，通道，映射属于指针传递，因为它们底层是一个指针(或者是胖指针)

## context包的用途？

context.Context的作用就是在不同的goroutine之间同步请求特定数据、取消信号以及处理请求的截止日期。

## 字符串有哪几种拼接方式？性能怎么样？

字符串底层结构本质是一个fat-pointer:

```go
type StringHeader struct {
	Data uintptr
	Len  int
}
```

- +号拼接，会产生临时字符串，性能一般
- fmt.Printf 进行拼接，由于字符串会变成interface{}，产生内存逃逸，性能较差
- strings.Join 用于字符串切片拼接，底层用到了strings.Builder，性能比较高
- strings.Builder 性能高，底层用到内存缓冲，内存缓冲结构是字节切片，输出字符串时候使用了zero-copy技术直接把字节切片转换成字符串。缺点就是每次reset时候都会将内存缓冲至为nil，不能够复用
- bytes.Buffer 性能高，跟strings.Builder类似，但reset时候不会将内存缓冲至为nil，能够达到复用的目的

## Go 数组与C语言数组有什么区别？

Go语言中数组是一片连续的内存，是**一个值类型**，作为参数传递时候会把COPY旧数组形成一个新数组作为函数的参数。这也意味着在函数内改变数组值，不会影响原数组。

## slice的len,cap知识，底层共享等问题，以及扩容策略？

### 切片概念

Go中切片是动态数组的概念，底层结构类似字符串，但其指针指向的内存是可以更改的，并且它还有一个容量字段。

```go
type slice struct {
	array unsafe.Pointer // 底层数据数组的指针
	len   int // 切片长度
	cap   int // 切片容量
}
```

**切片作为参数传递时候也是值传递，但它传递的是指针，属于指针传递，所以它拥有引用传递的特性**。

为了避免切片指针传递带来的副作用，可以使用内置copy函数复制一个全新的切片再传递。

### 创建方式

切片的创建方式有：

1. 使用make关键字创建，形式make([]T, length, capacity)，capacity可以省略，默认等于length
2. 基于数组，指向数组的指针，切片构建一个切片
    
    reslice操作语法可以是[]T[low : high]，也可以是[]T[low : high : 
    max]。其中low,high,max都可以省略，low默认值是0，high默认值cap([]T)，max默认值cap([]T)。low,hight,max取值范围是`0 <= low <= high <= max <= cap([]T)`
    ，其中high-low是新切片的长度，max-low是新切片的容量。
    
    对于[]T[low : high]，其包含的元素是[]T中下标low开始，到high结束（不含high所在位置的，相当于左闭右开[low, high)）的元素，元素个数是high - low个，容量是cap([]T) - low。
    
3. 使用字面量创建

### reslice

基于切片或者数组reslice一个新切片时候，需要注意新切片的容量：

```go
func main() {
	slice1 := make([]int, 0)
	slice2 := make([]int, 1, 3)
	slice3 := []int{}
	slice4 := []int{1: 2, 3}
	arr := []int{1, 2, 3}
	slice5 := arr[1:2]
	slice6 := arr[1:2:2]
	slice7 := arr[1:]
	slice8 := arr[:1]
	slice9 := arr[3:]
	slice10 := slice2[1:2]
	fmt.Printf("%s = %v,\t len = %d, cap = %d\n", "slice1", slice1, len(slice1), cap(slice1))
	fmt.Printf("%s = %v,\t len = %d, cap = %d\n", "slice2", slice2, len(slice2), cap(slice2))
	fmt.Printf("%s = %v,\t len = %d, cap = %d\n", "slice3", slice3, len(slice3), cap(slice3))
	fmt.Printf("%s = %v,\t len = %d, cap = %d\n", "slice4", slice4, len(slice4), cap(slice4))
	fmt.Printf("%s = %v,\t len = %d, cap = %d\n", "slice5", slice5, len(slice5), cap(slice5))
	fmt.Printf("%s = %v,\t len = %d, cap = %d\n", "slice6", slice6, len(slice6), cap(slice6))
	fmt.Printf("%s = %v,\t len = %d, cap = %d\n", "slice7", slice7, len(slice7), cap(slice7))
	fmt.Printf("%s = %v,\t len = %d, cap = %d\n", "slice8", slice8, len(slice8), cap(slice8))
	fmt.Printf("%s = %v,\t len = %d, cap = %d\n", "slice9", slice9, len(slice9), cap(slice9))
	fmt.Printf("%s = %v,\t len = %d, cap = %d\n", "slice10", slice10, len(slice10), cap(slice10))
}
```

上面输出：

```go
slice1 = [],	 len = 0, cap = 0
slice2 = [0],	 len = 1, cap = 3
slice3 = [],	 len = 0, cap = 0
slice4 = [0 2 3],	 len = 3, cap = 3
slice5 = [2],	 len = 1, cap = 2
slice6 = [2],	 len = 1, cap = 1
slice7 = [2 3],	 len = 2, cap = 2
slice8 = [1],	 len = 1, cap = 3
slice9 = [],	 len = 0, cap = 0
slice10 = [0],	 len = 1, cap = 2
```

### 扩容策略

切片的扩容策略是：

1. 首先判断，如果新申请容量大于 2 倍的旧容量，最终容量就是新申请的容量
2. 否则判断，如果旧切片的长度小于 1024，则最终容量就是旧容量的两倍
3. 否则判断，如果旧切片长度大于等于 1024，则最终容量从旧容量开始循环增加原来的 1/4, 直到最终容量大于等于新申请的容量。由于考虑内存对齐，最终实际扩容大小可能会大于1/4

### 常见用法

```go
//copy
b = make([]T, len(a))
copy(b, a)

//cut
a = append(a[:i], a[j:]...)

//delte
a = append(a[:i], a[i+1:]...)
// or
a = a[:i+copy(a[i:], a[i+1:])]

// insert
s = append(s, 0)
copy(s[i+1:], s[i:])
s[i] = x

//pop
x, a = a[len(a)-1], a[:len(a)-1]

//push
a = append(a, x)

//shift
x, a := a[0], a[1:]

//unshift
a = append([]T{x}, a...)

//反转
for left, right := 0, len(a)-1; left < right; left, right = left+1, right-1 {
	a[left], a[right] = a[right], a[left]
}
```

### 字符串与切片内存zero-copy转换的实现？

```go
func bytes2string(b []byte) string{
    return *(*string)(unsafe.Pointer(&b))
}

func StringToBytes(s string) (b []byte) {
	sh := *(*reflect.StringHeader)(unsafe.Pointer(&s))
	bh := (*reflect.SliceHeader)(unsafe.Pointer(&b))
	bh.Data, bh.Len, bh.Cap = sh.Data, sh.Len, sh.Len
	return b
}

func StringToBytes(s string) []byte {
	return *(*[]byte)(unsafe.Pointer(
		&struct {
			string
			Cap int
		}{s, len(s)},
	))
}
```

## make与new的区别？

- Go 中make关键字用来创建切片，通道，映射，返回是引用类型本身，new返回的是指向类型的指针。new返回的类型指针指向的值为该类型的零值。由于new不会初始化内存，只是清零内存，所以new切片，通道，映射之后，并不能直接使用：

```go
type User struct {
	name string
}

func main() {
	puser := new(User)
	puser.name = "hello"
	fmt.Println(*puser)
	
	pint := new(int)
	*pint = 123
	fmt.Println(*pint) // 123

	parr := new([5]int)
	(*parr)[1] = 123
	fmt.Println(parr) // &[0 123 0 0 0]

	pslice := new([]int)
	(*pslice)[0] = 8 // /panic: runtime error: index out of range
	
	pmap := new(map[string]string)
	(*pmap)["a"] = "a" // panic: assignment to entry in nil map
	
	pchan := new(chan string)
	pchan <- "good" //invalid operation: cv <- "good" (send to non-chan type *chan string)
}
```

## nil 的概念

对应于引用类型的变量，它的零值是nil。零值指的是当声明变量且未显示初始化时，Go语言会自动给变量赋予一个默认初始值。

- 对nil通道读写操作会永远阻塞
- 对nil切片，可以append操作，读写会panic
- 对nil映射读取和删除ok，写入会panic
- nil可以作为接收者，只不是值为nil而已

### Go语言中指针与非安全指针类型概念？

**对于任意类型T，其对应的的指针类型是*T，类型T称为指针类型*T的基类型。**
一个指针类型*T变量B存储的是类型T变量A的内存地址，我们称该指针类型变量B**引用(reference)了A。从指针类型变量B获取（或者称为访问）A变量的值的过程，叫解引用**
。解引用是通过解引用操作符*操作的。

Go中unsafe.Pointer是非安全类型指针，它作为桥梁，用于任意类型指针与uintptr互换。

```go
type MyInt int

func main() {
	a := 100
	fmt.Printf("%p\n", &a)
	fmt.Printf("%x\n", uintptr(unsafe.Pointer(&a)))
}
```

## 三色标记法原理

Golang中采用 **三色标记清除算法（tricolor mark-and-sweep algorithm）** 进行GC。由于支持写屏障（write barrier)了，GC过程和程序可以并发运行。

三色标记清除算核心原则就是根据每个对象的颜色，分到不同的颜色集合中，对象的颜色是在标记阶段完成的。三色是黑白灰三种颜色，每种颜色的集合都有特别的含义：

- 黑色集合
    
    该集合下的对象没有引用任何白色对象（即该对象没有指针指向白色对象）
    
- 白色集合
    
    扫描标记结束之后，白色集合里面的对象就是要进行垃圾回收的，该对象允许有指针指向黑色对象。
    
- 灰色集合
    
    可能有指针指向白色对象。它是一个中间状态，只有该集合下不在存在任何对象时候，才能进行最终的清除操作。
    

### GC流程

当垃圾回收开始，全部对象标记为白色。

- 垃圾回收器会遍历所有根对象并把它们标记为灰色，放入灰色集合里面。**根对象**就是程序能直接访问到的对象，包括全局变量以及栈、寄存器上的里面的变量。
- 遍历灰色集合中的对象，把灰色对象引用的白色集合的对象放入到灰色集合中，同时把遍历过的灰色集合中的对象放到黑色的集合中
- 重复步骤2，直到灰色集合没有对象
- 步骤3结束之后，白色集合中的对象就是不可达对象，也就是垃圾，可以进行回收

为了支持能够并发进行垃圾回收，Golang在垃圾回收过程中采用写屏障，每次堆中的指针被修改时候写屏障都会执行，写屏障会将该指针指向的对象标记为灰色，然后放入灰色集合（因为才对象现在是可触达的了），然后继续扫描该对象。

举个例子说明写屏障的重要性：

假定标记完成的瞬间，A对象是黑色，B是白色，然后A的对象指针字段f由空指针改成指向B，若没有写屏障的话，清除阶段B就会被清除掉，那边A的f字段就变成了悬浮指针，这是有问题的。若存在写屏障那么f字段改变的时候，f指向的B就会放入到灰色集合中，然后继续扫描，B最终也会变成黑色的，那么清除阶段它也就不会被清除了。

除了三色标记法外还有标记清除法，标记清除法的最大弊端就是在整个GC期间需要STW。

虽然 golang 是先实现的插入写屏障，后实现的混合写屏障，但是从理解上，应该是先理解删除写屏障，后理解混合写屏障会更容易理解；

插入写屏障没有完全保证完整的强三色不变式(栈对象的影响)，所以赋值器是灰色赋值器，最后必须 STW 重新扫描栈；

混合写屏障消除了所有的 STW，实现的是黑色赋值器，不用 STW 扫描栈；

混合写屏障的精度和删除写屏障的一致，比以前插入写屏障要低；

混合写屏障扫描栈式逐个暂停，逐个扫描的，对于单个 goroutine 来说，栈要么全灰，要么全黑；

暂停机制通过复用 goroutine 抢占调度机制来实现；

[**详细总结： Golang GC、三色标记、混合写屏障机制**](https://www.cnblogs.com/cxy2020/p/16321884.html)

[**golang GC工作过程**](https://blog.csdn.net/weixin_41479678/article/details/124845607)

[写屏障是什么_Golang 混合写屏障原理深入剖析，这篇文章给你梳理的明明白白！](https://blog.csdn.net/weixin_39676242/article/details/111581951)

[**两万字长文带你深入Go语言GC源码**](https://zhuanlan.zhihu.com/p/359582221)

强三色不变式规则：**不允许黑色对象引用白色对象**

破坏了条件一： 白色对象被黑色对象引用

解释：如果一个黑色对象不直接引用白色对象，那么就不会出现白色对象扫描不到，从而被当做垃圾回收掉的尴尬。

弱三色不变式规则：**黑色对象可以引用白色对象，但是白色对象的上游必须存在灰色对象**

破坏了条件二：灰色对象与白色对象之间的可达关系遭到破坏

解释： 如果一个白色对象的上游有灰色对象，则这个白色对象一定可以扫描到，从而不被回收

混合写屏障的具体核心规则如下：

1. GC开始后先将栈上的**可达对象**全部扫描并标记为黑色(之后不再进行第二次重复扫描，无需STW)

2. GC期间，任何在栈上创建的新对象，均为黑色。

3. (堆上)被删除的对象标记为灰色。

4.（堆上)被添加的对象标记为灰色。

场景一：栈对象A的下游引用一个堆对象C，接着该堆对象C被引用它的堆对象B删除。

- 栈A引用（即指向)对象C，由于没有写屏障，C对象不会做任何更改
- 堆对象B删除掉引用C，由于堆上删除写屏障的存在，那么C如果是灰色和白色的，那C就会标记成灰色

### GC触发时机

1. 主动触发
    
    调用runtime.GC
    
2. 内存分配至时候被动触发
    
    由mallocgc()发起的，触发条件是堆大小达到或者超过了临界值。使用步调（Pacing）算法，其核心思想是控制内存增长的比例。如 Go 的 GC是一种比例 GC, 下一次 GC 结束时的堆大小和上一次 GC 存活堆大小成比例.
    
3. 基于时间的周期性触发
    
    由系统监控sysmon发起，该触发条件由 runtime.forcegcperiod 变量控制，默认为 2 分钟。当超过两分钟没有产生任何 GC 时，强制触发 GC。
    

### 辅助GC的目的是？

辅助GC是mallocgc()函数的一部分，mallocgc()函数式堆分配的关键函数，runtime中new系列函数和make系列函数都依赖它。mallocgc()只有在GC标记阶段才执行辅助GC，并且每个goroutine都已辅助GC的字节额度，超过就不行辅助GC了。辅助GC机制能够优有限避免程序过快地分配内存，从而造成GC工作线程(gc worker)来不及标记的问题。

### GC如何调优

通过 go tool pprof 和 go tool trace 等工具

- 控制内存分配的速度，限制 Goroutine 的数量，从而提高赋值器对 CPU

的利用率。

- 减少并复用内存，例如使用 sync.Pool 来复用需要频繁创建临时对象，例

如提前分配足够的内存来降低多余的拷贝。

- 需要时，增大 GOGC 的值，降低 GC 的运行频率。
- 对于预分配的大量内存，则可能需要将 debug.SetGCPercent() 设置为低得多的百分比才能获得正常的 GC 频率。

## reflect反射三定律？

1. Reflection goes from interface value to reflection object
    
    反射可以将“接口类型变量”转换为“反射类型对象”
    
2. Reflection goes from reflection object to interface value
    
    反射可以将“反射类型对象”转换为“接口类型变量”
    
3. To modify a reflection object, the value must be settable
    
    如果要修改“反射类型对象”，其值必须是“可写的”（settable）
    

## Go pprof

pprof支持以下几种分析器：

- **Go 分析器**
    
    CPU 分析器通过操作系统监控应用程序的CPU 使用情况，并且每隔10ms的CPU 片时间发送一个SIGPROF信号来捕获profile数据。操作系统还包括内核在此监控中代表应用程序消耗的时间。由于信号传输速率取决于 CPU 消耗，因此它是动态的，最高可达 N * ``100Hz，其中 N是操作系统上逻辑 CPU 内核的数量。当 SIGPROF信号到达时，Go 的信号处理程序捕获当前活动的 goroutine 的堆栈跟踪，并增加profile文件中的相应值。 cpu/nanoseconds值目前是直接从samples/count样本计数中推导出来的，所以是多余的，但是使用方便。
    
- **内存分析器**
- **阻塞分析器**
    
    Go 中的阻塞分析器衡量你的 goroutine 在等待通道以及[sync包](https://pkg.go.dev/sync)提供的互斥操作时在 Off-CPU 外花费的时间。以下 Go 操作会被阻塞分析器捕获分析：
    
    - select
    - chan send
    - chan receive
    - semacquire ( [`Mutex.Lock`](https://golang.org/pkg/sync/#Mutex.Lock), [`RWMutex.RLock`](https://golang.org/pkg/sync/#RWMutex.RLock) , [`RWMutex.Lock`](https://golang.org/pkg/sync/#RWMutex.Lock), [`WaitGroup.Wait`](https://golang.org/pkg/sync/#WaitGroup.Wait))
    - notifyListWait ( [`Cond.Wait`](https://golang.org/pkg/sync/#Cond.Wait))
    
    阻塞 profile文件不包括等待 I/O、睡眠、GC 和各种其他等待状态的时间。此外，阻塞事件在完成之前不会被记录，因此阻塞profile文件不能用于调试 Go 程序当前挂起的原因。后者可以使用 Goroutine 分析器确定。
    

## Go内存分配原理？

Golang内存分配管理策略是**按照不同大小的对象和不同的内存层级来分配管理内存**。通过这种多层级分配策略，形成无锁化或者降低锁的粒度，以及尽量减少内存碎片，来提高内存分配效率。

Golang中内存分配管理的对象按照大小可以分为：

| 类别 | 大小 |
| --- | --- |
| 微对象 tiny object | (0, 16B) |
| 小对象 small object | [16B, 32KB] |
| 大对象 large object | (32KB, +∞) |

Golang中内存管理的层级从最下到最上可以分为：mspan -> mcache -> mcentral -> mheap -> heapArena。golang中对象的内存分配流程如下：

1. 小于16个字节的对象使用`mcache`的微对象分配器进行分配内存
2. 大小在16个字节到32k字节之间的对象，首先计算出需要使用的`span`大小规格，然后使用`mcache`中相同大小规格的`mspan`分配
3. 如果对应的大小规格在`mcache`中没有可用的`mspan`，则向`mcentral`申请
4. 如果`mcentral`中没有可用的`mspan`，则向`mheap`申请，并根据BestFit算法找到最合适的`mspan`。如果申请到的`mspan`超出申请大小，将会根据需求进行切分，以返回用户所需的页数，剩余的页构成一个新的`mspan`放回`mheap`的空闲列表
5. 如果`mheap`中没有可用`span`，则向操作系统申请一系列新的页（最小 1MB）
6. 对于大于32K的大对象直接从`mheap`分配

mspan:

mspan是一个双向链表结构。mspan是golang中内存分配管理的基本单位。span大小一共有67个规格。规格列表如下， 其中class = 0 是特殊的span，用于大于32kb对象分配，是直接从mheap上分配的。

mcache:

mcache持有一系列不同大小的mspan。mcache属于per-P cache，由于M运行G时候，必须绑定一个P，这样当G中申请从mcache分配对象内存时候，无需加锁处理。

mcetral:

当mcache的中没有可用的span时候，会向mcentral申请。

### Go错误处理

为了不丢失函数调用的错误链，使用`fmt.Errorf`时搭配使用特殊的格式化动词`%w`，可以实现基于已有的错误再包装得到一个新的错误。

```go
fmt.Errorf("查询数据库失败，err:%w", err)
```

对于这种二次包装的错误，`errors`包中提供了以下三个方法。

```go
func Unwrap(err error) error                 // 获得err包含下一层错误
func Is(err, target error) bool              // 判断err是否包含target
func As(err error, target interface{}) bool  // 判断err是否为target类型
```

[一篇文章带你轻松搞懂Golang的error处理_Golang_脚本之家](https://www.jb51.net/article/254917.htm)

## 资料

[【Golang开发面经】蔚来（两轮技术面）](https://zhuanlan.zhihu.com/p/574580955)