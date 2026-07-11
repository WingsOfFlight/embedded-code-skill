---
name: embedded-code-skill
description: "嵌入式 C 代码规范化助手：驱动骨架、旧代码整理、代码审查、寄存器重构"
command: ecs
user-invocable: true
triggers:
  - embedded
  - firmware
  - driver
  - HAL
  - BSP
  - ISR
  - DMA
  - register
  - MCU
  - SoC
  - Cortex-M
  - RISC-V
  - RTOS
  - FreeRTOS
  - 1553
  - PWM
  - ADC
  - DAC
  - watchdog
  - CAN
  - UART
  - SPI
  - I2C
  - GPIO
  - Timer
  - 嵌入式
  - 固件
  - 驱动
---

# Embedded C 代码助手 Skill

---

## 1. 定位与使用原则

### 1.1 定位

帮助处理嵌入式 C 裸机/驱动代码：驱动骨架生成、旧代码规范化整理、代码审查、寄存器重构。

本 skill 提供**不绑定某个 IDE 或 agent 的保守编码规范**。任何真实寄存器偏移、位定义、reset 值、IRQ 号、时序限制、cache/DMA 规则和屏障要求，都必须来自目标芯片参考手册、厂商头文件、现有代码或用户提供的资料——**不编造硬件事实**。

### 1.2 使用原则

1. 先判断任务类型：`REWRITE` 或 `REVIEW`。
2. 先读目标仓库的头文件、宏、状态类型、命名、include 顺序、vendor SDK、编译开关和已有驱动样例。
3. **规范统一**：仓库已有代码若符合本 skill 规范则直接沿用；若不符合，在不改变原逻辑的前提下修改为符合本 skill 规范的写法。项目已使用 CMSIS 或厂商寄存器结构体时，基于它们生成代码，不要为了 fallback 再包一层。
4. **不编造硬件事实**：信息缺失时先说明缺口；若必须继续，使用清晰标注的 placeholder。
5. 输出便于 IDE 采用：优先给小补丁、限定代码块、文件/行号 findings 或明确的复制目标；除非用户明确要求大重写，不整文件替换。
6. 风格问题排在 correctness、硬件行为、安全性、并发和可移植风险之后。

### 1.3 生成前必须确认的信息

| 信息 | 要求 | 示例 |
|------|------|------|
| 外设/模块名 | 必需 | `uart`, `spi`, `gpio`, `dma` |
| 硬件来源 | 强烈建议 | 参考手册章节、厂商头文件、现有驱动 |
| 芯片或架构 | 强烈建议 | `STM32F4`, `Cortex-M4`, `ESP32` |
| 基地址/位定义 | 生产代码必需 | `UART_BASE_ADDR = 0x4000C000U` |
| 项目约定 | 生成或重写前读取 | status type、命名、SDK、build macros |
| RTOS（如适用） | 驱动层需确认 | FreeRTOS、Zephyr、RT-Thread、裸机 |

缺少生产级硬件信息时，可以生成保守骨架，但必须标注 `USER_PROVIDED`、`REPO_DERIVED` 或 `PLACEHOLDER`。

---

## 2. Fallback 编码规范

仅当目标仓库没有更强约定时使用。仓库已有代码若符合本规范则沿用，不符合则在不改变逻辑的前提下修改为符合本规范的写法。

### 2.1 命名

| 元素 | 规范 | 示例 |
|------|------|------|
| 变量 | `snake_case` | `rx_count` |
| 全局变量 | `g_snake_case` | `g_system_ticks` |
| 函数 | `camelCase` | `uartInit()` |
| 结构体/枚举类型 | `snake_case_t` | `uart_handle_t` |
| 枚举值 | `PREFIXED_SNAKE` | `UART_STATE_IDLE` |
| 常量/宏 | `SCREAMING_SNAKE` | `UART_SR_RX_READY_MASK` |
| 指针 | 项目无约定时用清晰语义名 | `rx_buffer`, `handle`；或 `p_rx_buffer` |

### 2.2 类型与错误处理

