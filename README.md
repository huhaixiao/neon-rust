# Neon Rust / 霓虹锈蚀

俯视角双摇杆射击（Twin-stick shooter），Godot 4.7 / Forward+ / 2D 渲染，1280×720。
你驾驶一台霓虹涂装的拦截机，在一片锈蚀的废弃竞技场里撑过一波接一波的无人机群。

![战斗画面](docs/screenshots/combat.png)

## 运行

```bash
# 直接用编辑器：用 Godot 4.7 打开本目录，F5
open -a Godot /Users/huhaixiao/github/neon-rust

# 或者命令行
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/huhaixiao/github/neon-rust
```

首次打开会自动导入 `assets/` 下的 PNG/WAV（已随工程附带 `.import`，通常无需等待）。

## 操作

| 动作 | 键盘 / 鼠标 | 手柄 |
| --- | --- | --- |
| 移动（左摇杆） | `W` `A` `S` `D` / 方向键 | 左摇杆 `JOY_AXIS_LEFT_*` |
| 瞄准（右摇杆） | 鼠标位置 | 右摇杆 |
| 开火 | 鼠标左键（按住连发） | `RB` 或 `RT` 轴 |
| 冲刺 | `Space` | `B` / `LB` |
| 暂停 | `Esc` | `START` / `BACK`（左右两个菜单键都行） |
| 重开 | `R` / `Enter` | `A` |
| 静音 | `M` | — |
| 全屏 | `F11` | — |

HUD 会检测是否接了手柄：接了就把提示切成手柄说法（`RT FIRE` / `B DASH` / `START OR ESC TO RESUME` / `PRESS A TO REDEPLOY`），没接就显示键鼠说法。插拔手柄会即时切换。

键位在 `modules/global/autoload/input_setup.gd` 里用代码注册（运行时写入 InputMap），改键只改这一处；若你在项目设置里手写过同名 action，代码会尊重你的设置。

## 在 Steam Deck 上试玩

导出包已经内嵌 PCK，单个可执行文件即可运行：

```bash
./tools/package_deck.sh          # 产出 build/linux/neon-rust.x86_64 与 build/neon-rust-linux-x86_64.zip
```

1. 用 LocalSend 把 `build/neon-rust-linux-x86_64.zip` 发到 Deck，在「下载」目录里解压。
2. 桌面模式双击 `linux/neon-rust.x86_64`；如果没反应，先在 Konsole 里 `chmod +x neon-rust.x86_64` 再双击（zip 会保留可执行位，直接拷单个文件用 FAT 盘则会丢）。
3. 想进游戏模式：Steam → 库 → 添加非 Steam 游戏 → 选中该可执行文件；**Steam Input 建议设为「禁用」或「手柄」**，否则 A/B/RT 会被 Steam 的桌面模板重映射。
4. 手感确认：左摇杆移动、右摇杆瞄准、RT 开火、B 冲刺、START 暂停、A 重开；HUD 检测到手柄后会把文案切成 `RT FIRE / B DASH / START OR ESC TO RESUME / PRESS A TO REDEPLOY`。
5. 1280×720 会被 `canvas_items + expand` 自适应到 1280×800；F11 可切全屏。

## 实时调试（Steam Deck）

```bash
./tools/package_deck_debug.sh     # 出 build/linux/neon-rust-debug.x86_64 + build/neon-rust-linux-x86_64-debug.zip
```

- **游戏内浮层**：`F3` 或按下右摇杆（R3）切换，右上角显示 `FPS / 帧时 / 波次 / 敌人数 / 子弹数 / HULL / DASH / OD / 坐标`。浮层只在 debug 模板构建里生效（`OS.is_debug_build()`），release 包按了没反应，HUD 保持干净。
- **远程连编辑器**：先在 Mac 上打开本工程（编辑器即调试服务器，默认端口 `6007`），Deck 上这样启动：

```bash
./neon-rust-debug.x86_64 --remote-debug tcp://<Mac 的局域网 IP>:6007 --verbose
```

  `ipconfig getifaddr en0` 查 IP。连上后编辑器「调试器 → 远程」里会出现该实例，可看远程场景树、性能监视，debug 模板还支持脚本断点与错误堆栈。连不上先查 macOS 防火墙是否放行传入连接，以及两台设备是否同一网段。
- **只想要日志**：`./neon-rust-debug.x86_64 --verbose` 直接看 stdout；崩溃时加 `-d`（本地 debugger）会打堆栈。

## 玩法循环

