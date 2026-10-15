# math-coding

> **一门在编写代码之前先记录决策的纪律。** 内核是一个
> 单一的静态二进制文件；数据包是纯文本，存放在
> `decisions/` 中；判定由 `mathc gate` 和 `mathc self-check`
> 产生。

## 它是什么

math-coding 将一项具体变更与它可能影响到的义务、以及
关于这些义务的有限证据联系起来。它并不证明软件的
正确性。工作链如下：

```text
intent -> decision -> obligation -> change -> attestation -> revision
```

每一项架构承诺都在代码之**前**写下，内核在每次合并
时核对承诺与代码是否一致。这门纪律称为
**mathcoding** —— 将 math-coding 作为方法论加以应用。

## 它交付什么

- 一个内核（`mathc`），单个 OCaml 二进制，约 700 行
  外加传递依赖模块。
- 八条原则，每一条都以数据包的形式记录在
  `decisions/` 中，并可通过 `tests/cli/` 中的 cram
  固定样本进行验证。
- 一个静态站点（本文档），由 `mathc render` 生成，
  部署到 GitHub Pages。

## 五条公理与三条扩展

| 组别 | 原则 | 它断言的内容 |
|------|------|--------------|
| 基础 | `bootstrap-v3` | 内核能够检查本仓库 |
| 基础 | `kernel-conformance-runner` | 每个固定样本都被枚举并运行 |
| 基础 | `validate-and-context` | 每个决策都能解析并暴露出胶囊 |
| 基础 | `gate-decision` | 闸门判定可由机器检查 |
| 基础 | `attestation-store-fill` | 证据存储已被填充 |
| 扩展 | `mathc-explain-subcommand` | `mathc explain` 可解析 `decision:` 引用 |
| 扩展 | `mathc-self-check-subcommand` | `mathc self-check` 返回自动判定 |
| 扩展 | `mathc-packages-subcommand` | `mathc packages` 是一等公民表面 |

参见 [Foundations](foundations.html)，了解每条公理到
内核机制与验证义务的完整映射。

## 快速开始

```sh
nix develop .#test
dune build
dune test
mathc self-check     # 输出 JSON 判定；退出码 0 = 通过
```

在本地渲染站点：

```sh
scripts/render.sh         # 构建 mathc，运行 `mathc render`，
                          # 校验 dist/ 白名单
python3 -m http.server -d dist/ 8000
# 打开 http://localhost:8000/
```

## 命令

| 命令 | 用途 |
|------|------|
| `mathc validate FILE` | 将 FILE 解析为一项决策 |
| `mathc context BASE HEAD --budget N` | 输出 JSON 上下文胶囊 |
| `mathc explain DETAIL_REF` | 将 `decision:<id>` 解析为正文 |
| `mathc assess BASE HEAD` | 列出变更的文件路径 |
| `mathc attest FILE` | 解析 JUnit XML 报告 |
| `mathc time-estimate --class ... --count N` | 基于参考类进行预测 |
| `mathc gate BASE HEAD` | 基于证据存储的闸门判定 |
| `mathc self-check` | 自动化自验证 |
| `mathc packages --format=text\|json\|html` | 包裹网格 |
| `mathc render [--lang en\|ru\|both]` | 渲染静态站点 |

## 文件位置

| 路径 | 内容 |
|------|------|
| `lib/` | 纯 OCaml 内核模块 |
| `bin/` | `mathc` 命令行调度器 |
| `decisions/` | 决策与义务数据包（保障表面） |
| `attestations/` | 以 SHA 为键的证据（证据表面） |
| `axioms/` | 五条公理的 Markdown 文档 |
| `spec/` | 宪法 + 语义 + 代数（形式化层） |
| `site/` | 已发布的散文，提供英文与俄文版本 |
| `tests/cli/*.t` | 命令行的 cram 固定样本 |
| `tests/*.ml` | 内核单元测试与一致性测试 |

## 另请参阅

- [Manifesto](manifesto.html) —— 缘何存在。
- [Methodology](methodology.html) —— 这门纪律。
- [Axioms](axioms.html) —— 五条公理。
- [Foundations](foundations.html) —— 公理 → OCaml。
- [Workflow](workflow.html) —— 六步循环。
- [FAQ](faq.html) —— 最常被问到的问题。
- [Contributing](contributing.html) —— 如何贡献。
- [Packages](packages.html) —— 实时的保障表面。
- `AGENTS.md` —— 智能体协议。
- `ROADMAP.md` —— 优先级队列。
- `PACKAGES.md` —— 关于仓库内容的唯一可信来源。

## 许可证

Apache-2.0。参见 `LICENSE` 与 `NOTICE`。