- 公共接口优先使用 `<stdint.h>`、`<stdbool.h>`、`<stddef.h>`；默认 `uint8_t` / `uint16_t` / `uint32_t`、`int32_t`、`bool`
- 不把 `int`、`char`、`long` 作为默认跨平台接口类型

项目没有既有 status 类型时，公共函数默认返回 `embedded_code_status_t`：

```c
typedef enum {
    EmbedCode_Ok          =  0,
    EmbedCode_ErrNullPtr  = -1,
    EmbedCode_ErrInvalidArg = -2,
    EmbedCode_ErrTimeout  = -3,
    EmbedCode_ErrBusy     = -4,
    EmbedCode_ErrNotInit  = -5,
} embedded_code_status_t;

#define VALIDATE_NOT_NULL(ptr) \
    do { if ((ptr) == NULL) return EmbedCode_ErrNullPtr; } while (0)

#define VALIDATE_INIT(handle) \
    do { if ((handle) == NULL || !(handle)->initialized) return EmbedCode_ErrNotInit; } while (0)
```

### 2.3 结构体模式

默认拆成配置、运行时句柄和状态：

```c
typedef struct {
    uint32_t base_address;  /* 外设基地址 */
    uint32_t baud_rate;     /* 波特率 */
} uart_config_t;

typedef struct {
    bool initialized;           /* 初始化标志 */
    volatile bool tx_busy;      /* 发送忙标志（ISR 写） */
    uint8_t *rx_buffer;         /* 接收环形缓冲区 */
    uint16_t rx_head;           /* 环形缓冲区写位置 */
    uint16_t rx_tail;           /* 环形缓冲区读位置 */
    uart_config_t config;       /* 配置参数 */
} uart_handle_t;

typedef enum {
    UART_STATE_IDLE      = 0,
    UART_STATE_TX_BUSY,
    UART_STATE_RX_ACTIVE,
    UART_STATE_ERROR,
} uart_state_t;
```

### 2.4 注释

#### 2.4.1 注释原则

- 注释语言遵循项目约定；项目无约定时可用中文或用户指定语言。
- 注释解释硬件原因、约束、时序和意图；不要逐行复述代码。
- 注释应回答"为什么"而非"是什么"——代码本身说明"是什么"，注释补充"为什么这样写"。
- 保持注释与代码同步更新；过时注释比无注释更有害。

#### 2.4.2 必须注释的场景

| 场景 | 说明 | 示例 |
|------|------|------|
| 硬件约束 | 寄存器写入顺序、时序要求、errata workaround | `/* 必须先写 CTRL 再写 DATA，否则 FIFO 错位（Errata 3.2） */` |
| 非显而易见的逻辑 | 算法选择原因、特殊边界处理 | `/* 使用查表法而非计算，节省 12 个 CPU 周期 */` |
| 临时方案 | workaround、TODO、待确认项 | `/* FIXME: 临时绕过芯片 Rev.A 的 DMA 冻结问题 */` |
| 安全关键路径 | 看门狗刷新点、冗余检查、故障注入点 | `/* 喂狗必须在 SPI 传输完成后，否则超时复位 */` |
| 并发/中断相关 | critical section、屏障、volatile 使用原因 | `/* 关中断保护 tx_tail，ISR 中会修改 */` |
| 魔数来源 | 非自明的常量值来源 | `/* 1200 = 72MHz / (16 * 3750)，参考手册 §23.4.2 */` |

#### 2.4.3 注释格式

**函数注释**（公共 API 必须有，静态辅助函数酌情）：

```c
/**
 * @brief  初始化 UART 外设并配置波特率
 * @param  handle  UART 句柄指针，调用前需填充 config 字段
 * @param  baud    目标波特率（支持 9600 / 115200 / 921600）
 * @return EmbedCode_Ok 成功；EmbedCode_ErrNullPtr handle 为空；
 *         EmbedCode_ErrInvalidArg 波特率不支持
 * @note   调用前需确保 GPIO 已配置为 AF 模式
 * @note   本函数会禁用 UART 后重新配置，不保留当前状态
 */
embedded_code_status_t uartInit(uart_handle_t *handle, uint32_t baud);
```

**内联注释**（关键行上方或同行）：

