# redis

## redis架构

- 纯内存操作
- 单线程避免了多线程频繁的上小文切换问题
- 高效的数据结构
- 核心是基于非阻塞的IO多路复用

## 应用场景

- 队列
- 排行榜
- 自动补全
- 分布式锁
- UV统计（hyperloglog)
- 去重过滤(基于布隆过滤器)
- 限流器
- 用户签到/用户在线状态/活跃用户统计（基于位图）

## 过期策略

- 惰性删除
    - 当程序访问某key时候，会检查key是否过期，过期则删除

- 定期删除
    - 从过期key字典中随机 20 个 key
    - 删除这 20 个 key 中已经过期的 key
    - 如果过期的 key 比率超过 1/4，那就重复步骤 1
    - 扫描处理时间默认不会超过 25ms


## 最大内存策略

当内存使用达到设置的最大内存上限(配置参数 maxmemory )

- noeviction
    一直写，直到可用内存使用完，写不进数据
- volatile
    - volatile-ttl  设置了过期时间，ttl时间越短的key越优先被淘汰
    - volatile-lru
    基于LRU规则淘汰删除设置了过期时间的key
    - volatile-random 随机淘汰过期集合中的key
- allkeys
    - allkeys-lru 基于LRU规则淘汰所有key
    - allkeys-random 随机淘汰

## 持久化方式

一句话：使用RDB持久化会有数据丢失的风险，但是恢复速度快，而使用AOF持久化可以保证数据完整性，但恢复数据的时候会很慢

### RDB
RDB就是Snapshot快照存储，是默认的持久化方式。可理解为半持久化模式，即按照一定的策略周期性的将数据保存到磁盘。对应产生的数据文件为dump.rdb，通过配置文件中的save参数来定义快照的周期。下面是默认的快照设置：

```bash
# RDB持久化策略 默认三种方式，[900秒内有1次修改],[300秒内有10次修改],[60秒内有10000次修改]即触发RDB持久化，我们可以手动修改该参数或新增策略
save 900 1
save 300 10
save 60 10000
 
#RDB文件名
dbfilename "dump.rdb"
#RDB文件存储路径
dir "/opt/app/redis6/data"
```

**优点：**

- 压缩后的二进制文件，非常适合备份
- 非常适用于灾难恢复
- 存储性能高：存储数据时，父进程fork出一个子进程，父进程无需执行任何磁盘IO操作

**不足：**

- 一旦数据库出现问题，那么dump.rdb文件中保存的数据并不是全新的。从上次RDB文件生成到Redis停机这段时间的数据全部丢掉了。
- 当备份的数据集比较大时，可能会非常耗时，造成服务器停止处理客户端请求；

### AOF

AOF(Append-Only File)比RDB方式有更好的持久化性。由于在使用AOF持久化方式时，Redis会将每一个收到的写命令都通过Write函数追加到文件中（默认appendonly.aof），类似于MySQL的binlog。当Redis重启时会通过重新执行文件中保存的写命令来在内存中重建整个数据库的内容。

```bash
#开启AOF持久化
appendonly yes
 
#AOF文件名
appendfilename "appendonly.aof"
 
#AOF文件存储路径 与RDB是同一个参数
dir "/opt/app/redis6/data"
 
#AOF策略，一般都是选择第一种[always:每个命令都记录],[everysec:每秒记录一次],[no:看机器的心情高兴了就记录]
appendfsync always
#appendfsync everysec
# appendfsync no
 
 
#aof文件大小比起上次重写时的大小,增长100%(配置可以大于100%)时,触发重写。[假如上次重写后大小为10MB，当AOF文件达到20MB时也会再次触发重写，以此类推]
auto-aof-rewrite-percentage 100 
 
#aof文件大小超过64MB时,触发重写
auto-aof-rewrite-min-size 64mb
```

为了避免AOF文件中的写命令太多文件太大，Redis引入了AOF的重写机制来压缩AOF文件体积。AOF文件重写是把Redis进程内的数据转化为写命令同步到新AOF文件的过程。重写会根据重写策略或手动触发AOF重写。

**优点：**

- 以文本形式保存，易读
- 记录写操作保证数据不丢失

**缺点：**

- 存储所有写操作命令，且文件为文本格式保存，未经压缩，文件体积高
- 恢复数据时重放AOF中所有代码，恢复性能弱于RDB方式

### AOF+RDB混合

开启混合模式后，每当bgrewriteaof命令之后会在AOF文件中以RDB格式写入当前最新的数据，之后的新的写操作继续以AOF的追加形式追加写命令。当redis重启的时候，加载 aof 文件进行恢复数据：先加载 rdb 的部分再加载剩余的 aof部分。

