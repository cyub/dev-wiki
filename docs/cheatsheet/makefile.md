# Makefile

原始内容来自 [rstacruz/cheatsheets](https://github.com/rstacruz/cheatsheets/blob/master/makefile.md) 有改动。

## 变量赋值

```makefile
foo  = "bar" # foo 当前值为 bar，允许后面进行会修改
bar  = $(foo) foo  # Makefile 展开，确定 foo 值之后才能决定最后 bar 的值
dum := $(foo) foo # dum值为 bar foo
foo := "boo"       # 此时 foo 值被修改为 boo
foo ?= /usr/local  # 如果 foo 没有赋值过，才会进行赋值
bar += world       # 追加
foo != echo fooo   # 执行shell 命令后foo 值为 fooo

# 因为 foo 最终值确定为 fooo，所以最终 bar 值为fooo foo world。
```

`=` 用于创建一个可变的变量，后面可以重新赋值这个变量，最终值是整个 Makefile 最后指定的值。`:=`是赋予当前位置的值。`?=`是如果该变量没有被赋值，才被赋值为等号后面的值。

```makefile
x = foo
y = $(x) bar
z := $(x) bar
x = xyz
```

上面例子中x,y,z最终值分别为`xyz`,`xyz bar`, `foo bar`。

## 魔术变量

```makefile
out.o: src.c src.h src.c
  $@   # "out.o" (目标对象)
  $<   # "src.c" (第一个前置依赖)
  $^   # "src.c src.h" (所有的前置依赖)
  $+   # "src.c src.h src.c" (类似$^，不同于$^地方是它不会去重)
  $?   # 所有比目标对象新的依赖的集合
  $(@D) # "." (目标对象中的目录部分，没有目录部分那么对应是.)
```

## 命令前缀

| 前缀 | 描述 |
| --- | --- |
| `-` | 忽略错误 |
| `@` | 不打印命令输出 |
| `+` | 忽略错误，但会打印错误信息 |

```makefile
build:
    @echo "compiling"
    -gcc $< $@

-include .depend
```

## 查找文件

```makefile
js_files  := $(wildcard test/*.js) # 匹配所有test目录下的js文件
all_files := $(shell find images -name "*") # 查找images目录下所有文件
```

## 函数

```makefile
# 替换相关
file     = $(SOURCE:.cpp=.o)   # 替换 .cpp 为 .o
outputs  = $(files:src/%.coffee=lib/%.js) # 替换 .coffee 为 .js
outputs  = $(patsubst %.c, %.o, $(wildcard *.c)) # 替换 *.c 为 *.o
assets   = $(patsubst images/%, assets/%, $(wildcard images/*)) # 替换 images/ 为 assets/

# 其他函数
$(strip $(string_var)) # 移除字符串两端的空格

$(filter %.less, $(files)) # 匹配所有以 .less 结尾的文件
$(filter-out %.less, $(files)) # 匹配所有不是以 .less 结尾的文件

$(subst ee,EE,feet on the street) # 替换 ee 为 EE
```

`patsubst <pattern>,<replacement>,<text>` 是将 text 中的所有匹配 pattern 的部分替换成 replacement。

## 多目标规则

Makefile的规则中的目标可以不止一个，其支持多目标，有可能我们的多个目标同时依赖于一个文件，并且其生成的命令大体类似。于是我们就能把其合并起来。

```makefile
bigoutput littleoutput : text.g
    generate text.g -$(subst output,,$@) > $@
```

其中， `-$(subst output,,$@)` 中的 $ 表示执行一个Makefile的函数，函数名为subst，后面的为参数。上述规则等价于：

```makefile
bigoutput : text.g
    generate text.g -big > bigoutput
littleoutput : text.g
    generate text.g -little > littleoutput
```

### 静态模式

静态模式可以更加容易地定义多目标的规则。

```makefile
<targets ...> : <target-pattern> : <prereq-patterns ...>
    <commands>
    ...
```

- targets定义了一系列的目标文件，可以有通配符。是目标的一个集合。

- target-pattern是指明了targets的模式，也就是的目标集模式。

- prereq-patterns是目标的依赖模式，它对target-pattern形成的模式再进行一次依赖目标的定义。

```makefile
objects = foo.o bar.o

all: $(objects)

$(objects): %.o: %.c
    $(CC) -c $(CFLAGS) $< -o $@
```

上面的例子中，指明了我们的目标从$object中获取， %.o 表明要所有以 .o 结尾的目标，也就是 foo.o bar.o ，也就是变量 $object 集合的模式，而依赖模式 %.c 则取模式 %.o 的 % ，也就是 foo bar ，并为其加下 .c 的后缀，于是，我们的依赖目标就是 foo.c bar.c 。而命令中的 $< 和 $@ 则是自动化变量， $< 表示第一个依赖文件， $@ 表示目标集（也就是“foo.o bar.o”）。于是，上面的规则展开后等价于下面的规则：

```makefile
foo.o : foo.c
    $(CC) -c $(CFLAGS) foo.c -o foo.o
bar.o : bar.c
    $(CC) -c $(CFLAGS) bar.c -o bar.o
```

再看一个例子：

```makefile
files = foo.elc bar.o lose.o

$(filter %.o,$(files)): %.o: %.c
    $(CC) -c $(CFLAGS) $< -o $@

$(filter %.elc,$(files)): %.elc: %.el
    emacs -f batch-byte-compile $<
```

`$(filter %.o,$(files))`表示调用Makefile的filter函数，过滤“$files”集，只要其中模式为“%.o”的内容。

## 隐含规则与模式规则

### 隐含规则

```makefile
foo : foo.o bar.o
    cc –o foo foo.o bar.o $(CFLAGS) $(LDFLAGS)
```

这个Makefile中并没有写下如何生成 foo.o 和 bar.o 这两目标的规则和命令。因为make的“隐含规则”功能会自动为我们自动去推导这两个目标的依赖目标和生成命令。在上面的那个例子中，make调用的隐含规则是，把 .o 的目标的依赖文件置成 .c ，并使用C的编译命令 `cc –c $(CFLAGS)  foo.c` 来生成 foo.o 的目标。也就是说，它等同于下面的两条规则：

```makefile
foo.o : foo.c
    cc –c foo.c $(CFLAGS)
bar.o : bar.c
    cc –c bar.c $(CFLAGS)
```

另外对于没有 Makefile 的时候，对于一个 foo.c 文件，我们可以 make foo 时，会自动运行`cc foo.c -o foo`。

### 老式风格的“后缀规则”

后缀规则是一个比较老式的定义隐含规则的方法。后缀规则会被模式规则逐步地取代。因为模式规则更强更清晰。为了和老版本的Makefile兼容，GNU make同样兼容于这些东西。后缀规则有两种方式：“双后缀”和“单后缀”。

双后缀规则定义了一对后缀：目标文件的后缀和依赖目标（源文件）的后缀。如 .c.o 相当于 %o : %c 。单后缀规则只定义一个后缀，也就是源文件的后缀。如 .c 相当于 % : %.c 。后缀规则不允许任何的依赖文件，如果有依赖文件的话，那就不是后缀规则，那些后缀统统被认为是文件名。

```makefile
.c.o:
    $(CC) -c $(CFLAGS) $(CPPFLAGS) -o $@ $<
```

### 模式规则

我们可以使用模式规则来定义一个隐含规则，模式规则中，至少在规则的目标定义中要包含 % ，否则，就是一般的规则。目标中的 % 定义表示对文件名的匹配。

```makefile
%.o: %.c
  $(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@ # 把所有的 .c 文件都编译成 .o 文件
```


## 条件判断

```makefile
foo: $(objects)
ifeq ($(CC),gcc)
  $(CC) -o foo $(objects) $(libs_for_gcc)
else
  $(CC) -o foo $(objects) $(normal_libs)
endif
```

## 自动生成依赖性

在Makefile中，我们的依赖关系可能会需要包含一系列的头文件，我们可以借助编译器来生成依赖关系。

```bash
cc -M main.c # -M选项输出依赖关系
gcc -MM main.c # -MM 选项输出依赖关系，输出的依赖关系中会去掉标准库中的头文件
cc -MM src/chap8/udpserv01.c -I./src/include # 使用 -I 参数指定自定义头文件位置
```

## 包含其他 Makefile

```makefile
-include foo.make
```

make会在当前目录下首先寻找，如果当前目录下没有找到，那么，make还会在下面的几个目录下找：

1. 如果make执行时，有 -I 或 --include-dir 参数，那么make就会在这个参数所指定的目录下去寻找。

2. 接下来按顺序寻找目录 <prefix>/include （一般是 /usr/local/bin ）、 /usr/gnu/include 、 /usr/local/include 、 /usr/include 。

环境变量 .INCLUDE_DIRS 包含当前 make 会寻找的目录列表。你应当避免使用命令行参数 -I 来寻找以上这些默认目录，否则会使得 make “忘掉”所有已经设定的包含目录，包括默认目录。

## 命令行选项

```sh
make
  -e, --environment-overrides # 允许环境变量覆盖 Makefile 的变量
  -B, --always-make # 强制重新编译所有目标
  -s, --silent # 不打印任何信息
  -j, --jobs=N   # 并行编译，N 表示同时编译的线程数
  -f, --file=FILE # 指定 Makefile 文件
```


## 参考示例

```makefile
CC=cc
CFLAGS+=-Wall -Werror -Wformat=2 -g
LDFLAGS=-I./src/include -L./src/lib

COMPILER_VERSION=$(shell $(CC) --version)
ifneq '' '$(findstring clang, $(COMPILER_VERSION))'
	CFLAGS += -Qunused-arguments
endif

lib := src/lib
bin := udpserv01 udpcli01
all: $(bin)

lib_objects :=$(patsubst %.c, %.o, $(wildcard $(lib)/*.c))
$(lib_objects): %.o : %.c
	$(CC) -c $(CFLAGS) $(LDFLAGS) $< -o $@

.PHONY: udpserv01
udpserv01: src/chap8/udpserv01.c $(lib_objects)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@

.PHONY: udpcli01
udpcli01: $(lib_objects) src/chap8/udpcli01.c dg_cli.o
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@
```

### 单个主文件

项目结构如下：

```css
project/
├── main.c
├── Makefile
```

Makefile 示例：

```makefile
# 编译器
CC = gcc

# 编译选项
CFLAGS = -Wall -Wextra -std=c11 -O2

# 目标文件和最终可执行文件
TARGET = main
SRC = main.c

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC)

clean:
	rm -f $(TARGET)

.PHONY: all clean
```

### 多个源文件

项目结构如下：

```css
project/
├── main.c
├── utils.c
├── utils.h
├── Makefile
```

Makefile 示例：

```makefile
CC = gcc
CFLAGS = -Wall -Wextra -std=c11 -O2

TARGET = app
OBJS = main.o utils.o

# 默认目标
all: $(TARGET)

# 链接
$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^

# 编译每个 .c 文件为 .o
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# 清理
clean:
	rm -f *.o $(TARGET)

.PHONY: all clean
```

自动识别所有 .c 文件的 Makefile 的示例：

```makefile
CC = gcc
CFLAGS = -Wall -Wextra -std=c11 -O2

SRC = $(wildcard *.c)
OBJ = $(SRC:.c=.o)
TARGET = app

all: $(TARGET)

$(TARGET): $(OBJ)
	$(CC) $(CFLAGS) -o $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f *.o $(TARGET)

.PHONY: all clean
```

### 支持模块库 + 安装 + 测试

项目结构如下：

```css
your_project/
├── Makefile
├── src/
│   ├── main.c
│   ├── libmath/
│   │   ├── math.c
│   │   └── math.h
│   ├── libnet/
│   │   ├── net.c
│   │   └── net.h
├── include/
│   └── common.h         # 通用头文件（可选）
├── test/
│   └── test_math.c
├── build/               # 自动生成
```

Makefile 示例：

```makefile
# 编译器和选项
CC := gcc
AR := ar
CFLAGS := -Wall -Wextra -fPIC -Iinclude
LDFLAGS :=
DEBUG_FLAGS := -g
RELEASE_FLAGS := -O2

SRC_DIR := src
BUILD_DIR := build
DEP_DIR := $(BUILD_DIR)/deps
LIB_DIR := $(BUILD_DIR)/lib
TEST_DIR := test
INSTALL_PREFIX := /usr/local

TARGET := $(BUILD_DIR)/app

# 控制链接类型（默认静态）
LINK_TYPE ?= static  # 可选 static / shared

# 源文件
MATH_SRC := $(wildcard $(SRC_DIR)/libmath/*.c)
NET_SRC := $(wildcard $(SRC_DIR)/libnet/*.c)
MAIN_SRC := $(filter-out $(MATH_SRC) $(NET_SRC), $(shell find $(SRC_DIR) -name '*.c'))

# 对应 .o 文件
MATH_OBJ := $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/%.o, $(MATH_SRC))
NET_OBJ := $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/%.o, $(NET_SRC))
MAIN_OBJ := $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/%.o, $(MAIN_SRC))

# .a/.so 输出路径
MATH_STATIC := $(LIB_DIR)/libmath.a
NET_STATIC := $(LIB_DIR)/libnet.a
MATH_SHARED := $(LIB_DIR)/libmath.so
NET_SHARED := $(LIB_DIR)/libnet.so

# 默认构建
all: release

release: CFLAGS += $(RELEASE_FLAGS)
release: $(TARGET)

debug: CFLAGS += $(DEBUG_FLAGS)
debug: $(TARGET)

# 主程序链接
$(TARGET): $(MAIN_OBJ) $(MATH_LIB) $(NET_LIB)
	@mkdir -p $(BUILD_DIR)
ifeq ($(LINK_TYPE),shared)
	$(CC) $(CFLAGS) $^ -L$(LIB_DIR) -lmath -lnet -o $@ $(LDFLAGS) -Wl,-rpath=$(LIB_DIR)
else
	$(CC) $(CFLAGS) $^ -o $@
endif
	@echo "✅ Linked: $@ (LINK_TYPE=$(LINK_TYPE))"

# 模块构建静态库
$(MATH_STATIC): $(MATH_OBJ)
	@mkdir -p $(LIB_DIR)
	$(AR) rcs $@ $@

$(NET_STATIC): $(NET_OBJ)
	@mkdir -p $(LIB_DIR)
	$(AR) rcs $@ $@

# 模块构建动态库
$(MATH_SHARED): $(MATH_OBJ)
	@mkdir -p $(LIB_DIR)
	$(CC) -shared $^ -o $@

$(NET_SHARED): $(NET_OBJ)
	@mkdir -p $(LIB_DIR)
	$(CC) -shared $^ -o $@

# 模块输出选择（静态或动态）
ifeq ($(LINK_TYPE),shared)
MATH_LIB := $(MATH_SHARED)
NET_LIB  := $(NET_SHARED)
else
MATH_LIB := $(MATH_STATIC)
NET_LIB  := $(NET_STATIC)
endif

# 依赖
ALL_SRCS := $(MATH_SRC) $(NET_SRC) $(MAIN_SRC)
DEPS := $(patsubst $(SRC_DIR)/%.c, $(DEP_DIR)/%.d, $(ALL_SRCS))

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(dir $@) $(dir $(DEP_DIR)/$*.d)
	$(CC) $(CFLAGS) -MMD -MF $(DEP_DIR)/$*.d -c $< -o $@

-include $(DEPS)

# 安装
install:
	@mkdir -p $(INSTALL_PREFIX)/bin
	@mkdir -p $(INSTALL_PREFIX)/include
	cp $(TARGET) $(INSTALL_PREFIX)/bin/
	cp -r src/libmath/*.h src/libnet/*.h include/* $(INSTALL_PREFIX)/include/
ifeq ($(LINK_TYPE),shared)
	cp $(MATH_LIB) $(NET_LIB) $(INSTALL_PREFIX)/lib/
else
	cp $(MATH_LIB) $(NET_LIB) $(INSTALL_PREFIX)/lib/
endif
	@echo "✅ Installed to $(INSTALL_PREFIX)"

# 测试
test: $(TARGET)
	@echo "🧪 Running test cases..."
	@for file in $(wildcard $(TEST_DIR)/*.c); do \
		obj=$$(basename $$file .c); \
		$(CC) $(CFLAGS) -c $$file -o $(BUILD_DIR)/$$obj.o; \
		if [ "$(LINK_TYPE)" = "shared" ]; then \
			$(CC) $(BUILD_DIR)/$$obj.o -L$(LIB_DIR) -lmath -lnet -Wl,-rpath=$(LIB_DIR) -o $(BUILD_DIR)/$$obj; \
		else \
			$(CC) $(BUILD_DIR)/$$obj.o $(MATH_LIB) $(NET_LIB) -o $(BUILD_DIR)/$$obj; \
		fi; \
		./$(BUILD_DIR)/$$obj || exit 1; \
	done

clean:
	rm -rf $(BUILD_DIR)
	@echo "🧹 Cleaned build directory."

.PHONY: all release debug clean install test
```

## 进一步阅读

- [isaacs's Makefile](https://gist.github.com/isaacs/62a2d1825d04437c6f08)
- [Your Makefiles are wrong](https://tech.davis-hansson.com/p/make/)
- [Manual](https://www.gnu.org/software/make/manual/html_node/index.html)
- [跟我一起写Makefile](https://seisman.github.io/how-to-write-makefile/index.html)