```c
/* 等待发送完成，超时防止硬件死锁（参考手册建议 ≥1ms） */
uint32_t timeout = UART_TX_TIMEOUT_MS;
while (!(UART_REG->STATUS & UART_SR_TX_EMPTY) && --timeout) {
    /* 空等：ISR 模式下此循环不应执行，保留作为 safety net */
}
```

**结构体/枚举注释**：

```c
typedef struct {
    uint8_t *rx_buffer;     /* 接收环形缓冲区，由应用层分配，驱动层不管理生命周期 */
    uint16_t rx_head;       /* ISR 写入位置（volatile），主循环只读 */
    uint16_t rx_tail;       /* 主循环读取位置，ISR 只读 */
    volatile bool tx_busy;  /* 发送忙标志，ISR 在发送完成时清零 */
} uart_handle_t;
```

**寄存器注释**：

```c
typedef struct {
    volatile uint32_t CTRL;    /* 0x00 控制寄存器：bit[0]=EN, bit[2:1]=MODE, bit[4]=IE */
    volatile uint32_t STATUS;  /* 0x04 状态寄存器：bit[0]=TX_EMPTY, bit[1]=RX_FULL, bit[3]=ERR */
    const  uint32_t RESERVED0[2];
    volatile uint32_t DATA;    /* 0x10 数据寄存器：写=TX FIFO，读=RX FIFO */
} uart_reg_t;
```

#### 2.4.4 标记约定

项目无既有约定时，必须标注以下三种标记；通用标记（`TODO`/`FIXME`/`NOTE`/`WARNING`/`HACK`/`OPTIMIZE`）按业界惯例使用即可。

| 标记 | 含义 | 何时移除 |
|------|------|----------|
| `USER_PROVIDED` | 需用户填入真实硬件值 | 用户提供信息后 |
| `PLACEHOLDER` | 临时占位值，功能正确但不完整 | 硬件信息确认后 |
| `REPO_DERIVED` | 从仓库现有代码推导，可能不准确 | 对照手册验证后 |

```c
/* USER_PROVIDED: 根据实际外部晶振频率填入 PLL 分频系数 */
/* PLACEHOLDER: 当前使用 115200，最终波特率由系统设计决定 */
/* WARNING: 修改 BAUD 寄存器值可能导致正在进行的传输损坏 */
/* FIXME: Rev.A 芯片需要额外 2 个 NOP 等待 FIFO 稳定，Rev.B 后移除 */
```

#### 2.4.5 文件头注释

- Doxygen 文件头只在项目已有模式时添加。
- 若项目需要文件头，格式如下：

```c
/**
 * @file    uart_drv.c
 * @brief   UART 驱动层：直接硬件寄存器操作，不包含业务逻辑
 * @author  （遵循项目约定）
 * @note    本文件所有函数操作硬件寄存器，单元测试时需替换为 mock 层
 */
```

### 2.5 头文件包含规范

#### 2.5.1 核心原则：Include What You Use

**每个 `.c` / `.h` 文件必须显式包含自身直接使用的符号所对应的头文件，不依赖传递包含，不保留不再使用的 `#include`。**

| 规则 | 说明 |
|------|------|
| 自包含 | 每个头文件独立可编译 — 若 `a.h` 使用了 `uint32_t`，自身必须 `#include <stdint.h>` |
| 直接包含 | 使用 `UART_HandleTypeDef` 则必须包含其定义所在头文件，不依赖其他头文件的传递 |
| 最小化 | 头文件只包含接口必须的类型，实现细节的依赖放在 `.c` 中 |
| 无冗余 | 删除不再使用的 `#include` — 重构或功能移除时同步清理 |
| 无循环 | 通过前置声明 + include guard 避免循环依赖 |

#### 2.5.2 Include 顺序

项目无既有约定时，按以下顺序分组，组间空行分隔：

```c
/* 1. 自身头文件（.c 包含自己的 .h，验证自包含） */
#include "uart_drv.h"

/* 2. 项目内头文件（按模块依赖层级，低层在前） */
#include "uart_reg.h"
#include "gpio_drv.h"

/* 3. 厂商 / RTOS / 第三方头文件 */
#include "stm32f4xx_hal.h"
#include "FreeRTOS.h"
#include "task.h"

/* 4. C 标准库头文件 */
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
```