修改下面的参数即可开启AOF，RDB混合持久化：

```bash
aof-use-rdb-preamble yes
```


### Redis重启时加载持久化文件的顺序

Redis重启的时候优先加载AOF文件，如果AOF文件不存在再去加载RDB文件。
如果AOF文件和RDB文件都不存在，那么直接启动。
不论加载AOF文件还是RDB文件，只要发生错误都会打印错误信息，并且启动失败。

### 如何选择？

- 通常，如果你要想提供很高的数据保障性，那么建议你同时使用两种持久化方式。
- 如果你可以接受灾难带来的几分钟的数据丢失，那么你可以仅使用RDB。
- 很多用户仅使用了AOF，但是我们建议，既然RDB可以时不时的给数据做个完整的快照，并且提供更快的重启，所以最好还是也使用RDB。
- 因此，我们希望可以在未来（长远计划）统一AOF和RDB成一种持久化模式。

## 复杂度

### 键

整个Redis 数据库的所有key 和value 也组成了一个全局字典，还有带过期时间的key 集合也是一个字典。

```c
typedef struct redisDb {
dict *dict;
// all keys, key => value。所有的key和对应的value

dict *expires; // all expire keys, key => long(timestamp)，所有设置过期时间的key，和对应过期时间
} redisDb;

### zset复杂度

Redis 的zset 是一个复合结构，一方面它需要一个hash结构来存储value（成员) 和score 的对应关系，
另一方面需要提供按照score 来排序的功能，还需要能够指定score 的范围来获取value 列表的功能，这个时候通过跳跃列表实现。

```c++
typedef struct zset {
    dict *dict; // 字典
    zskiplist *zsl; // 跳表
} zset;

typedef struct zskiplist {
    struct zskiplistNode *header, *tail;
    unsigned long length;
    int level;
} zskiplist;

typedef struct zskiplistNode {
    sds ele;
    double score;
    struct zskiplistNode *backward;
    struct zskiplistLevel {
        struct zskiplistNode *forward;
        unsigned long span;
    } level[];
} zskiplistNode;
```

**Zrank的复杂度是O(log(n))，为什么？**

Redis 在skiplist 的forward 指针上进行了优化，给每一个forward 指针都增加了span 属性，span 是「跨度」的意思，
表示从前一个节点沿着当前层的forward 指针跳到当前这个节点中间会跳过多少个节点
这样计算一个元素的排名时，只需要将「搜索路径」上的经过的所有节点的跨度span 值进行叠加就可以算出元素的最终rank 值。


**zrange 的复杂度是 O(log(N)+M)， N 为有序集的基数，而 M 为结果集的基数。为什么是这个复杂度呢？**

ZRANGE key start stop [WITHSCORES]，zrange 就是返回有序集 key 中，指定区间内的成员，而跳表中的元素最下面的一层是有序的(上面的几层就是跳表的索引)，按照分数排序，我们只要找出 start 代表的元素，然后向前或者向后遍历 M 次拉出所有数据即可，而找出 start 代表的元素，其实就是在跳表中找一个元素的时间复杂度。跳表中每个节点每一层都会保存到下一个节点的跨度，在寻找过程中可以根据跨度和来求当前的排名，所以查找过程是 O(log(N) 过程，加上遍历 M 个元素，就是 O(log(N)+M)，所以 redis 的 zrange 不会像 mysql 的 offset 有比较严重的性能问题。

### 时间复杂度O(n)

**List:**

```c
lindex // n为列表长度
lset
linsert
```


**Hash：**

```c
hgetall // n为哈希表大小
hkeys
hvals
```

**Set：** 

```c
smembers // 返回所有集合成员，n为集合成员元素
sunion/sunionstore // 并集， N 是所有给定集合的成员数量之和
sinter/sinterstore // 交集，O(N * M)， N 为给定集合当中基数最小的集合， M 为给定集合的个数
sdiff/sdiffstore // 差集， N 是所有给定集合的成员数量之和
```

**Sorted Set：**

```c
zrange/zrevrange/zrangebyscore/zrevrangebyscore/zremrangebyrank/zremrangebyscore // O(m) + O(log(n)) // N 为有序集的基数，而 M 为结果集的基数
```

生产严禁使用的命令：

```c
keys
flushall
flushdb
```

我们可以在生产环境通过设置空别名来禁止危险命令：

```
# cat redis.conf
rename-command FLUSHALL ""  
rename-command FLUSHDB ""  
rename-command KEYS ""
```

### 统计概览

```
http://redisdoc.com/client_and_server/info.html

info commandstats 
info keyspace
```

## 资料

- [Redis---持久化方式RDB、AOF](https://blog.csdn.net/zhangpower1993/article/details/89034941)