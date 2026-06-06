# embedded-code-skill

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License: MIT" />
  <img src="https://img.shields.io/badge/language-C-A8B9CC?style=flat-square&logo=c&logoColor=white" alt="C" />
  <img src="https://img.shields.io/badge/OpenAI%20Codex-412991?style=flat-square&logo=openai&logoColor=white" alt="OpenAI Codex" />
  <img src="https://img.shields.io/badge/Claude%20Code-5678a0?style=flat-square&logo=anthropic&logoColor=white" alt="Claude Code" />
  <img src="https://img.shields.io/badge/Cursor-7C3AED?style=flat-square&logo=cursor&logoColor=white" alt="Cursor" />
  <img src="https://img.shields.io/static/v1?label=&message=VSCode&logo=visualstudiocode&logoColor=ffffff&color=007ACC&style=flat-square" alt="VSCode" />
  <img src="https://img.shields.io/badge/RTOS-FreeRTOS%20%7C%20Zephyr%20%7C%20RT--Thread-orange?style=flat-square" alt="RTOS" />
</p>

> 嵌入式 C 的 REWRITE/REVIEW/GUIDE：三层整理、低层审查、RTOS/构建咨询。硬件参数须有出处。

[简体中文](README.md) · [English](README_EN.md) · [日本語](README_JP.md)

---

## 做什么

- **REWRITE**：整理旧驱动代码，保持寄存器写入顺序和时序
- **REVIEW**：审查 ISR/DMA/cache/竞态风险，输出问题表
- **GUIDE**：RTOS 任务设计、CMake 配置、调试策略等咨询

**不是芯片手册**，不替代寄存器手册、IRQ 表或认证资料。

---

## 核心原则：三层解耦

REWRITE/REVIEW 必须遵守三层架构：

```
┌──────────────────────────────────────┐
│  应用层 (module.h / module.c)        │
│  缓冲管理、协议、对外 API              │
│  ✗ 不直写寄存器  ✗ 不含 ISR           │
├──────────────────────────────────────┤
│  驱动层 (module_drv.h / .c)          │
│  寄存器读写、ISR、DMA                 │
│  ✗ 不含业务逻辑  ✗ 不分配 buffer       │
│  → ISR 通过回调通知应用层              │
├──────────────────────────────────────┤
│  寄存器层 (module_reg.h)             │
│  结构体、位定义、基地址宏              │
│  ✗ 无函数实现  ✗ 无业务代码           │
└──────────────────────────────────────┘
```

五文件：`module_reg.h` → `module_drv.h/.c` → `module.h/.c`

---

## 快速开始

```bash
# REWRITE：整理 UART 驱动，保留寄存器写入顺序
/ecs 整理这段 UART 驱动，按三层架构拆分

# REVIEW：审查 DMA ISR 风险
/ecs 审查这段 DMA ISR 是否有竞态或 cache 问题

# GUIDE：RTOS 任务设计
/ecs 设计 FreeRTOS 任务优先级和栈大小
```

---

## RED LINES（禁止）

1. 禁伪造硬件参数（寄存器/IRQ/屏障/时序）
2. 禁低层 `malloc` / VLA
3. 禁公共接口用 `int`/`char`/`long`
4. 禁业务代码散落裸寄存器地址
5. 禁不可编译的输出
6. **禁违反三层解耦**

---

## 安装

```bash
./install.sh          # ~/.codex/skills/embedded-code-skill/
./install.sh cursor   # ~/.cursor/skills/embedded-code-skill/
./install.sh claude   # ~/.claude/skills/embedded-code-skill/
```

---

## 章节导航

| 章节 | 内容 |
|------|------|
| §1 | 定位、使用原则、工作模式、RED LINES |
| §2 | 编码规范（命名、类型、错误处理、数据结构、注释） |
| §3 | 寄存器抽象（分层结构体、`MASK/SHIFT`） |
| §4 | 驱动模板（三层五文件、接口规范） |
| §5 | 架构规则（Cortex-M/A、ESP32、RISC-V 等） |
| §6 | RTOS 指导（FreeRTOS/Zephyr/RT-Thread） |
| §7 | 构建系统（链接脚本、CMake） |
| §8 | 测试与调试 |
| §9 | 行业领域（航空/军工/工业/汽车） |
| §10-12 | 内存与并发、反例集、回查清单 |

详细规范请阅读 [SKILL.md](SKILL.md)。

---

## 许可

MIT License
