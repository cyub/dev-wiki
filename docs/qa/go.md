
# Go

## 互斥锁(Mutex)有哪两种模式？

Mutex 可能处于两种操作模式下：正常模式和饥饿模式。

正常模式下，waiter 都是进入先入先出队列，被唤醒的 waiter 并不会直接持有锁，而是要和新来的 goroutine 进行竞争。新来的 goroutine 有先天的优势，它们正在 CPU 中运行，可能它们的数量还不少，所以，在高并发情况下，被唤醒的 waiter 可能比较悲剧地获取不到锁，
这时，它会被插入到队列的前面。如果 waiter 获取不到锁的时间超过阈值 1 毫秒，

那么，这个 Mutex 就进入到了饥饿模式。在饥饿模式下，Mutex 的拥有者将直接把锁交给队列最前面的 waiter。新来的 goroutine 不会尝试获取锁，即使看起来锁没有被持有，它也不会去抢，也不会 spin，它会乖乖地加入到等待队列的尾部。

如果拥有 Mutex 的 waiter 发现下面两种情况的其中之一，它就会把这个 Mutex 转换成正常模式:

- 此 waiter 已经是队列中的最后一个 waiter 了，没有其它的等待锁的 goroutine 了；

- 此 waiter 的等待时间小于 1 毫秒。

饥饿模式是对公平性和性能的一种平衡，它避免了某些 goroutine ⻓时间的等待锁。在饥饿模式下，优先对待的是那些一直在等待的 waiter

## Go垃圾清理的三色标记法?

