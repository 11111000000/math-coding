# 工作流

> **从意图到修订。** math-coding 工作流是源自
> `decisions/decision.yaml` 的有限状态机，作为一门
> 纪律加以贯彻。六个步骤，一个二进制。

![单条 math-coding 记录的生命周期有限状态机：7 个状态（草稿、已承诺、已实现、已证据、已观察、争议中、已退役）、6 个主转移、4 个阻断标记（违规、宽限、过期、豁免失效）。](assets/lifecycle-fsm.svg)

上图即是工作流。下面的六个步骤分别对应状态机中的
一个转移：state intent → commit → implement → attest →
gate → self_verify → merge 到 main。阻断标记（违规、
宽限、过期、豁免失效）是可能打断某一状态、并强制回退
到更早状态的四种情形。

## 1. 陈述意图

打开 `decisions/<id>.yaml` 并写入 `intent:`。意图是
「为什么」；「承诺」紧随其后。没有意图的记录，是关于
空无的记录。

```yaml
intent: |
  增加关于「决策 — 义务」判定的结构化日志，使评审者无需
  重读内核即可回答「这次合并是否安全」。
```

## 2. 承诺

承诺即**可证伪的断言**。`obligation` 块指明验证方式：

```yaml
commitment: |
  mathc packages --format=html 渲染出一张带有判定的
  「决策 — 义务」HTML 网格。
obligation:
  - id: packages-kernel-walker
    acceptance:
      all:
        - verifier: mathc packages --format=json
          result: pass
```

`commit` 到 `implement` 的转移受规则「每一项义务均具备
正、反两份固定样本」约束。上述义务具备正向验收条款
（`verifier: mathc packages --format=json, result: pass`）；
对应的反向条款（即 `result: fail` 的用例，断言验证器会
拒绝一份格式错误的决策）在步骤 4（Attest）中补齐之后，
`implement → attest` 的转移才变为可达。

## 3. 实现

修改 `lib/packages.ml` 与 `bin/Mathc.ml` 以兑现承诺。
实现保持纯 OCaml、无副作用，约 700 行外加二进制。

## 4. 证据

每次实现之后运行 `scripts/generate-attestations.py`。
脚本会为每一对包裹生成
`attestations/<sha>.json`。提交这些 JSON 文件。

## 5. 闸门

`mathc gate BASE HEAD` 基于已填充的存储运行。退出码
为 `0` 表示「过」，`1` 表示「阻断」，`3` 表示「未知」。
CI 中的阻断步骤即为 `mathc self-check`。

## 6. 自验证

`mathc self-check` 作用于**整个**决策图。其退出码决定
能否合并到 `main`。`self-check` 的 JSON 中包含
`verdict`、`subjects_count`、`pass_count` 以及
`kernel_digest`（产生该判定的二进制的 SHA-256 摘要）。

![引导时间轴：从 v3-alpha-0.0.1 到 8fa7fcf（v3.0.0.19），再到今日。人工机制止于 8fa7fcf；自动机制自同一提交起生效。](assets/bootstrap-timeline.svg)

上面的引导时间轴展示了同一工作流如何被应用到这个项目
自身。从 `v3-alpha-0.0.1` 到提交 `8fa7fcf`，每一次转移
都由人类评审员放行（人工机制）；自 `8fa7fcf` 起，放行者
变为内核。两套机制的边界，就是本工作流中的
`mathc self-check` 步骤。

## 一个完整的示例

关于添加 `mathc packages` 的决策，在提交 `5d1046a` 中
走完了六个步骤：

| 步骤 | 提交 | 验证器 |
|------|------|--------|
| 1. 陈述意图 | `mathc-packages-subcommand@1` | `intent:` 块 |
| 2. 承诺 | 同上 | `commitment:` + `obligation:` |
| 3. 实现 | `lib/packages.ml`、`bin/Mathc.ml` | `dune build` 退出码 0 |
| 4. 证据 | `attestations/mathc-packages-subcommand-*.json` | `mathc packages --format=json` |
| 5. 闸门 | `tests/cli/gate-{pass,fail,stale}.t` | cram 绿 |
| 6. 自验证 | `tests/cli/self-check-pass.t` | cram 绿 |

六步循环即是内核将 A3 应用于自身。形式化表述见
[Axioms](axioms.html)。