#### 2.5.3 头文件中减少包含

头文件中优先使用**前置声明**，将 `#include` 推迟到 `.c`：

```c
/* ===== uart_drv.h ===== */
#include <stdint.h>       /* 接口用到 uint32_t → 必须包含 */
#include <stdbool.h>      /* 接口用到 bool → 必须包含 */

/* 前置声明 — 代替 #include "uart_reg.h" */
typedef struct uart_reg_t uart_reg_t;   /* 指针参数只需前置声明 */

typedef struct {
    uart_reg_t *regs;                  /* 指针，前置声明足够 */
    void (*rx_callback)(uint8_t byte); /* 函数指针 */
} uart_drv_handle_t;

/* ===== uart_drv.c ===== */
#include "uart_drv.h"
#include "uart_reg.h"   /* 实现中访问寄存器成员，这里才需要完整定义 */
```

**前置声明适用条件**：头文件仅将类型用作指针或引用（函数参数、结构体成员指针），不访问其成员、不计算 `sizeof`。

#### 2.5.4 禁止的反模式

| 反模式 | 问题 | 正确做法 |
|--------|------|----------|
| 传递依赖 | 依赖 `a.h` 间接包含的 `b.h` 中的符号 | 显式 `#include "b.h"` |
| 遗留 include | 功能已移除但 include 保留 | 删除不再使用的 `#include` |
| 万能头 | 项目中到处包含一个 `common.h` / `includes.h` | 各文件按需独立包含 |
| 头文件包含 `.c` | `#include "foo.c"` | 用 `.h` 声明接口，链接 `.c` |
| 相对路径 `../` | `#include "../module/foo.h"` | 用 `-I` 编译选项指定 include path |
| 条件编译嵌套过深 | `#ifdef` 中包含 `#ifdef` 三级以上 | 拆分为平台抽象层，每层独立头文件 |
| 循环包含 | `a.h` → `b.h` → `a.h` | 前置声明 + include guard |

#### 2.5.5 Include Guard

所有头文件必须有 include guard。项目无约定时优先 `#pragma once`；需兼容老编译器时用 `#ifndef MODULE_NAME_H_` / `#define` / `#endif` 模式。项目已使用一种时保持一致。

#### 2.5.6 嵌入式特有注意事项

- **厂商 HAL 头文件**体积庞大——驱动层 `.h` 中若仅需某个厂商类型，优先用前置声明替代包含整个 HAL 头文件。
- **ISR 文件中** include 保持最小，减少符号污染和链接器拖入。
- **代码生成工具**（STM32CubeMX 等）的 `/* USER CODE BEGIN Includes */` 区域内的 include 不混入手动区域。

---

## 3. 寄存器抽象

### 3.1 强制规则：寄存器必须定义为结构体

**所有外设寄存器块必须以 `*_reg_t` 结构体形式定义，禁止将寄存器散落为独立的 `#define` 地址宏。**

| 要求 | 说明 |
|------|------|
| 一个外设一个 `*_reg.h` | 每个外设 block 独立一个头文件，仅含寄存器结构体、位定义宏、基地址宏，无 `.c` 无函数实现 |
| 结构体命名 `*_reg_t` | 如 `uart_reg_t`、`spi_reg_t`、`dma_reg_t` |
| 使用 `volatile uint32_t` 成员 | 所有寄存器成员必须 `volatile`，确保每次访问都真正读写硬件 |
| 只读寄存器加 `const` | 状态寄存器等只读寄存器声明为 `const volatile uint32_t`，编译期阻止误写 |
| reserved 区域显式填充 | 寄存器间的保留空间用 `const uint32_t RESERVED[n]` 占位，确保偏移正确 |
| 一个明确的基地址入口 | 通过 `*_REG` 宏或项目已有 wrapper 访问，不裸写地址转换 |
| 位字段用 `MASK/SHIFT` 宏 | 每个位域定义 `_MASK` 和 `_SHIFT` 宏，不写魔法数字 |

