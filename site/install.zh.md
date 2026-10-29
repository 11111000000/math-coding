# 安装 math-coding

> 四条通往可工作 `mathc` 二进制文件的途径。选择与你的
> 环境匹配的那一条；四条途径交付相同的 release 制品，
> 以 SHA-256 标识。

math-coding 通过四个相互独立的安装渠道交付。每个渠道
都来自同一构建产出的同一个 `mathc` 二进制；渠道之间的
区别在于二进制如何到达主机，以及渠道对主机环境的
预设范围。

## 选择你的渠道

> 原生渠道优先；Docker 作为后备。若任何原生渠道都不可用，请参见下方 [如果原生安装失败](#如果原生安装失败)。

| 渠道 | 使用场景 | 安装命令 |
|------|----------|----------|
| Release binary | 默认。Linux glibc ≥ 2.35、macOS 或 WSL。 | `curl -fsSL https://github.com/11111000000/math-coding/releases/download/v${VERSION}/install.sh \| sh` |
| Docker image | 没有 sudo、无可写 `~/.local/`、受限的 CI runner，或你需要一次密封运行。 | `docker run --rm -v "$PWD:/repo" ghcr.io/11111000000/mathc:${VERSION} validate decisions/foo.yaml` |
| Nix run | 你已安装 Nix ≥ 2.18 并启用了 flakes，且偏好 zero-install。 | `nix run github:11111000000/math-coding -- validate decisions/foo.yaml` |
| Source build | 你正在修改 `lib/` 或 `bin/`。 | `nix develop .#test && dune build --root . bin/mathc.exe` |

Release binary 是默认推荐渠道，原因有二：(a) 安装脚本
针对 SHA-256 对照同一 release 中发布的 `SHA256SUMS` 进行
校验下载的二进制，防御网络 MITM；(b) 脚本在同一次调用
中还会安装 per-user opencode 技能（`--user-skill`）。

## 如果原生安装失败

如果 `curl | sh`、Windows 安装程序、`nix run` 或源码
构建在你的主机上不可用（公司代理屏蔽
`raw.githubusercontent.com`、Alpine/musl libc、不可写入
`~/.local/` 的不可变 CI runner），Docker 镜像就是
始终可用的后备通道。镜像
`ghcr.io/11111000000/mathc:<VERSION>` 由本仓库的 CI
在每次发布 tag 推送时构建并签名；无需在主机上安装。

```sh
docker run --rm -v "$PWD:/repo" \
  ghcr.io/11111000000/mathc:<VERSION> \
  validate decisions/foo.yaml
```

同一命令可用于任何子命令。把 `<VERSION>` 替换为发布
tag（例如 `v3.3.0`），或替换为 `edge` 以获得 main 上
最新提交。`:edge` tag 会在每次推送到 main 时重建并
重新发布；每日健康检查 workflow 会断言镜像仍然可以
运行。

## 面向 AI 代理

代理技能存在两条安装路径，与二进制镜像对称：

- **Per-repo（按仓库）**：将 release 的
  `dist-adoption.tar.gz` 中的
  `dist/adoption/opencode/SKILL.md` 复制到目标仓库的
  `.opencode/skills/math-coding/SKILL.md`。这将为该仓库
  的代理会话钉住一个具体的 math-coding 版本。

- **Per-user（按用户）**：向 `install.sh` 传入
  `--user-skill`。技能将落在
  `${XDG_CONFIG_HOME:-${HOME}/.config}/opencode/skills/math-coding/SKILL.md`
  并应用于该主机上跨所有仓库的所有 opencode 会话。
  在 math-coding 发布后使用 `--upgrade` 重新运行。

Per-repo 路径是有文档化的生产契约：技能的 `compatible_with:
mathc@>=X.Y.Z` frontmatter 字段
（`adoption/SKILL.md:188`）强制版本钉住。Per-user 路径
是为"为新的 math-coding 项目搭建脚手架"提供的便利——
每次发布后运行 `install.sh --user-skill --upgrade`
即可保持技能为最新。

## 校验

任何安装完成后，使用以下命令校验：

```bash
mathc version
mathc self-check
mathc validate decisions/<your-first-decision>.yaml
```

`mathc version` 从二进制中输出版本字符串。
`mathc self-check` 针对当前仓库运行内核，并报告
pass/unknown/fail。`mathc validate` 按模式检查单个
决策文件；接受时退出码为 0，拒绝时为 1，输入错误时
为 2。

## 搭建新项目

当 `mathc` 在 PATH 上后，针对新项目的推荐采用流程为：

```bash
cd /path/to/new-project
mathc init .                 # 生成 decisions/、attestations/
# decisions/decision.yaml、.githooks/
```

`mathc init`（决策 `ux-3-init-subcommand-2026-10`）：

- 在目标目录中创建 `decisions/` 与 `attestations/`。
- 写入 `decisions/decision.yaml`，包含当前策略（对
  install-tooling 模板的逐字拷贝，该模板为
  `math-coding/3.2`）。
- 安装 `.githooks/pre-commit`（除非传入 `--no-install`）。
- **拒绝** 检测到 `docs/arc42/`、`docs/adr/` 或 `adr/`
  存在的情况，除非传入 `--merge`。拒绝消息会指明检测
  到的约定，并指向 `mathc import-adr`（见下）作为存量
  项目的路径。
- 标志：`--agent`（按平台布置技能，目前除输入校验外
  为 no-op）、`--from-adr`（暂缓）、`--no-install`、
  `--merge`。

对于已有 MADR 或 adr-tools ADR 的项目，使用
`mathc import-adr` 按文件处理（决策
`ux-3-import-adr-subcommand-2026-10`）：

```bash
# 单个文件（向 stdout 输出 YAML）
mathc import-adr docs/adr/0001-use-postgres.md

# 所有 MADR 文件（写入 decisions/<id>.yaml；
# 审阅者在 mathc validate 接受前填入 scope.paths[]）
for f in docs/adr/*.md; do
  mathc import-adr "$f" --write
done
```

## 从早期版本迁移

在已安装 `mathc` 的主机上重新运行 `install.sh`，当
版本匹配时为 no-op（`install.sh --check` 退出 0）。
当版本不一致时，脚本会就地覆盖二进制；per-user 技能
仅在使用 `--user-skill --upgrade` 时才会被覆盖。

对于 per-repo 技能，将新的
`dist/adoption/opencode/SKILL.md` 复制到项目的
`.opencode/skills/math-coding/SKILL.md`。frontmatter 中
的版本钉住是有文档化的真相来源，记录"该仓库是在哪个
发布版之上编写的"。

## 沙箱说明

在 NixOS 上，通过 `flake.nix` 的默认内核构建产出的 `mathc`
链接到 `/nix/store/<hash>-glibc-2.42`。该二进制在系统
glibc 早于 2.42 的主机上将无法运行。`release.yml` 流水线
在 Ubuntu 22.04 上通过 system opam 进行构建；发布的二进制
链接到 runner 的 glibc，可在 glibc 2.35+ 系统间移植。
交付的 `install.sh` 故意不信任本地构建的二进制；它从
发布版本下载。

对于 Alpine（musl-libc），自 v3.2.0-alpha 起，
`mathc-linux-x86_64-musl` 变体作为 release asset 发布；
musl Docker 镜像推迟到后续周期（参见
`decisions/docker-alpine-impl-pending.yaml`）。在那之前，
Alpine 用户直接从 release 的 `assets/` 列表中下载
musl 二进制。

## 另请参阅

- 在 `adoption/SKILL.md` — 规范化的代理技能。
- 在 `USAGE.md` — 采用运行手册（二进制安装 + 首个决策）。
- 在 `decisions/install-tooling-2026-10.yaml` — 引入这
  四个渠道的决策。
- 在 `OCAML_KERNEL_CONVENTIONS.md` §11.28（`curl | sh`
  安装脚本及 `-fSL` 标志的纪律）。