![](https://static.cyub.vip/images/202107/tricolor_sweep.gif)

三色标记法是传统 Mark-Sweep 的一个改进，它是一个并发的 GC 算法。
原理如下，

- 首先创建三个集合：白、灰、黑。
- 将所有对象放入白色集合中。
- 然后从根节点开始遍历所有对象（注意这里并不递归遍历），把遍历到的对象从白色集合放入灰色集合。
- 之后遍历灰色集合，将灰色对象引用的对象从白色集合放入灰色集合，之后将此灰色对象放入黑色集合
重复 4 直到灰色中无任何对象
- 通过write-barrier检测对象有变化，重复以上操作
- 收集所有白色对象（垃圾）

## Golang什么时候会触发GC?

- 阈值：默认内存扩大一倍，启动gc
- 定期：默认2min触发一次gc，src/runtime/proc.go:forcegcperiod
- 手动：runtime.gc()

## Golang进行GC时候会不会STW？

![](https://static.cyub.vip/images/202107/golang_gc_stw.jpeg)

Golang使用的是三色标记法方案，并且支持并行GC，即用户代码何以和GC代码同时运行。具体来讲，Golang GC分为几个阶段:Mark阶段该阶段又分为两个部分：

- Mark Prepare：初始化GC任务，包括开启写屏障(write barrier)和辅助GC(mutator assist)，统计root对象的任务数量等，这个过程需要STW。
- GC Drains: 扫描所有root对象，包括全局指针和goroutine(G)栈上的指针（扫描对应G栈时需停止该G)，将其加入标记队列(灰色队列)，并循环处理灰色队列的对象，直到灰色队列为空。该过程后台并行执行。
- Mark Termination阶段：该阶段主要是完成标记工作，重新扫描(re-scan)全局指针和栈。因为Mark和用户程序是并行的，所以在Mark过程中可能会有新的对象分配和指针赋值，这个时候就需要通过写屏障（write barrier）记录下来，re-scan 再检查一下，这个过程也是会STW的。Sweep: 按照标记结果回收所有的白色对象，该过程后台并行执行。
- Sweep Termination: 对未清扫的span进行清扫, 只有上一轮的GC的清扫工作完成才可以开始新一轮的GC。

总结一下，Golang的GC过程有两次STW:第一次STW会准备根对象的扫描, 启动写屏障(Write Barrier)和辅助GC(mutator assist).第二次STW会重新扫描部分根对象, 禁用写屏障(Write Barrier)和辅助GC(mutator assist).

## Go内存分配策略是什么样子的？

Golang内存分配管理策略是根据对象大小区分和不同的内存分配层级来分配管理内存。Golang中内存分配管理的对象按照大小可以分为：

类别 | 大小
--- | ---
微对象 tiny object | (0, 16B)
小对象 small object | [16B, 32KB]
大对象 large object | (32KB, +∞)

Golang中内存管理的层级从最下到最上可以分为：mspan -> mcache -> mcentral -> mheap -> heapArena。golang中对象的内存分配流程如下：
- 小于16个字节的对象使用mcache的微对象分配器进行分配内存
- 大小在16个字节到32k字节之间的对象，首先计算出需要使用的span大小规格，然后使用mcache中相同大小规格的mspan分配
- 如果对应的大小规格在mcache中没有可用的mspan，则向mcentral申请
- 如果mcentral中没有可用的mspan，则向mheap申请，并根据BestFit算法找到最合适的mspan。如果申请到的mspan超出申请大小，将会根据需求进行切分，以返回用户所需的页数，剩余的页构成一个新的mspan放回mheap的空闲列表
- 如果mheap中没有可用span，则向操作系统申请一系列新的页（最小 1MB）
- 对于大于32K的大对象直接从mheap分配

## new和make的区别？

传递给 new 函数的是一个类型，不是一个值。返回值是指向这个新分配的零值的指针。

make 的作用是为创建slice，map 或 chan。

## 内存泄露有哪些场景？

- 全局变量，比如全局切片一直被局部变量引用着

- for + select + time.Afer 进行超时处理时候：

    ```go
    for {
        select {
        ...
        case <-time.After(3 * time.Minute):
            fmt.Printf("现在是：%d，我脑子进煎鱼了！", time.Now().Unix())
        }
    }
    ```

    因为 for在循环时，就会调用都 select 语句，因此在每次进行 select 时，都会重新初始化一个全新的计时器（Timer）。



- 发送数据到通道时，通道已满

    goroutine作为生产者向 channel发送信息，但是没有消费的goroutine，或者消费的goroutine被错误的关闭了。导致channel被打满。

    ```go
    func channelNoProducter() {
        ch := make(chan int)
        go func() {
            ch <- 1
            fmt.Println(111)
        }()
    }
    ```

- 从通道接收数据时候，通道为空

    作为消费者的goroutine,等待消费channel，但是上游的生产者不存在

    ```go
    func channelNoProducer() {
        ch := make(chan int, 1)
        go func() {
            <-ch
            fmt.Println(111)
        }()
    }
    ```

    排查内存泄露的方法有：使用pprof分析内存使用情况，以及goroutine运行情况

- 向nil通道发送或读取数据时候

## 内存逃逸有哪些场景？

- 闭包造成内存逃逸
- 返回指向栈变量的指针
- 切片变量过大会造成内存逃逸

## Go内部包是怎么回事？

Go语言1.4版本后增加了 Internal packages 特征用于控制包的导入。如果项目包含多个包，可能有一些公共的函数，这些函数旨在供项目中的其他包使用，但不打算成为项目的公共API的一部分，那么请将其放在名为 internal/ 的目录中，或者放在名为 internal/ 的目录的子目录中。

**导入路径包含internal关键字的包，只允许internal的父级目录及父级目录的子包导入，其它包无法导入**

## Go性能分析手段

### pprof

- CPU Profiling

    CPU分析，按照一定的频率采集所监听的应用程序的CPU使用情况，可确定应用程序在主动消耗 CPU 周期时花费时间的位置。
- Memory Profiling

    内存分析，在应用程序堆栈分配时记录跟踪，用于监视当前和历史内存使用情况，检查内存泄漏情况。
- Block Profiling

    阻塞分析，记录goroutine阻塞等待同步的位置
- Mutex Profiling

    互斥锁分析，报告互斥锁的竞争情况

### GODEBUG

- gctrace=1

    查看gc情况

- schedtrace=X

    每 X 毫秒输出一行调度器的摘要信息到标准 err 输出中

### go test

基准测试

### go tool trace

- goroutine 创建、启动、结束
- gorouting 阻塞、恢复
- 网络阻塞
- 系统调用（syscall）
- GC 事件

## perf

`perf record`用来记录一段性能分析数据，并可以根据此生成火焰图。