**为什么必须用结构体而非宏**：结构体由编译器计算偏移，基地址一变全变；`RESERVED[n]` 自动占位不留间隙；`const volatile` 编译期拦截只读寄存器误写。散落 `#define` 地址宏手算偏移极易错位且无任何保护。

### 3.2 标准模板

```c
/* ===== 寄存器结构体 — 成员顺序 = 硬件地址升序 ===== */
typedef struct {
    /* --- 0x00 --- */
    volatile uint32_t CTRL;          /* 控制寄存器：bit[0]=EN, bit[2:1]=MODE, bit[4]=IE */
    const    uint32_t RESERVED0[3];  /* 0x04~0x0C 保留，禁止访问 */
    /* --- 0x10 --- */
    const    volatile uint32_t STATUS;  /* 状态寄存器：只读，bit[0]=TX_EMPTY, bit[1]=RX_FULL */
    volatile uint32_t DATA;          /* 数据寄存器：写=TX FIFO，读=RX FIFO */
    volatile uint32_t BAUD;          /* 波特率寄存器：BAUD = PCLK / (16 × target_rate) */
} uart_reg_t;

/* ===== 基地址宏 — 来自芯片参考手册 ===== */
#define UART1_BASE_ADDR  (0x40001000U)  /* USER_PROVIDED: 以芯片手册 Memory Map 为准 */

/* ===== 寄存器入口 — 全局唯一访问点 ===== */
#define UART1_REG  ((uart_reg_t *)UART1_BASE_ADDR)

/* ===== 位定义宏 — CTRL 寄存器 ===== */
#define UART_CTRL_EN_MASK     (1U << 0)
#define UART_CTRL_EN_SHIFT    (0U)
#define UART_CTRL_MODE_MASK   (3U << 2)
#define UART_CTRL_MODE_SHIFT  (2U)
#define UART_CTRL_IE_MASK     (1U << 4)
#define UART_CTRL_IE_SHIFT    (4U)

/* ===== 位定义宏 — STATUS 寄存器 ===== */
#define UART_STATUS_TX_EMPTY_MASK  (1U << 0)
#define UART_STATUS_RX_FULL_MASK   (1U << 1)

/* ===== 寄存器操作 helper 宏（可选，放 _reg.h 尾部） ===== */
#define REG_SET_BITS(reg, mask, value)  \
    ((reg) = ((reg) & ~(mask)) | ((value) << (mask##_SHIFT)))
#define REG_GET_BITS(reg, mask)         \
    (((reg) & (mask)) >> (mask##_SHIFT))
```

### 3.3 结构体成员布局规范

1. **成员顺序**必须与硬件寄存器地址升序一致，偏移隐含在结构体布局中。
2. **reserved 区域**用 `const uint32_t RESERVEDn[count]` 显式占位，注释注明地址范围。
3. **只读寄存器**声明为 `const volatile uint32_t` — 只读约束由编译器在编译期检查。
4. **读写寄存器**声明为 `volatile uint32_t`。
5. **写-only 寄存器**声明为 `volatile uint32_t`（C 语言无 write-only 限定符，靠注释说明）。
6. **多字节访问**的寄存器组（如 64-bit timer counter）使用连续两个 `uint32_t` 成员，注释标注 low/high。
7. 若同一地址存在**读/写含义不同**的寄存器对（如读=FIFO 数据，写=TX 数据），使用两个成员 `DATA_RD` 和 `DATA_WR` 并注释说明实际为同一地址。

### 3.4 寄存器使用方式

```c
/* ✅ 正确：通过结构体访问 */
UART1_REG->CTRL |= UART_CTRL_EN_MASK;
uint32_t status = UART1_REG->STATUS;
UART1_REG->DATA = tx_byte;

/* ✅ 正确：read-modify-write 通过结构体 + mask */
uint32_t ctrl = UART1_REG->CTRL;
ctrl &= ~UART_CTRL_MODE_MASK;
ctrl |= (UART_MODE_ASYNC << UART_CTRL_MODE_SHIFT);
UART1_REG->CTRL = ctrl;

/* ❌ 禁止：裸地址宏散落在业务逻辑中 */
#define UART1_CTRL  (*(volatile uint32_t *)0x40001000U)
#define UART1_DATA  (*(volatile uint32_t *)0x40001010U)
UART1_CTRL = 0x01;
UART1_DATA = tx_byte;
```

