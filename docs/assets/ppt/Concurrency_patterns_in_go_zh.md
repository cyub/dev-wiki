# Go 语言中的并发模式

## 并发关乎**设计**

- **设计**程序，使其成为一组独立的进程  
- **设计**这些进程，使它们最终可以并行运行  
- **设计**代码，以确保最终结果始终一致  

## 并发的细节

- 通过识别独立任务来组织代码（和数据）  
- 无竞争条件（race conditions）  
- 无死锁（deadlocks）  
- 增加 worker 数量 = 更快的执行速度  

## 通信顺序进程（CSP）

- Tony Hoare，1978  
1. 每个进程都是为顺序执行而构建的  
2. 进程之间通过通道（channel）进行数据通信，没有共享状态！  
3. 通过增加相同类型的进程来扩展  

## 通道（Channels）

- 可以将其想象为一条水桶传递链  
- 由 3 个部分组成：发送端、缓冲区、接收端  
- 缓冲区是可选的

![](../../images/bucket_chain.png)

### 阻塞通道（Blocking Channels）

```go
unbuffered := make(chan int)

// 1) 阻塞
a := <- unbuffered

// 2) 阻塞
unbuffered <- 1

// 3) 同步
go func() { <- unbuffered }()
unbuffered <- 1


buffered := make(chan int, 1)
// 4) 仍然阻塞
a := <- buffered

// 5) 正常
buffered <- 1

// 6) 阻塞（缓冲区已满）
buffered <- 2
```

#### 阻塞破坏并发

- 记住：
    - 无死锁  
    - 增加 worker 数量 = 更快的执行速度  
- 阻塞可能导致死锁  
- 阻塞可能阻碍程序的扩展  

### 关闭通道（Closing Channels）

- `close` 发送一个特殊的 `closed` 消息  
- 接收端在某个时刻会检测到 `closed`，表示无更多数据  
- 如果关闭后仍然尝试发送数据，会导致 **panic**！

```go
c := make(chan int)
close(c)

fmt.Println(<-c) // 接收并打印
// 输出是什么？

// 0, false

// - 接收操作总是返回两个值  
// - 0 是 int 类型的零值  
// - false 表示 `没有更多数据` 或 `返回值无效`
```

### `select` 语句

- 类似于 `switch` 语句，但用于通道操作  
- case 语句的顺序**无关紧要**  
- 也可以有 `default` 分支  
- `select` 语句会选择**第一个非阻塞的 case**（无论是发送还是接收）  

#### 使通道非阻塞

```go
func TryReceive(c <-chan int) (data int, more, ok bool) {
    select {
        case data, more = <- c:
            return data, more, true
        default: // 当 c 阻塞时执行
            return 0, true, false
    }
}
```

```go
func TryReceiveWithTimeout(c <-chan int, duration time.Duration) (data int, more, ok bool) {
    select {
        case data, more = <- c:
            return data, more, true
        case <- time.After(duration): // time.After 返回一个通道
            return 0, true, false
    }
}
```

#### 设计数据流

- 通道是数据流  
- 处理多个数据流是 `select` 的真正强大之处 

![](../../images/data_flow.png)

**Fan-out（扇出）**：Fan-out 指的是从一个输入通道，将数据分发到多个 goroutine 进行并发处理。

**Funnel（汇聚）**：Funnel 方式是多个输入通道的数据合并到一个通道中，通常用于多个数据源合并处理。

**Turnout（分流）**：Turnout 代表的是数据从一个输入通道，按照特定的规则被发送到不同的通道（可能是不同的 goroutine 进行不同的处理）。

##### 扇出（Fan-out）

```go
func Fanout(In <-chan int, OutA, OutB chan int) {
    for data := range In { // 直到通道关闭
        select { // 发送到第一个非阻塞的通道
            case OutA <- data:
            case OutB <- data:
        }
    }
}
```

##### 扇入（Turnout）

```go
func Turnout(InA, InB <-chan int, OutA, OutB chan int) {
    for {
        select { // 从第一个非阻塞的通道接收
            case data, more = <- InA:
            case data, more = <- InB:
        }

        if !more {
            return
        }

        select { // 发送到第一个非阻塞的通道
            case OutA <- data:
            case OutB <- data:
        }
    }
}
```

