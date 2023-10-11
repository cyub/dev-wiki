# redis

## redis为什么高效？

1. 纯内存缓存数据库
2. 使用单线程，避免了多线程带来的频繁的上下文切换
3. 使用了高效的数据结构体
4. 客户端和服务端使用了非阻塞的IO多路复用模型

## redis支持哪些数据结构？

1. 字符串 string
2. 列表 list
3. 哈希表  hash
4. 集合 set
5. 有序集合 Sorted Set

高级数据结构有：HyperLogLog/BitMap/BloomFilter/GeoHash

## redis典型使用场景有哪些？

1. 队列

    1. 使用lpush/brpop或者blpop/rpush

        优点：使用简单， 缺点：若消费过慢，容易出现热点数据，不支持消费确认，不支持重复消费和多次消费
    2. 使用SUBSCRIBE/PUBLISH 发布订阅模式

        优点：使用简单，支持多次消费。缺点：不支持持久化，容易丢数据。若消息者异常，则在异常这段时间，消息是无法被该消费者消费到的。

    4. 使用有序集合（Sorted-Set）实现延迟队列

    3. 使用Stream类型

        优点：redis5.0支持，近乎完美。1.支持阻塞或非阻塞式读取 2. 支持消费组模式，从而支持多次消费 2. 支持消息队列监控

2. 排行榜

3. 自动补全

4. 分布式锁

    为了避免单点故障，可以使用redlock。

    redlock原理：不能只在一个redis实例上创建锁，应该是在多个redis实例上创建锁，n/2 + 1，必须在大多数redis节点上都成功创建锁，才能算这个整体的RedLock加锁成功，避免说仅仅在一个redis实例上加锁而带来的问题。

5. UV统计

    使用HyperLogLog数据结构实现：

    ```
    redis 127.0.0.1:6379> PFADD runoobkey "redis"

    1) (integer) 1

    redis 127.0.0.1:6379> PFADD runoobkey "mongodb"

    1) (integer) 1

    redis 127.0.0.1:6379> PFADD runoobkey "mysql"

    1) (integer) 1

    redis 127.0.0.1:6379> PFCOUNT runoobkey

    (integer) 3
    ```

6. 去重过滤

    基于bitmap实现布隆过滤器或者直接使用Redis Module: BloomFilter

7. 限流器

8. 用户签到/用户在线状态/活跃用户统计等统计功能

    基于位图bitmap实现


## redis中key有哪些过期策略？

1. 惰性删除策略

    当访问key时候，再检查key是否过期

2. 定期删除策略

    Redis 会将每个设置了过期时间的 key 放入到一个独立的字典中，默认每 100ms 进行一次过期扫描：

    1. 从过期key字典中随机 20 个 key，删除这 20 个 key 中已经过期的 key

    2. 如果过期的 key 比率超过 1/4，那就重复步骤 1

    3. 扫描处理时间默认不会超过 25ms

## redis中最大内存策略有哪些？

redis中最大内存是由maxmemory参数配置的，当内存使用达到设置的最大内存上限时候，会执行最大内存策略：

1. noeviction 从不驱逐，一直写，直到可用内存使用完，写不进数据

2. volatile

    - volatile-ttl 设置了过期时间，ttl时间越短的key越优先被淘汰

    - volatile-lru 基于LRU规则(Least Recently Used)淘汰删除设置了过期时间的key

    - volatile-random 随机淘汰过期集合中的key

3. allkeys

    - allkeys-lru 基于LRU规则淘汰所有key

    - allkeys-random 随机淘汰

## redis中持久化方式有哪些？

### RDB

RDB是Snapshot快照存储，是redis默认的持久化方式，即按照一定的策略周期性的将数据保存到磁盘上。配置文件中的save参数来定义快照的周期。

```
# RDB持久化策略 默认三种方式，[900秒内有1次修改],[300秒内有10次修改],[60秒内有10000次修改]即触发RDB持久化，我们可以手动修改该参数或新增策略
save 900 1
save 300 10
save 60 10000
```

优点：

1. 压缩的二进制文件，非常适合备份和灾难恢复

缺点：

1. 备份操作需要fork一个进程（使用bgsave命令）属于重操作
2. 不能最大限度避免丢失数据

### AOF

AOF(Append-Only File)，Redis会将每一个收到的写命令都通过Write函数追加到文件中（默认appendonly.aof）。

优点：

1. 以文本形式保存，易读
2. 能最大限度避免丢失数据

缺点：

1. 文件体积过大（可以使用bgrewriteaof重写aof)
2. 相比rdb，aof恢复数据较慢


AOF支持三种同步策略：

```
appendfsync always # 默认alawys
```

1. always

    每条Redis写命令都同步写入硬盘

2. everysec

    每秒执行一次同步，将多个命令写入硬盘

3. no

    由操作系统决定何时同步。

Redis重启的时候优先加载AOF文件，如果AOF文件不存在再去加载RDB文件。 如果AOF文件和RDB文件都不存在，那么直接启动。 不论加载AOF文件还是RDB文件，只要发生错误都会打印错误信息，并且启动失败。

## redis键的数据结构是什么样的？

