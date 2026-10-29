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

- 一个内核（`mathc`），单个 OCaml 二进制，外加传递依赖模块。
- 八条原则，每一条都以数据包的形式记录在
  `decisions/` 中，并可通过 `tests/cli/` 中的 cram
  固定样本进行验证。
- 一个静态站点（`site/`），由 `mathc render` 生成，
  部署到 GitHub Pages。

## 五条公理与三条扩展

八个引导数据包是主策略的义务；规范清单见
`decisions/decision.yaml`。
[Foundations](foundations.html) 给出了每条公理到内核机制与
验证义务的完整映射。

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

完整的子命令目录与退出码在 `spec/semantics.md`
（§CLI subcommands）中具有规范效力。

## 文件位置

`PACKAGES.md` 是关于本仓库内容的唯一可信来源。

## 另请参阅

- [Manifesto](manifesto.html) —— 缘何存在。
- [Methodology](methodology.html) —— 这门纪律。
- [Axioms](axioms.html) —— 五条公理。
- [Foundations](foundations.html) —— 公理 → OCaml。
- [Workflow](workflow.html) —— 六步循环。
- [FAQ](faq.html) —— 最常被问到的问题。
- [Contributing](contributing.html) —— 如何贡献。
- [Packages](packages.html) —— 实时的保障表面。
- `KERNEL_AGENTS.md` —— 智能体协议。
- `ROADMAP.md` —— 优先级队列。
- `PACKAGES.md` —— 关于仓库内容的唯一可信来源。

## 许可证

Apache-2.0。参见 `LICENSE` 与 `NOTICE`。