### 3.5 复用 vendor/CMSIS 已有结构体的例外

若项目已使用 CMSIS 或厂商 SDK 提供的寄存器结构体（如 `USART_TypeDef`、`SPI_TypeDef`），则**直接复用**，不再自定义 `*_reg_t`。此时只需补充：
- 缺失的位定义 `MASK/SHIFT` 宏
- 寄存器入口宏 `*_REG`（若 SDK 未提供）

```c
/* 复用 STM32 CMSIS 结构体，仅补充位定义 */
#define UART_SR_RXNE_MASK   USART_SR_RXNE
#define UART_REG            (USART1)
```

**不可既自定义结构体又同时用裸地址宏来描述同一外设的寄存器。**

---

## 4. 驱动模板

驱动模板用于组织代码，不是厂商级寄存器头文件。所有真实 offset、reserved bit、reset 值、时序和 errata 必须来自目标资料。

每个外设模块按**三层五文件**组织：寄存器层（纯定义）→ 驱动层（硬件操作）→ 应用层（业务 API）。

### 4.1 统一结构

```text
module/
├── module_reg.h    # 寄存器结构体、位定义、基地址宏 — 无 .c，无函数实现
├── module_drv.h    # 驱动层：寄存器读写、ISR、DMA  — 不含业务逻辑、不分配 buffer
├── module_drv.c
├── module.h        # 应用层：缓冲管理、协议处理、对外 API — 不直写寄存器、不含 ISR
└── module.c
```

调用链：应用层 → 驱动层 → 寄存器层。驱动层 ISR 通过函数指针回调通知应用层，不直接操作 ring buffer。

### 4.2 接口模板

| 模块 | 驱动层 (`_drv.h`) | 应用层 (`.h`) |
|------|-------------------|---------------|
| UART | `uartDrvInit/DeInit/SendByte/RecvByte/EnableIRQ/IRQHandler` | `uartInit/DeInit/Send/Recv/SendIT/RecvIT/SendDMA/RecvDMA` |
| SPI | `spiDrvInit/Transfer/SetCS/IRQHandler` | `spiInit/Transfer/SelectCS/TransferIT/TransferDMA` |
| GPIO | `gpioDrvInit/WritePin/ReadPin/TogglePin/IRQHandler` | `gpioInit/WritePin/ReadPin/TogglePin/SetCallback` |
| DMA | `dmaDrvChannelInit/Start/Abort/IsComplete/IRQHandler` | `dmaChannelInit/StartTransfer/AbortTransfer/IsTransferComplete` |

**Init 模式（驱动层）**：禁用外设 → 配置参数（值来自厂商或 PLACEHOLDER）→ 清挂起标志 → 使能 → 标记 initialized

**ISR 模式（驱动层）**：读 STATUS → 按 mask 分支 → 回调通知应用层 → 清中断标志 → 从不阻塞

### 4.3 关键结构

| 模块 | 寄存器 | 驱动层 handle | 应用层 handle |
|------|--------|--------------|--------------|
| UART | `DATA, STATUS, CTRL, BAUD` | `regs, rx/tx_callback` | `rx_buffer, rx_head, rx_tail, drv_handle` |
| SPI | `CTRL, STATUS, DATA, BAUD` | `regs, cs_callback` | `drv_handle` |
| I2C | `CTRL, STATUS, ADDR, DATA` | `regs, addr, direction` | `timeout, bus_state, drv_handle` |
| DMA | `GLOBAL_STATUS, ch[n].CTRL/SRC/DST/LEN` | `regs, channel_cfg[]` | `buffers[], drv_handle` |
| CAN | `CTRL, STATUS, BIT_TIMING, TX/RX_DATA` | `regs, bit_timing` | `can_msg_t{id,dlc,data[8]}, drv_handle` |
| GPIO | `MODE, INPUT/DATA, OUTPUT_DATA, BIT_SET_RESET` | `regs, pin_map` | `pin_callbacks[], gpio_mode_t, drv_handle` |
| Timer | `CTRL, COUNT, AUTO_RELOAD, PRESCALER` | `regs, prescaler, auto_reload` | `period, callback, drv_handle` |
| Watchdog | `KEY, RELOAD, STATUS` | `regs, key_reg` | `timeout_ms, drv_handle` |
| MIL-STD-1553 | `CMD, STATUS, DATA[n]` | `regs, mode` | `msg_t, drv_handle` |

