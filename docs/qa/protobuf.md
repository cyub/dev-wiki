# Protobuf

## Protobuf编码相比Json的优点有哪些？

1. 具有强一致性
2. 占用空间小，更高效

## Protobuf编码存储方式是？

![](https://static.cyub.vip/images/202107/protobuf_codec.png)

Protobuf采用的是`Tag - Length - Value`，即`标识 - 长度 - 字段值`。 Tag 整体采用 Varints 编码。

Tag是标识，是将字段编号左移三位之后与字段类型或运算之后产生：

```
Tag  = (field_number << 3) | wire_type
```

varint是一种变长编码方式，用来字节编码数字，每个字节的高位表示后面的那个字节是否是数字的一部分。

varint缺点是如果用来编码一个负数，一定需要5个byte。因为负数最高位是1，会被当做很大的整数去处理。解决办法是采用zigzag编码，即将负数转换成正数，然后再采用varint编码。

### Wire Type = 0时的编码和存储方式

对于int32/int64类型的数据（正数），protobuf会使用Varints编码；而对于sint32/sint64类型的数据（负数），protobuf会先使用ZigZag 编码，再使用Varints编码。存储格式为Tag-Value。

### Wire Type = 2时的编码和存储方式

对于string，bytes和嵌套消息类型的数据，protobuf会使用Length-delimited编码，存储格式为Tag-Length-Value。

### Wire Type = 1&5时的编码和存储方式

对于大整数类型的数据，protobuf会使用64-bit和32-bit编码方式，存储格式为Tag-Value。
Varints适合处理一定范围内的数字，当数字很大的时候使用Varints编码效率反而很低，因此protobuf定义了64-bit和32-bit两种定长编码类型。