- 每波按预算生成敌人：`min(6 + 波次 × 2, 44)` 个，从场地边缘外缓速涌入。
- 第 2 波起出现 SPITTER（远程），第 3 波起出现 BRUTE（重装）；敌人体力随波次 ×`1 + 0.16 × (波次 − 1)`，移速每波 +3%。
- 清空当前波 → 结算奖励 `25 + 20 × 波次` 分 → 短暂间隔后下一波。
- 敌人有几率掉落补给：6% 血包（回 30 HP）、9% 超载（9 秒三连发，单发伤害 0.72 倍、射速 0.62 间隔）。
- 玩家 100 HP；冲刺 0.13 秒、期间无敌、冷却 1.5 秒。
- 死亡后场景暂停并弹出 SYSTEM FAILURE 面板，`R` 立即重开；最高分写入 `user://neon_rust.cfg`。

## 敌人

| 单位 | 体力 | 速度 | 接触伤害 | 分值 | 行为 |
| --- | --- | --- | --- | --- | --- |
| CHASER（洋红箭头） | 30 | 235 | 12 | 10 | 直冲玩家，绕行摆动 |
| BRUTE（橙色六边形） | 130 | 118 | 26 | 45 | 慢速压上，撞击最痛 |
| SPITTER（黄绿菱形） | 48 | 150 | 10 | 30 | 保持距离，发射弹速 620 的子弹 |

## 工程结构

```
neon-rust/
├─ project.godot          # 1280×720，canvas_items 拉伸，Forward+
├─ main.tscn + main.gd    # 唯一入口：竞技场底图 + 各模块装配 + 输入/暂停/重开
├─ modules/
│  ├─ global/autoload/    # Game 全局状态 + 存档 / InputSetup 键位 / Fx 粒子音效池
│  ├─ player/             # player.tscn + player.gd
│  ├─ enemies/            # enemy.tscn + enemy.gd（三型共用一套场景）
│  ├─ projectiles/        # bullet.tscn + bullet.gd（敌我共用）
│  ├─ pickups/            # pickup.tscn + pickup.gd
│  ├─ waves/              # spawner.gd 波次导演
│  ├─ camera/             # camera_rig.gd 跟随与震屏
│  └─ hud/                # hud.tscn + hud.gd HUD 与暂停 / 结算面板
├─ assets/sprites/        # 全部由脚本生成，无外部素材
├─ assets/sounds/         # 8 个合成音效
├─ tools/                 # 资源生成与像素采样脚本（纯标准库，无第三方依赖）
├─ tests/                 # 无头冒烟测试 + 窗口截图脚本
└─ docs/screenshots/      # 验收截图
```

碰撞层：玩家 1、敌人 2、友方子弹 4（掩码 2）、敌方子弹 8（掩码 1）、补给 1。场地没有物理墙——所有单位按 `Game.ARENA_SIZE`（1600×1000）做 `clamp`，子弹越界即回收，省掉一圈静态碰撞体。相机手动夹在场地内，画面永远不会露出场地外的空白。

## 资源与验证

所有美术与音效都是脚本现算出来的，仓库里没有第三方素材：

```bash
python3 tools/generate_assets.py    # 精灵（SDF 光栅化 + 三层着色）
python3 tools/generate_arena.py     # 竞技场底图 1600×1000
python3 tools/generate_sounds.py    # WAV 音效（stdlib wave 合成）
python3 tools/png_sample.py <png> x,y   # 不装 PIL 也能查像素，用于核对渲染结果
```

两条自检命令：

```bash
# 无头冒烟测试：加载主场景、跑若干帧、推进波次、开火、冲刺、击杀，全部走真实脚本
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/smoke_test.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/pause_test.tscn   # 暂停时玩法必须冻结、输入层仍活着
# 期望输出：SMOKE TEST: PASS

# 窗口截图验收：合成输入并抓 4 张图到 /tmp/neon_rust_shots/
/Applications/Godot.app/Contents/MacOS/Godot --path . res://tests/capture.tscn
```

## 已知限制 / 下一步

- 音效是纯合成占位，没有音乐轨；`Fx` 里已经留好音效池，换成真素材只需替换 `assets/sounds/`。
- 目前只有一种武器（加“超载”变体），没有升级/商店。
- 场地是单张 1600×1000 底图，没有可破坏掩体或视线遮挡。
- `tools/generate_assets.py` 仍会顺带生成一张 `floor_tile.png`（早期平铺方案的遗留，当前场景不使用），可以删掉那段代码。

顺手能加的东西：武器升级树、精英波（每 5 波 BOSS）、屏幕击杀连击计分、手柄死区与震动反馈、以及把 `Fx` 的粒子换成 `GPUParticles2D` 以便在低端机上稳住帧率。