**反模式**：寄存器散落成地址宏、应用层直写寄存器、驱动层分配 buffer/处理协议帧、ISR 中阻塞。

---

## 5. 架构规则

架构相关代码包括 ISR、barrier、DMA、cache、interrupt controller、memory ordering 和 board bring-up。

### 5.1 Quick Ref

| 架构 | Barrier | Interrupt | 代表芯片 |
|------|---------|-----------|---------|
| ARM Cortex-M | `__DMB()/__DSB()/__ISB()` | NVIC | STM32, GD32, NXP, RP2040 |
| RISC-V | `fence` | PLIC/CLINT | FE310, CH32V |
| ESP32 (Xtensa) | `esp_cpu_dsb()` | INT matrix | ESP32, S2/S3 |

> 其他架构（Cortex-A、PowerPC、SPARC）和平台细节（ESP32 IRAM_ATTR、nRF52 SoftDevice、RP2040 Pico SDK）仅在用户明确提及该芯片时才查阅对应文档，不在此展开。

### 5.2 未知架构处理

1. 根据芯片、工具链、vendor headers 和已有低层代码判断架构
2. 不确定时查官方文档或要求用户提供资料
3. 不能确认时，只生成架构无关 C 骨架，barrier/interrupt/cache maintenance 标成 placeholder
4. 不猜测 barrier、cache maintenance、DMA ownership、IRQ number 或 interrupt-controller 行为

---

## 6. RTOS 场景速查

裸机项目跳过本节。RTOS 项目仅在用户明确后才应用以下规则（不主动引入 RTOS 依赖）：

- **ISR 规则**：禁止阻塞（不调用 `osDelay`/`osMutexAcquire`），FreeRTOS 用 `...FromISR()` API，只做读状态→清标志→通知任务
- **数据共享**：任务间用互斥量，ISR→任务用队列，简单标志用 `<stdatomic.h>`
- **死锁预防**：固定锁顺序、超时替代无限等待、持锁不调阻塞 API
- **常用 RTOS**：FreeRTOS / Zephyr / RT-Thread 的 API 对照仅在用户指定 RTOS 时提供

---

## 7. 构建系统与链接

### 7.1 Linker Script 与 Startup

```
Reset_Handler：搬运 .data（Flash→RAM）→ 清零 .bss → SystemInit() → main()
```

MEMORY 中 FLASH 放 `.text`/`.rodata`，RAM 放 `.data`/`.bss`；`__data_start/end` 和 `__bss_start/end` 符号供 startup 引用。

### 7.2 编译器 Attribute

| 用途 | 写法 |
|------|------|
| 中断函数 | `__attribute__((interrupt("IRQ")))` |
| 指定 section | `__attribute__((section(".dma_buf")))` |
| 对齐 | `__attribute__((aligned(32)))` |
| 弱符号 | `__attribute__((weak))` |
| 始终内联 | `__attribute__((always_inline))` |

### 7.3 构建工具

交叉编译 CMake 模板仅在用户使用 CMake 时提供（`CMAKE_SYSTEM_NAME Generic` + `arm-none-eabi-` toolchain）；Makefile/Keil/IAR 按项目现有构建系统沿用。

---

## 8. 测试与调试

### 8.1 HAL Mock 模式

通过函数指针表实现可替换 HAL：生产用 `uart_hal_hw`，测试用 `uart_hal_mock`。

```c
typedef struct {
    void    (*init)(const config_t *);
    status_t (*send)(const uint8_t *, uint16_t);
} uart_hal_t;
```