##### 退出通道（Quit Channel）

```go
func Turnout(Quit <-chan int, InA, InB, OutA, OutB chan int) {
    for {
        select {
            case data = <- InA:
            case data = <- InB:

            case <- Quit: // 关闭通道会发送一个消息
                close(InA) // 反模式（anti-pattern）
                close(InB)

                Fanout(InA, OutA, OutB) // 处理剩余数据
                Fanout(InB, OutA, OutB)
                return
        }
    }
}
```

### 通道的局限性

- 可能会导致死锁  
- 通道传递的是数据的 **副本**，可能影响性能  
- 传递指针的通道可能会引发竞争条件  
- 如何处理 **“天然共享”** 的数据结构（如缓存、注册表）？  

## 互斥锁（Mutex）不是最佳解决方案

- **互斥锁就像厕所**  
    - 使用时间越长，等待队列越长  
- 读/写锁只能 **减少** 问题，但不能完全避免  
- 使用多个互斥锁最终会导致死锁  
- 总体而言，不是最佳方案  

### 三种代码执行模式

- **阻塞（Blocking）** = 代码可能会长时间停滞  
- **无锁（Lock-free）** = 至少有一部分程序始终在执行  
- **无等待（Wait-free）** = 所有部分的程序始终在执行  

## 原子操作（Atomic Operations）

- `sync/atomic` 包  
- `Store`、`Load`、`Add`、`Swap`、`CompareAndSwap`  
- 底层映射到 CPU 级别的线程安全指令  
- 仅适用于整数类型  
- 仅比普通操作慢 10-60 倍（比互斥锁更高效）  

### 自旋 CAS（Spinning CAS）

- 需要一个 **状态变量** 和一个 **free** 常量  
- 在循环中使用 `CAS（CompareAndSwap）`：
    - 如果状态 **不是 free**，则继续尝试  
    - 如果状态 **是 free**，则修改状态，获取所有权  

```go
type Spinlock struct {
    state *int32
}

const free = int32(0)

func (l *Spinlock) Lock() {
    for !atomic.CompareAndSwapInt32(l.state, free, 42) {
        runtime.Gosched()
    }
}

func (l *Spinlock) Unlock() {
    atomic.StoreInt32(l.state, free)
}
```

### 票据存储（Ticket Store）

- 需要：
    - **索引化数据结构**
    - **票据（ticket）**
    - **完成（done）变量**  
- 每个新票据值递增，保证唯一性  
- 票据作为索引存储数据  
- `done` 变量表示可读范围  

```go
type TicketStore struct {
    ticket *uint64
    done   *uint64
    slots  []string
}

func (ts *TicketStore) Put(s string) {
    t := atomic.AddUint64(ts.ticket, 1) - 1
    slots[t] = s
    for !atomic.CompareAndSwapUint64(ts.done, t, t+1) {
        runtime.Gosched()
    }
}

func (ts *TicketStore) GetDone() []string {
    return ts.slots[:atomic.LoadUint64(ts.done)+1]
}
```

### 调试非阻塞代码

- 我称之为 “**指令指针游戏**”（The Instruction Pointer Game）。
- 规则如下：
    - 打开 **两个窗口**（即两个 Goroutine），它们运行相同的代码。
    - 你有 **一个指令指针**，它会依次执行你的代码。
    - 你可以在 **任何一条指令** 处 **切换** 窗口（即在不同 Goroutine 之间切换执行顺序）。
    - **观察** 变量的值，查找可能发生的数据竞争（Race Condition）。

### 调试以排除故障

```go
func (ts *TicketStore) Puts(s string) {
    ticket := atomic.AddUint64(ts.next, 1) -1
    slots[ticket] = s
    atomic.AddUint64(ts.done, 1)
}
```

## 并发实战

- **避免阻塞，避免竞争**  
- **优先使用通道避免共享状态**  
- **当通道不适用时**：
    - 先尝试 `sync` 包的工具  
    - 在简单场景或必要时，尝试无锁代码  