整个Redis 数据库的所有key 和value 也组成了一个全局字典，还有带过期时间的key 集合也是一个字典。

```c++
struct RedisDb {
	dict	* dict;         /* all keys key=>value */
	dict	* expires;      /* all expired keys key=>long(timestamp) */
	...
}
```

## zset底层数据结构是什么样的？

Redis 的zset 是一个复合结构，一方面它需要一个hash结构（字典）来存储value（成员) 和score 的对应关系，
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
    sds ele; // 节点存储的具体值 
    double score; // 节点对应的分值
    struct zskiplistNode *backward; // 后退指针
    struct zskiplistLevel {
        struct zskiplistNode *forward; // //前进指针
        unsigned long span; // 到下一个节点的跨度 
    } level[];
} zskiplistNode;
```

## set底层数据结构是什么样的？

set底层数据结构有两种，即intset和dict。当满足以下条件时候，使用intset，否则使用dict：

1. 结合对象保存的所有元素都是整数值
2. 集合对象保存的元素数量不超过512个

当使用dict时候，即hashTable，哈希表的key值是set集合元素，value值是nil。

资料：https://juejin.cn/post/6844904198019137550

## Zrank的复杂度是O(log(n))，为什么？

Redis 在skiplist 的forward 指针上进行了优化，给每一个forward 指针都增加了span 属性，span 是「跨度」的意思， 表示从前一个节点沿着当前层的forward 指针跳到当前这个节点中间会跳过多少个节点 这样计算一个元素的排名时，只需要将「搜索路径」上的经过的所有节点的跨度span 值进行叠加就可以算出元素的最终rank 值。

## zrange 的复杂度是 O(log(N)+M)， N 为有序集的基数，而 M 为结果集的基数。为什么是这个复杂度呢？

ZRANGE key start stop [WITHSCORES]，zrange 就是返回有序集 key 中，指定区间内的成员，而跳表中的元素最下面的一层是有序的(上面的几层就是跳表的索引)，按照分数排序，我们只要找出 start 代表的元素，然后向前或者向后遍历 M 次拉出所有数据即可，而找出 start 代表的元素，其实就是在跳表中找一个元素的时间复杂度。**跳表中每个节点每一层都会保存到下一个节点的跨度，在寻找过程中可以根据跨度和来求当前的排名**，所以查找过程是 O(log(N) 过程，加上遍历 M 个元素，就是 O(log(N)+M)，所以 redis 的 zrange 不会像 mysql 的 offset 有比较严重的性能问题。

## redis中哪些操作时间复杂度O(n)?

### Key

```
keys *
```

### List

```
lindex // n为列表长度
lset
linsert
```

### Hash

```
hgetall // n为哈希表大小
hkeys
hvals
```

### Set

```
smembers // 返回所有集合成员，n为集合成员元素
sunion/sunionstore // 并集， N 是所有给定集合的成员数量之和
sinter/sinterstore // 交集，O(N * M)， N 为给定集合当中基数最小的集合， M 为给定集合的个数
sdiff/sdiffstore // 差集， N 是所有给定集合的成员数量之和
Sorted Set：

zrange/zrevrange/zrangebyscore/zrevrangebyscore/zremrangebyrank/zremrangebyscore // O(m) + O(log(n)) // N 为有序集的基数，而 M 为结果集的基数
```

## redis哨兵模式介绍？

redis的哨兵模式（sentinel）**为了保证redis主从的高可用**。主要功能：

1. 监控：它会监听主服务器和从服务器之间是否在正常工作。
2. 故障转移：它在主节点出了问题的情况下，会在所有的从节点中竞选出一个节点，并将其作为新的主节点。

从从节点选出一个主节点流程是：
1. 首先去掉所有断线或下线的节点，获取所有监控节点
2. 然后选择**复制偏移量**最大的节点，复制偏移量代表其从主节点成功复制了多少数据，越大说明越与主节点最接近同步。
3. 若步骤选出了多个节点，那比较每个节点的唯一标识uid，选择最小的那个。

将从节点变成主节点操作时候，需要哨兵来操作，由于为了保证哨兵高可用性，哨兵存在多个，那就需要选主出来一个哨兵头领来处理这个操作，这个过程涉及到Raft算法。

## redis cluster分片原理？

采用虚拟槽进行数据分片，总共2^14个虚拟槽，有几个节点就把2^14分成几个范围，按照crc16(key)%2^14确定key在哪个槽，每个节点保存了集群中的槽对应的节点信息，如果一个请求过来发现key不在这个节点上，这个节点会回复一个mov的消息指向新节点，彼此节点间定时通过ping来检测故障。

## redis rehash过程？

redis采用渐进式hash方式。redis会同时维持两个hash表：ht[0] 和 ht[1] 两个哈希表。 要在字典里面查找一个键的话， 程序会先在 ht[0] 里面进行查找， 如果没找到的话， 就会继续到 ht[1] 里面进行查找， 诸如此类。在渐进式 rehash 执行期间， 新添加到字典的键值对一律会被保存到 ht[1] 里面， 而 ht[0] 则不再进行任何添加操作


## redis底层数据结构？

![](https://static.cyub.vip/images/202107/redis-inner.png)