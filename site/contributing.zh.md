# 参与贡献

> **协议自指其身。** 触及内核、章程、模式或权限规则的
> 拉取请求遵循 `KERNEL_AGENTS.md` §Self-application。触及其他
> 任何内容的拉取请求遵循工作链。

## 工作链

```text
意图 -> 决策 -> 义务 -> 变更 -> 证据 -> 修订
```

`main` 上的每一次提交至少闭合一项义务。任何义务都不
会在缺少正向+负向装置的情况下闭合。任何内核变更都
不会在没有 `decisions/*.yaml` 决策（处于活跃策略下）
的情况下交付。

## 分支

- **Tier 1+**：从 `main` 创建功能分支，命名为
  `<group>/<slug>`（例如 `site/tufte-redesign`、
  `mathc/packages-html`）。
- **Tier 3+**：按 `OCAML_KERNEL_CONVENTIONS.md` §P4 合并
  顺序拆分为多个 PR：先决策，后装置，再纯内核帮助函数，
  最后 `bin/Mathc.ml`。
- **工作树优先**：每一次变更都发生在 git 工作树中
  （参见 `worktree-first` 技能）。

## 提交前检查

在 `git commit` 之前运行 `scripts/dev verify`。它会
执行：

1. `pkill` 残留的 `dune`/`nix develop`（清理 `_build/.lock`）
2. `dune build`
3. `dune test`
4. `scripts/fmt-check.sh`
5. `scripts/check.sh`

每一步相互独立，因此第 3 步失败不会跳过第 4 步。总耗时
约 30–60 秒。

## 受保护策略变更

对章程、内核、闸门规则、权限规则或豁免规则的变更要求满足
受保护变更清单。该清单具有规范效力，并且只存一处：
`KERNEL_AGENTS.md` §Self-application。

## Conventional Commits 前缀

使用 `Conventional Commits` 编写提交主题（≤72 字符）：

```
feat(scope): summary
fix(scope): summary
refactor(scope): summary
docs(scope): summary
chore(scope): summary
attestations: ...
ci: ...
```

PR 标题遵循同一约定。`scope` 字段应命名受影响的包或
内核模块（例如 `mathc-self-check`、`lib/render`、
`bin/Mathc`、`decisions/site-deploy` 等）。

## 时间诚实的提交

任何提及持续时间的提交消息都需要附带一段括号注释，
指明所采用的尺度与参考类：

```text
feat(kernel): 添加风险分类器（kernel-change p95≈150min，
  ref: SWE-bench-V 2025-Q4）
```

反模式（维护者将拒绝）：

- "花了两天在这上面。"——未记录会话起点的 wall-clock-
  minutes 声明。
- "快速修复，几分钟的事。"——未记录具体值的持续时间
  声明。
- "一周深思熟虑的工作。"——将 wall-clock 与主观关注
  混为一谈。

## 琐碎提醒

- 所有决策必须包含 frontmatter（`schema`、`id`、
  `revision`）；格式见 `decisions/decision.yaml`。
- 所有义务必须声明一个验证器；参见
  `OCAML_KERNEL_CONVENTIONS.md` §2.4 中 `acceptance:` 块的
  约定。
- 所有 cram 装置位于 `tests/cli/*.t`；切勿重建
  `tests/cram/`。
- 所有时间估计须通过 `mathc time-estimate` 引用
  `bin/data/time-distribution.yaml` 中的参考类。

## 卡住时

OCaml 陷阱日志位于 `OCAML_KERNEL_CONVENTIONS.md` §11。在
新增任何内容前先阅读它。如果下一个 bug 不在其中，请
修复根本原因，并在合并前追加一条新的陷阱条目。

## 另请参阅

- 在 [README](readme.html) — 项目简介。
- 在 [Workflow](workflow.html) — 六步循环。
- 在 [FAQ](faq.html) — 我们最常被问到的问题。
- 在 `KERNEL_AGENTS.md` §Self-application — 受保护策略的清单。
- 在 `OCAML_KERNEL_CONVENTIONS.md` — OCaml 约定。
