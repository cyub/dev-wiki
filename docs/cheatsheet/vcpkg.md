# vcpkg

## 简介

Vcpkg 是由 Microsoft 和 C++ 社区维护的免费开源 C/C++ 包管理器，可在 Windows、macOS 和 Linux 上运行。 它是核心的 C++ 工具，使用 C++ 和 CMake 脚本编写。 它旨在解决管理 C/C++ 库的独特难题。

## 为什么使用 vcpkg？

- 在特选注册表中有超过[2300 个开源库](https://github.com/microsoft/vcpkg/tree/master/ports)可供选择，这些库会定期生成，用于验证 ABI 兼容性
- 支持使用自己的自定义库包创建自定义库注册表
- 适用于 Windows、macOS 和 Linux 的一致的跨平台体验
- 使用任何生成和项目系统都可以轻松将库添加到项目
- 从源生成依赖项或下载预生成的 ABI 验证二进制文件，默认提供 70 多个配置，并可针对特定要求进行无限自定义
- 通过独特的版本控制设计，防止依赖项之间出现版本冲突和菱形依赖问题
- 对于 MSBuild 和 CMake 用户：自动与生成环境集成，打造无缝获取依赖项的体验

## 第一个示例

### 安装Vcpkg

1. GitHub 克隆 vcpkg 存储库

```bash
git clone https://github.com/microsoft/vcpkg.git
```

存储库包含用于获取 vcpkg 可执行文件的脚本，以及由 vcpkg 社区维护的特选开放源代码库的注册表。vcpkg 特选注册表是一组数量超过 2000 个的开源库。 这些库已通过 vcpkg 的持续集成管道进行验证，可以协同工作。 虽然 vcpkg 存储库不包含这些库的源代码，但它保存方案和元数据，以便在系统中生成和安装它们。

2. 安装vcpkg
```bash
cd vcpkg && ./bootstrap-vcpkg.sh
```

3. 配置环境变量
```bash
export VCPKG_ROOT=/path/to/vcpkg
export PATH=$VCPKG_ROOT:$PATH

vcpkg --version # 查看安装是否成功
```

### 创建项目

创建项目目录

```bash
mkdir helloworld && cd helloworld
```

创建清单文件

```bash
vcpkg new --application
```

添加`fmt`依赖项

```bash
vcpkg add port fmt
```

创建`CMakeLists.txt`文件：

```cmake
cmake_minimum_required(VERSION 3.10)

project(HelloWorld)

find_package(fmt CONFIG REQUIRED)

add_executable(HelloWorld helloworld.cpp)

target_link_libraries(HelloWorld PRIVATE fmt::fmt)
```

示例源码

```cpp
#include <fmt/core.h>

int main()
{
    fmt::print("Hello World!\n");
    return 0;
}
```

运行生成Cmake配置

创建`CMakePresets.json`文件：

```json
{
  "version": 2,
  "configurePresets": [
    {
      "name": "vcpkg",
      "generator": "Unix Makefiles",
      "binaryDir": "${sourceDir}/build",
      "cacheVariables": {
        "CMAKE_TOOLCHAIN_FILE": "$env{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
      }
    }
  ]
}
```

创建`CMakeUserPresets.json`：

```json
{
  "version": 2,
  "configurePresets": [
    {
      "name": "default",
      "inherits": "vcpkg",
      "environment": {
        "VCPKG_ROOT": "<path to vcpkg>"
      }
    }
  ]
}
```

`CMakePresets.json`文件中将 `CMAKE_TOOLCHAIN_FILE` 设置为使用 vcpkg 的自定义工具链时，CMake 可以自动链接 vcpkg 安装的库。 `CMakeUserPresets.json` 文件会将 `VCPKG_ROOT` 环境变量设置为指向包含 vcpkg 本地安装的绝对路径。 建议不要将 `CMakeUserPresets.json` 签入版本控制系统。

生成Cmake配置：

```bash
cmake --preset=default
```

运行项目

```bash
cmake --build build # 生成项目

./build/HelloWorld # 运行项目
```

## 第二个示例：手动安装依赖

创建项目目录

```bash
mkdir fib-example
```

创建源文件`main.cpp`

```cpp
#include <cxxopts.hpp>
#include <fmt/format.h>
#include <range/v3/view.hpp>

namespace view = ranges::views;

int fib(int x)
{
  int a = 0, b = 1;

  for (int it : view::repeat(0) | view::take(x))
  {
    (void)it;
    int tmp = a;
    a += b;
    b = tmp;
  }

  return a;
}

int main(int argc, char **argv)
{
  cxxopts::Options options("fibo", "Print the fibonacci sequence up to a value 'n'");
  options.add_options()("n,value", "The value to print to", cxxopts::value<int>()->default_value("10"));

  auto result = options.parse(argc, argv);
  auto n = result["value"].as<int>();

  for (int x : view::iota(1) | view::take(n))
  {
    fmt::print("fib({}) = {}\n", x, fib(x));
  }
}
```

手动添加依赖

```bash
vcpkg new --application # 初始化操作

vcpkg add port fmt cxxopts range-v3
```

手动创建`CMakeLists.txt`文件

```Cmake
cmake_minimum_required(VERSION 3.15)

project(fibonacci CXX)

find_package(fmt REQUIRED)
find_package(range-v3 REQUIRED)
find_package(cxxopts REQUIRED)

set(CMAKE_CXX_STANDARD 17)

add_executable(fibo main.cxx)

target_link_libraries(fibo
  PRIVATE
    fmt::fmt
    range-v3::range-v3
    cxxopts::cxxopts)
```

手动配置Cmake

```bash
cmake -B build -S . -DCMAKE_TOOLCHAIN_FILE=${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake
```

生成项目

```
cmake --build build
```

运行项目

```
./build/fib
```

## 参考资料

- [microsoft官方教程：通过 CMake 安装和使用包](https://learn.microsoft.com/zh-cn/vcpkg/get_started/get-started?pivots=shell-bash)