### 8.2 断言分级

- `STATIC_ASSERT(cond, msg)` → `_Static_assert`，编译期检查（寄存器偏移、结构体大小）
- `ASSERT(cond)` → 运行时，仅在 debug build 生效
- `SOFT_ASSERT(cond, action)` → 生产代码不 crash，记录错误后执行 action

### 8.3 裸机调试要点

- 保留至少 1 个 GPIO 用于 SWO/printf 或逻辑分析仪触发
- 栈溢出检测：栈底填 watermark pattern，定期检查
- 日志级别 ERROR > WARN > INFO > DEBUG，生产固件只保留 ERROR

---

## 9. 行业领域

仅在用户或项目资料明确标准（DO-178C / ISO 26262 / IEC 61508 / MIL-STD）时才应用对应规则，**不默认声明任何认证等级或合规结论**。通用裸机项目不主动引入行业约束。

---

## 10. 内存、安全和并发默认值

- 低层驱动、ISR 和 hot path 默认不用 `malloc/free/calloc/realloc`
- 禁止 VLA；缓冲区大小、timeout、retry count 使用命名常量
- critical section 要短、显式，沿用项目本地 helper
- ISR、DMA、cache coherency、volatile 和 memory ordering 必须保留硬件相关顺序
- 不发明 barrier、cache maintenance、DMA ownership 或 interrupt-controller 细节

---

## 11. 反例集

**1. 寄存器散落为地址宏**：❌ 每个寄存器独立 `#define` 地址宏 → ✅ 一个 `*_reg_t` 结构体 + 基地址宏（详见第 3 节）

**2. DMA cache coherency**：❌ 直接 DMA 读写无 cache 处理 → ✅ `SCB_InvalidateDCache_by_Addr()` 或放 non-cacheable section

**3. ISR 阻塞**：❌ `osSemaphoreAcquire(uart_sem, osWaitForever)` → ✅ `xSemaphoreGiveFromISR()` + `portYIELD_FROM_ISR()`

**4. volatile 漏用**：❌ `bool g_transfer_done; while(!g_transfer_done){}` → ✅ `volatile bool g_transfer_done;`

**5. 优先级反转**：❌ `xSemaphoreCreateBinary()` 保护共享资源 → ✅ `xSemaphoreCreateMutex()` 优先级继承

---

## 12. 回查清单与维护自检

### 12.1 回查清单

- [ ] 仓库已有代码符合本规范则沿用，不符合则在不改变逻辑的前提下修改
- [ ] 硬件常量来自用户、仓库或 placeholder
- [ ] 不编造寄存器/IRQ/barrier/cache 规则
- [ ] 每个外设寄存器块均已定义为 `*_reg_t` 结构体（非散落 `#define` 地址宏）
- [ ] reserved 区域已用 `RESERVED[n]` 占位，只读寄存器已加 `const`
- [ ] 复用 vendor/CMSIS 结构（若项目已有）
- [ ] 无裸寄存器地址散落在业务逻辑，所有寄存器访问通过结构体成员
- [ ] 无冗余/传递依赖的 `#include`，include 顺序符合规范
- [ ] 无默认动态内存和 VLA
- [ ] 命名/类型/错误处理符合本 skill 规范
- [ ] REWRITE 保留行为/ABI/时序顺序
- [ ] REVIEW correctness 和硬件风险优先于风格
- [ ] ISR 无阻塞，RTOS 用 FromISR API
- [ ] DMA buffer 处理 cache coherency
- [ ] 共享变量正确使用 volatile/atomic/互斥量

### 12.2 维护自检

修改本 skill 后，用以下场景做 smoke check：

- `REWRITE`：保留 public API、ABI、寄存器写入顺序
- `REVIEW`：优先指出 race/volatile/barrier/ownership 风险
- RTOS：共享数据有互斥保护，ISR 只用 FromISR
- 领域：DO-178C/MIL-STD/IEC 61508/ISO 26262 只在用户明确时写合规结论

通过标准：不编造硬件事实、仓库代码符合本规范或在不改变逻辑前提下统一、子领域无丢失或矛盾。
