# LifePilot 生态 — 整体架构说明

## 一、核心产品背景：关于 LifePilot

虽然本项目由多个独立运作的子系统（如观测看板、数据中台、工具集、SDK等）协同构成，但最初的业务源头与核心体验载体为 **LifePilot（AI 日程 & 任务助理）**。

- **产品背景**：在信息与任务碎片化时代，人们需要一个能理解自然语言、结合个人上下文历史记录并主动辅助规划的智能系统。传统 To-Do 应用纯靠手动管理，缺乏智能化思考与执行手段。
- **目标人群**：需要高效管理日程的学生、职场人士、以及需要构建个人专属知识库的知识型工作者。
- **产品定位**：一个以大语言模型（LLM）和 LangGraph 工作流为大脑，支持多模态（语音、文本、图片、文档）交互的“全能型私人任务与知识助理”。
- **核心功能**：
  - **智能任务与日程管理**：通过自然语言对话（如“帮我规划今天下午的任务”），AI 会自动分析并调用 MCP 工具拆解任务、排期并在前端日历与任务列表中呈现。
  - **专属私人知识库（RAG）**：支持上传多种格式的文档文件，AI 基于用户个人私有数据提供精准的问答支持。
  - **快捷语音交互（ASR & TTS）**：内置流式语音识别与高质量语音合成，支持类似真实对话的便利沟通方式。
  - **出行与攻略搜索**：整合高德地图与小红书等外部 MCP 工具，能通过自主推理（ReAct Agent）进行复杂的城市路线规划、导航及旅游攻略检索。
- **它能带来什么帮助**：将用户从繁琐的日程排期、计划制定与资料翻找中彻底解放出来。它不仅仅是一个记录工具，更是一个能“听懂复杂指令、自主进行规划切分、查阅用户私人资料、甚至连接外部世界（地图/社交内容）”的主动型数字伴侣。

---

## 二、项目全景概览

本项目由多个子项目协同组成，覆盖前端、AI 后端、工具服务、RAG 知识库、日志监控以及共享 SDK。各子项目通过明确的接口约定（REST、SSE、MCP、HTTP SDK）相互解耦，可独立部署与扩展。

```
Graduation Project/
├── LifePilot/            # 前端主应用（Next.js 15）
├── LifePilotServer/      # AI 后端服务（Express + LangGraph）
├── LifePilot_mcp/        # MCP 工具服务（Model Context Protocol Server）
├── ai-server/            # RAG / AI 能力服务（Python FastAPI）
├── Metaphorical/         # 日志监控看板（Next.js 16）→ metaphorical.yanmengsss.xyz
├── OmniBase/             # 数据库观测汇总平台（Next.js 16）→ omnibase.yanmengsss.xyz
├── yanmengs-logs/        # 日志上报 SDK（正式 npm 包 ^1.0.0）
└── yanmengs-ragPackage/  # 统一 AI 能力客户端 SDK（npm 发布包）
```

---

## 三、各子项目说明

各子项目各司其职，通过 API/SDK 与其他模块通信，共同支撑 LifePilot 完整功能。

| 项目 | 技术栈 | 端口 / 域名 | 核心职责 |
|------|--------|------------|----------|
| `LifePilot` | Next.js 15, React 19, Prisma, MobX, TailwindCSS | `lifepilot.website` | 前端主应用：任务管理、日历、知识库、AI 对话 |
| `LifePilotServer` | Express 5, LangGraph, LangChain, MCP SDK | `server.lifepilot.website` (:5000) | AI 后端：LangGraph Agent、流式对话、OSS、TTS |
| `LifePilot_mcp` | Express, @modelcontextprotocol/sdk, Prisma | `mcp.lifepilot.website` (:7000) | MCP 服务器：为 AI Agent 提供任务的 CRUD 工具 |
| `ai-server` | FastAPI, LangChain, Weaviate, qiniu | RAG 服务地址 | RAG 知识库：文档解析、向量检索、ASR/TTS/OSS |
| `Metaphorical` | Next.js 16, React 19, Mongoose, shadcn/ui | `metaphorical.yanmengsss.xyz` (:6500) | 日志看板：查看/管理所有项目上报的运行日志，Jenkins+Docker 部署 |
| `OmniBase` | Next.js 16, React 19, weaviate-client, mysql2, redis, mongodb, shadcn/ui | `omnibase.yanmengsss.xyz` (:3500) | 数据库观测汇总平台：多数据源（Weaviate/MySQL/MongoDB/Redis）可视化管理 |
| `yanmengs-logs` | TypeScript (**正式 npm 包 `^1.0.0`**) | — | 日志上报 SDK：埋点并上报日志至 Metaphorical |
| `yanmengs-ragPackage` | TypeScript (npm 包 `^1.0.1`) | — | RAG/TTS/ASR/七牛 统一客户端 SDK，供前后端共用 |

---

## 四、整体架构图

下图展示了各子系统之间的调用关系，分为用户端、前端、AI 后端、MCP 工具服务、RAG 服务、可观测性/数据平台和共享基础设施七个层次。

- **用户浏览器** 通过 HTTPS 访问前端 LifePilot
- **前端**通过 REST/SSE 与 AI 后端通信，通过 HTTP 调用 RAG 服务（经 `yanmengs-rag-package` SDK 封装）
- **AI 后端（LifePilotServer）** 内置 LangGraph，通过 MCP 协议与 `LifePilot_mcp` 通信并接入高德地图 MCP 和小红书 MCP
- **日志链路**：前端通过 `yanmengs-logs`（正式 npm 包 `^1.0.0`）上报日志至 Metaphorical 看板
- **OmniBase**：独立的数据库观测汇总平台，直连 Weaviate / MySQL / MongoDB / Redis 进行可视化管理
- **共享基础设施**：MySQL（主数据）、MongoDB（历史+日志）、Redis（缓存）、Weaviate（向量）、七牛云（OSS+CDN）

```mermaid
graph TB
    subgraph 用户端
        Browser["🌐 用户浏览器"]
    end

    subgraph 前端["LifePilot 前端  (lifepilot.website)"]
        NextApp["Next.js 15 App\n/home · /login · /knowledge"]
        MobX["MobX Store\n任务/标签/用户状态"]
        PrismaFE["Prisma Client\n→ MySQL"]
        YanmengsLogs["yanmengs-logs SDK\n日志埋点上报"]
        YanmengsRAG["yanmengs-rag-package\nRAG/TTS/ASR/OSS 客户端"]
    end

    subgraph AIServer["AI 后端服务  (server.lifepilot.website:5000)"]
        Express["Express 5 App\n/chat · /oss · /tts"]
        LangGraph["LangGraph Agent\n多节点工作流"]
        Scheduler["任务调度器\n定时提醒"]
        McpClient["MCP Client\n→ LifePilot_mcp"]
        PrismaBE["Prisma Client\n→ MySQL"]
        AiSdk["AI SDK\nGPT-4o (工作流) / DeepSeek (路由识别)"]
    end

    subgraph MCPServer["MCP 工具服务  (mcp.lifepilot.website:7000)"]
        MCPCore["@modelcontextprotocol/sdk\nStreamableHTTP Transport"]
        TaskTools["Tools:\ncreate_task · get_tasks\nupdate_task · delete_task · create_tag"]
        PrismaMCP["Prisma Client\n→ MySQL"]
    end

    subgraph PyService["RAG / AI 能力服务  (ai-server / FastAPI)"]
        FastAPI["FastAPI\n/document · /chat · /asr · /tts · /oss"]
        LangChainPy["LangChain + Weaviate\n向量检索 RAG"]
        QiniuPy["七牛云 OSS"]
    end

    subgraph Observability["可观测性 & 数据平台"]
        MetaphoricalApp["Metaphorical 看板\nNext.js 16 日志监控\nmetaphorical.yanmengsss.xyz"]
        MongoDB2["MongoDB\n日志存储"]
        OmniBaseApp["OmniBase 数据平台\nNext.js 16 多源数据管理\nomnibase.yanmengsss.xyz"]
    end

    subgraph 共享基础设施["☁️ 共享基础设施"]
        MySQL[("MySQL\nsqlpub.com:3307\ntodo_list")]
        Redis[("Redis\nUpstash TLS")]
        MongoDB[("MongoDB\n45.207.220.25:27017\ntodoList")]
        Weaviate[("Weaviate\n向量数据库")]
        Qiniu["七牛云 CDN\ncdn.yanmengsss.xyz"]
    end

    Browser -->|HTTPS| NextApp
    NextApp --- MobX
    NextApp --- PrismaFE
    NextApp --- YanmengsLogs
    NextApp --- YanmengsRAG

    NextApp -->|REST + SSE\n/chat /tts /oss| Express
    YanmengsRAG -->|HTTP| FastAPI

    Express --> LangGraph
    Express --> Scheduler
    LangGraph --> AiSdk
    LangGraph --> McpClient
    LangGraph --> PrismaBE

    McpClient -->|MCP over HTTP| MCPCore
    MCPCore --> TaskTools
    TaskTools --> PrismaMCP

    PrismaFE -->|Prisma| MySQL
    PrismaBE -->|Prisma| MySQL
    PrismaMCP -->|Prisma| MySQL

    NextApp -->|ioredis| Redis
    Express -->|ioredis| Redis

    Express -->|Mongoose| MongoDB
    NextApp -->|Mongoose| MongoDB

    LangChainPy --> Weaviate
    FastAPI --> QiniuPy
    QiniuPy --> Qiniu

    YanmengsLogs -->|HTTP POST| MetaphoricalApp
    MetaphoricalApp --> MongoDB2

    OmniBaseApp -->|直连查询| MySQL
    OmniBaseApp -->|直连查询| MongoDB
    OmniBaseApp -->|直连查询| Redis
    OmniBaseApp -->|直连查询| Weaviate

    NextApp -->|上传/下载| Qiniu
    Express --> Qiniu
```

---

## 五、核心功能工作流

本章详细描述 LifePilot 四条核心业务链路：AI 对话（SSE 流式）、TTS 语音合成、ASR 语音识别、知识库（RAG 文档入库与检索问答）。

### 5.1 AI 对话（SSE 流式）

用户输入自然语言或语音，前端通过 **Server-Sent Events（SSE）** 实时接收 AI 回复流，避免了 HTTP 长轮询的性能损耗。服务端在返回第一个 chunk 之前会先保存用户消息到 MongoDB，对话结束后再保存 AI 最终回复，确保历史记录完整。

```mermaid
sequenceDiagram
    actor User as 用户
    participant FE as LifePilot 前端
    participant Server as LifePilotServer
    participant LG as LangGraph Router
    participant Workflow as 具体 Workflow
    participant DB as MongoDB

    User->>FE: 输入消息 / 语音
    FE->>Server: POST /chat { user_id, chat_id, context }
    Server->>DB: saveHistory（user 消息）
    Server->>Server: setHeader SSE（text/event-stream）
    Server->>LG: runSmartWorkflowStream()
    LG->>LG: 意图识别（router 节点）
    LG-->>Server: yield { type:"think", node:"router" }
    LG->>Workflow: 分发到对应 workflow
    loop 流式输出
        Workflow-->>Server: yield { type:"think"|"response"|"confirm"|"refresh" }
        Server-->>FE: data: SSE chunk\n\n
        FE-->>User: 实时渲染
    end
    Server->>DB: saveHistory（assistant 最终回答）
    Server-->>FE: data: { type:"done" }
```

**SSE 事件类型说明：**

每个 SSE chunk 携带一个 `type` 字段，前端根据类型决定渲染行为：

| type | 含义 |
|------|------|
| `id` | 新对话的 chat_id + message_id |
| `think` | 节点推理过程（显示为"思考中..."） |
| `response` | 最终回复内容（流式追加渲染） |
| `confirm` | buildToDo 暂停，前端展示 accept/reject 按钮 |
| `thread_id` | buildToDo checkpoint 的线程 ID，供 resume 用 |
| `refresh` | 通知前端刷新任务列表 |
| `done` | 流结束 |

---

### 5.2 TTS（文字转语音）工作流

当 AI 回复需要以语音播放时，前端将文本发送到 LifePilotServer，由后端进行 **Markdown 清洗**（去除代码块、`#`、`**` 等符号）后，再通过 `yanmengs-rag-package` SDK 转发给 `ai-server`（FastAPI），最终将 MP3 音频流 pipe 回前端直接播放。后端代理的好处是 FastAPI 服务地址和鉴权 Key 不暴露给客户端。

```mermaid
sequenceDiagram
    participant FE as LifePilot 前端
    participant Server as LifePilotServer
    participant SDK as yanmengsClient (RAG SDK)
    participant Py as ai-server / FastAPI

    FE->>Server: POST /tts/stream { text: "AI 回复内容" }
    Server->>Server: sanitizeTextForTTS()\n去除代码块/Markdown符号
    Server->>SDK: yanmengsClient.tts.stream({ text })
    SDK->>Py: POST /tts/... { text }
    Py-->>SDK: 流式 audio/mpeg
    SDK-->>Server: Response stream
    Server->>FE: pipe → audio/mpeg chunked 流
    FE->>FE: 播放音频
```

---

### 5.3 ASR（语音识别）工作流

用户在前端长按录音，浏览器通过 `MediaRecorder` API 采集音频，录音结束后以 `multipart/form-data` 格式直接 POST 到 `ai-server`（FastAPI），跳过 LifePilotServer，以降低延迟。`ai-server` 验证 APP_KEY 后调用 **SiliconFlow 的 SenseVoiceSmall 模型**完成转写，将识别文本填回前端对话框并自动触发 AI 对话流程（详见 4.1）。

```mermaid
sequenceDiagram
    actor User as 用户
    participant FE as LifePilot 前端
    participant PyASR as ai-server / FastAPI /asr/transcribe
    participant SiliconFlow as SiliconFlow API\n(SenseVoiceSmall)

    User->>FE: 按住录音
    FE->>FE: 浏览器录音 (MediaRecorder)
    FE->>PyASR: POST /asr/transcribe { file: audio }
    Note over PyASR: App-Key 鉴权
    PyASR->>SiliconFlow: POST /v1/audio/transcriptions\n(multipart form)
    SiliconFlow-->>PyASR: { text: "识别结果" }
    PyASR-->>FE: { code:200, data:{ text } }
    FE->>FE: 将文字填入对话框
    FE->>FE: 触发 AI 对话流程 (→ 4.1)
```

---

### 5.4 知识库（RAG）工作流

知识库分为**文档入库**和**检索问答**两个阶段，分别使用不同的数据链路。

#### 文档入库

用户上传文件后，前端先将文件**直传七牛云 OSS** 获取 CDN URL，再将 URL 交给 `ai-server` 处理。`ai-server` 从 CDN 下载文件，通过对应的解析器（PDF/Word/Excel/PPT/图片/TXT）提取文本，切块后写入 **Weaviate 向量数据库**，以用户 ID 和项目名隔离数据。前端直传七牛云的设计避免了大文件经过 Node.js 服务器，减少后端压力。

```mermaid
sequenceDiagram
    actor User as 用户
    participant FE as LifePilot 前端 /knowledge
    participant Qiniu as 七牛云 OSS
    participant PyDoc as ai-server / FastAPI /documents
    participant Weaviate as Weaviate 向量库

    User->>FE: 上传文件（PDF/Word/Excel/PPT/图片/TXT）
    FE->>Qiniu: 直传七牛云 → 获取 CDN URL
    FE->>PyDoc: POST /documents/process-url\n{ userID, file_url }
    Note over PyDoc: APP_KEY 鉴权
    PyDoc->>Qiniu: 下载文件（CDN URL）
    PyDoc->>PyDoc: 解析文件\n(pdf_parser/doc_parser/image_parser...)
    PyDoc->>PyDoc: chunk_text() 文本分块
    PyDoc->>Weaviate: store_to_weaviate(chunks, index=appName, userID)
    Weaviate-->>PyDoc: 写入成功
    PyDoc-->>FE: { message:"执行成功", total_chunks }
```

#### 检索问答（RAG Workflow）

当用户提问触发 `rag` workflow 时，LangGraph 调用 `yanmengsClient.chat.ask()` 向 `ai-server` 发出检索请求。`ai-server` 在 Weaviate 中按用户 ID 过滤后取 Top-K 相关文本块，拼装 RAG Prompt 交给 GPT-4o 生成答案。若未命中（向量相似度不足），则 fallback 到普通 LLM 问答，保证用户始终得到回复。

```mermaid
sequenceDiagram
    participant LG as LangGraph rag 节点
    participant SDK as yanmengsClient
    participant Py as ai-server / FastAPI /chat
    participant Weaviate as Weaviate
    participant LLM as GPT-4o LLM

    LG->>SDK: yanmengsClient.chat.ask({ userId, query, topK:3 })
    SDK->>Py: POST /chat/ask
    Py->>Weaviate: 向量检索（按 userID + index 过滤）
    Weaviate-->>Py: Top-K 相关文本块
    Py->>LLM: 拼装 RAG Prompt + 检索内容
    LLM-->>Py: 生成回答
    Py-->>SDK: { answer }
    SDK-->>LG: ragAnswer
    alt 有命中
        LG-->>前端: type:"response" 直接输出答案
    else 未命中
        LG->>LLM: fallback GPT-4o 普通问答
        LG-->>前端: type:"response" 流式输出
    end
```

---

### 5.5 异步任务调度与邮件提醒机制

LifePilot 具备基于 **Redis Zset（有序集合）** 和 **Node.js 定时轮询** 的高性能异步任务调度系统，专用于到期待办任务的邮件提醒。架构保证了高效性、无阻塞和强容错能力。

#### 核心调度与派发流程

1. **抢占式轮询 (Redis Zrangebyscore + Zrem)**
   - 后端启动一个内置的 Scheduler，每次循环通过 `zrangebyscore` 从 Redis 的 `scheduler:tasks` 队列（Score 为触发时间戳）中拉取当前时间应该触发提醒的任务 ID。
   - 为了防止可能的并发重复处理，拉取后立刻通过 `zrem` 将任务出队。只有 ZREM 抢占成功（返回 1）的进程才会接管处理。
2. **状态判定与邮件发送 (Nodemailer)**
   - 调度器从 MySQL (Prisma) 中获取任务最新详情和用户配置的提醒频率（`tipsFrequency`）。如果任务由于前端操作已经被删除或标记为完成，则静默丢弃。
   - 若任务已晚于截止时间 (`endAt`)，更新数据库状态为 `timeout`，并通过 `Nodemailer` 及定制的 HTML 模板向用户邮箱发送“任务超时”告警邮件。
   - 若任务仍在进行中，则发送格式优美的“任务即将到期提醒”通知。
3. **循环再调度 (Zadd)**
   - 邮件发送完成后，系统根据用户的提醒频率（如每 1 小时）计算下一次触发时间。如果下次触发时间仍早于任务截止时间，则通过 `zadd` 再次放入 Redis Zset 挂起等待；否则将最终的到期时间作为最后一次提醒。
   
```mermaid
sequenceDiagram
    participant Worker as Scheduler (Node.js)
    participant Redis as Redis (Zset)
    participant MySQL as MySQL (Prisma)
    participant Mail as Nodemailer (QQ SMTP)
    actor User as 用户邮箱

    loop 持续轮询
        Worker->>Redis: 1. zrangebyscore 获取已到期任务
        Worker->>Redis: 2. zrem 原子抢占任务 (防并发)
        alt 抢占成功
            Worker->>MySQL: 3. 查询任务详情与用户配置
            alt 任务已完结
                Note over Worker: 终止处理
            else 任务超时
                Worker->>MySQL: 更新状态为 timeout
                Worker->>Mail: 4a. 发送任务超时告警邮件
                Mail-->>User: HTML 邮件送达
            else 任务进行中
                Worker->>Mail: 4b. 发送倒计时提醒邮件
                Mail-->>User: HTML 邮件送达
                Worker->>Redis: 5. 计算下次时间并 ZADD 重新入队
            end
        end
    end
```

---

## 六、LangGraph Agent 工作流详解

LangGraph 是整个 AI 对话能力的核心，运行于 `LifePilotServer` 中。所有对话请求经由顶层 **Router 节点**进行意图识别，路由到 5 条工作流之一。每条工作流在正式处理前都会执行两个**公共前置节点**：

- **`get_time`**：获取当前时间（注入到 Prompt，使 LLM 感知时区和日期）
- **`prepare_context`**：从 MongoDB 拉取历史对话记录 + 从 MySQL 拉取用户当前任务列表

```mermaid
graph LR
    Input([用户输入]) --> Router["🧭 Router\n意图识别\n( DeepSeek JSON 输出 )"]
    Router -->|build_todo| BT["📋 build_todo\n新建任务规划\n执行者+检查者+用户确认"]
    Router -->|what_to_do| WT["🔄 what_to_do\n任务操作管理\n执行者+检查者+管家"]
    Router -->|trivel| TV["✈️ trivel\n出行规划\nReAct Agent"]
    Router -->|howToGo| HG["🗺️ howToGo\n路线查询\nReAct Agent"]
    Router -->|rag / fallback| RAG["📚 rag\n知识库检索\n+GPT-4o 兜底"]
```

---

### 6.1 build_todo — 新建任务规划（执行者 × 检查者 × 用户确认 × MCP）

这是最复杂的 workflow，包含**人在回路（Human-in-the-Loop）**机制。当用户表达"帮我规划今天的任务"之类的意图时触发。

整个流程采用**三角色 + 用户确认**模式：
1. **执行者（executor）** 分析用户需求，生成包含 `tips`（计划建议）和 `list`（任务列表 JSON）的结构化输出
2. **检查者（inspector）** 验证输出质量，不通过则驱动执行者重新生成（循环）
3. **formatter** 将结构化 JSON 格式化为对用户友好的 Markdown + JSON 代码块
4. **user_judgment** 调用 `interrupt()` 中断工作流，前端显示"接受/拒绝"按钮
5. 用户接受后，**save_to_mcp** 通过 MCP 协议批量写入 MySQL，并通知前端刷新任务列表

```mermaid
graph TD
    Start([START]) --> get_time
    get_time --> prepare_context
    prepare_context --> executor

    executor["🛠️ 执行者 executor\n分析用户需求\n生成任务列表 JSON\n(tips + list)"]
    inspector["🔍 检查者 inspector\n校验执行者输出\n返回 {pass:bool, reason}"]
    formatter["📐 formatter\n格式化为 Markdown\n+ JSON 代码块"]
    user_judgment["⏸️ user_judgment\ninterrupt() 中断\n等待用户 accept/reject"]
    save_to_mcp["💾 save_to_mcp\n调用 MCP create_task\n批量写入 MySQL"]

    executor -->|executor_response| inspector
    inspector -->|pass=false, 重新生成| executor
    inspector -->|pass=true| formatter
    formatter -->|展示给用户\n发送 type:conf/rm 事件| user_judgment
    user_judgment -->|reject → inspector_feedback=用户拒绝| executor
    user_judgment -->|accept| save_to_mcp
    save_to_mcp -->|type:refresh 通知前端刷新| End([END])

    style executor fill:#dbeafe
    style inspector fill:#fef9c3
    style user_judgment fill:#fee2e2
    style save_to_mcp fill:#dcfce7
```

**状态字段：**

| 字段 | 说明 |
|------|------|
| `executor_response` | 执行者输出的 JSON（tips + list） |
| `inspector_feedback` | 检查者反馈（pass/reason）|
| `manager_response` | 格式化后的最终展示内容 |
| `list` | 任务列表 JSON（持久化到 checkpoint） |
| `thread_id` | MemorySaver checkpoint ID，用于 resume |

**人在回路交互：**

- 工作流在 `user_judgment` 节点调用 `interrupt()` 暂停，前端收到 `type:confirm` 事件展示确认按钮
- 用户点击后，前端 POST `/chat/judgment { thread_id, decision: "accept"|"reject" }`
- 后端调用 `resumeBuildToDoStream(thread_id, decision)` 恢复工作流

---

### 6.2 what_to_do — 任务操作管理（执行者 × 检查者 × 管家）

针对"帮我查看/修改/删除哪个任务"类意图的三角色协作模式。与 `build_todo` 不同，本 workflow **不调用 MCP、不写数据库**，定位为纯分析与建议输出，由"管家"角色以自然语言向用户呈现结论。

```mermaid
graph TD
    Start([START]) --> get_time
    get_time --> prepare_context
    prepare_context --> executor2

    executor2["🛠️ 执行者 executor\n结合历史上下文\n分析用户任务操作意图\n输出结构化操作建议"]
    inspector2["🔍 检查者 inspector\n验证执行者分析是否准确\n返回 {pass:bool, reason}"]
    manager["🎩 资深管家 manager\n整合执行者结论\n用自然语言回复用户"]

    executor2 -->|executor_response| inspector2
    inspector2 -->|pass=false| executor2
    inspector2 -->|pass=true| manager
    manager -->|type:response 流式输出| End([END])

    style executor2 fill:#dbeafe
    style inspector2 fill:#fef9c3
    style manager fill:#f3e8ff
```

**三角色职责对比：**

| 角色 | 节点 | 输出格式 | 作用 |
|------|------|---------|------|
| **执行者** | `executor` | 结构化 JSON / 分析报告 | 理解用户意图，提取关键信息 |
| **检查者** | `inspector` | `{ pass: boolean, reason: string }` | 质量把关，循环直至通过 |
| **管家** | `manager` | 自然语言（流式） | 润色包装，直接与用户对话 |

---

### 6.3 trivel & howToGo — 出行规划（ReAct Agent）

两者均使用 **ReAct（Reason + Act）** 架构：单一 `planner` 节点，LLM 开启 `useTools: true`，**自主决定何时调用工具**（高德地图 MCP、小红书 MCP）、何时输出最终回答。

ReAct 模式的优势在于无需预定义固定的节点链路，LLM 可在"推理→调用工具→观察结果→再推理"的循环中自主解决复杂的多跳问题，适合开放式出行规划与内容搜索场景。

```mermaid
graph TD
    Start([START]) --> get_time2
    get_time2 --> prepare_context2
    prepare_context2 --> planner

    planner["🤖 planner（ReAct Agent）\nLLM + useTools=true\n接入高德地图 MCP + 小红书 MCP\n自主推理 + 工具调用循环"]

    planner -->|tool-call| AmapMCP["🗺️ 高德地图 MCP\n路线规划 / 地点搜索 / 导航"]
    planner -->|tool-call| XhsMCP["📖 小红书 MCP\n内容检索 / 攻略搜索"]
    AmapMCP -->|tool-result| planner
    XhsMCP -->|tool-result| planner
    planner -->|生成最终文字回复| End([END])

    style planner fill:#dbeafe
    style AmapMCP fill:#dcfce7
    style XhsMCP fill:#fce7f3
```

**已接入 MCP 工具：**

| MCP 工具 | 用途 | 接入 Workflow |
|---------|------|---------------|
| **高德地图 MCP** | 路线规划、地点搜索、导航信息 | `trivel` / `howToGo` |
| **小红书 MCP** | 旅游攻略检索、目的地内容搜索 | `trivel` |

**ReAct 与三角色模式对比：**

| | ReAct (trivel/howToGo) | 三角色 (build/what_todo) |
|---|---|---|
| 节点数 | 1（planner 自循环） | 3+（executor/inspector/manager） |
| 工具调用 | LLM 自主决策（useTools） | 由 MCP Client 固定节点调用 |
| 循环控制 | LLM 内部 | LangGraph 条件边 |
| 适合场景 | 开放式搜索/规划 | 结构化操作/数据写入 |

---

### 6.4 rag — 知识库问答（RAG + GPT-4o 兜底）

当用户询问与其上传文档相关的问题时，Router 将其路由到 `rag` workflow。`rag` 节点调用 `yanmengsClient.chat.ask()` 在 Weaviate 中进行向量检索，若命中则直接将答案以 `type:response` 流式推给前端；若未命中（检索内容为空或相似度过低），则 fallback 到 GPT-4o 原生 LLM 进行普通问答，确保用户始终得到有效回复。

```mermaid
graph LR
    Start2([START]) --> rag_node
    rag_node["📚 rag 节点\n调用 yanmengsClient.chat.ask()"]
    rag_node -->|命中| output_rag["直接输出 type:response"]
    rag_node -->|未命中| fallback["GPT-4o 普通问答\n流式输出"]
    output_rag --> End2([END])
    fallback --> End2
```

---

## 七、MCP 工具服务（LifePilot_mcp）

`LifePilot_mcp` 是基于 **Model Context Protocol** 构建的工具微服务，专为 AI Agent 提供对任务数据的受控访问。AI Agent（LifePilotServer 内的 MCP Client）通过标准 MCP 协议（Streamable HTTP Transport）与其通信，工具调用结果经 Prisma 落库到 MySQL。

该设计的优势：将数据库操作权限收口到 MCP 服务，AI Agent 只能调用预定义工具，无法执行任意 SQL，提升了系统安全性。

MCP 服务器提供 5 个工具，供 AI Agent 通过 MCP 协议操作 MySQL 中的任务数据：

| 工具名 | 功能 | 必填参数 |
|--------|------|---------|
| `create_task` | 创建任务 | `userID`, `title` |
| `get_tasks` | 查询任务列表（多条件过滤）| `userID` |
| `update_task` | 更新任务 | `userID`, `id` |
| `delete_task` | 删除任务（支持批量）| `userID`, `id` |
| `create_tag` | 创建标签 | `userID`, `tags[]` |

**调用链：** `LifePilotServer (McpClient)` → HTTP → `LifePilot_mcp (:7000/mcp)` → `Prisma` → `MySQL`

---

## 八、日志可观测链路

LifePilot 内置了一套轻量级可观测性方案，通过 `yanmengs-logs` SDK 在前端业务代码中埋点，将日志实时上报至 **Metaphorical 看板**（独立 Next.js 服务），日志持久化到 MongoDB。开发者/运维人员可通过看板按项目、时间、日志等级筛选查看运行状态。

该链路完全独立于主业务链路，不影响 LifePilot 的正常运行，即使 Metaphorical 服务不可用，SDK 内部的错误也不会传播到主应用。

```mermaid
graph LR
    subgraph LifePilot前端
        Code["业务代码"] -->|import| SDK["yanmengs-logs SDK\n初始化: projectKey + tableName"]
        SDK -->|HTTP POST| MetAPI["Metaphorical API\n/api/logs"]
    end

    subgraph Metaphorical
        MetAPI -->|写入| MongoDB3[("MongoDB\n日志表")]
        Dashboard["Next.js 看板\n/logs 页面"] -->|查询| MongoDB3
        Dashboard -->|可视化展示| Admin["管理员"]
    end
```

---

## 九、共享 SDK 依赖关系

项目通过两个 SDK 包实现能力复用，避免重复造轮子：

- **`yanmengs-rag-package`**（npm 发布包 `^1.0.1`）：封装了对 `ai-server` 的 RAG、TTS、ASR、七牛 OSS 的 HTTP 调用，供 `LifePilot` 前端和 `LifePilotServer` 后端共用，统一了鉴权和接口规范
- **`yanmengs-logs`**（**正式 npm 发布包 `^1.0.0`**）：轻量日志上报 SDK，已从本地文件依赖升级为正式 npm 包，可在任意项目中安装使用，通过 `projectKey + tableName` 初始化后即可上报日志

```mermaid
graph TD
    subgraph npm发布
        RAGPkg["yanmengs-rag-package (npm ^1.0.1)\nRAG / TTS / ASR / 七牛 OSS 统一客户端"]
        LogsPkg["yanmengs-logs (npm ^1.0.0)\n日志上报 SDK\n初始化: projectKey + tableName"]
    end

    TodoFE["LifePilot 前端"] -->|依赖| RAGPkg
    TodoFE -->|依赖| LogsPkg
    TodoServer["LifePilotServer 后端"] -->|依赖| RAGPkg

    RAGPkg -->|HTTP| PyRAG["ai-server / FastAPI\n(/chat · /tts · /asr · /oss)"]
    LogsPkg -->|HTTP POST| MetAPI2["Metaphorical API\n/api/logs"]
```

---

## 十、部署架构

所有服务均通过 **Jenkins CI/CD + Docker** 完成自动化构建和部署。每个子项目有独立的 `Jenkinsfile`，触发 Pipeline 后自动构建 Docker 镜像并推送，容器启动后通过 Nginx 反向代理绑定到对应域名。

- **`LifePilot`**：`next build && next start`，映射到 `lifepilot.website`
- **`LifePilotServer`**：`tsx app.ts` 启动，监听 `:5000`，映射到 `server.lifepilot.website`
- **`LifePilot_mcp`**：编译后 `node dist/index.js` 启动，监听 `:7000`，映射到 `mcp.lifepilot.website`
- **`ai-server`**：`uvicorn main:app` 启动 FastAPI
- **`Metaphorical`**：`next build && next start -p 6500`，Jenkins + Docker 部署，映射到 `metaphorical.yanmengsss.xyz`
- **`OmniBase`** (`weaviate-manager`)：`next build && next start`，Jenkins + Docker 部署，映射到 `omnibase.yanmengsss.xyz`

```mermaid
graph TB
    subgraph Jenkins["Jenkins CI/CD"]
        JFE["Jenkinsfile\nLifePilot"]
        JSER["Jenkinsfile\nLifePilotServer"]
        JMCP["Jenkinsfile\nLifePilot_mcp"]
        JPY["Jenkinsfile\nai-server"]
        JMET["Jenkinsfile\nMetaphorical"]
        JOMB["Jenkinsfile\nOmniBase"]
    end

    subgraph Docker["Docker 容器"]
        DFE["LifePilot\nnext build → next start"]
        DSER["LifePilotServer\ntsx app.ts :5000"]
        DMCP["LifePilot_mcp\nnode dist/index.js :7000"]
        DPY["ai-server\nuvicorn main:app"]
        DMET["Metaphorical\nnext start -p 6500"]
        DOMB["OmniBase\nnext start :3500"]
    end

    subgraph 域名映射
        D1["lifepilot.website → LifePilot"]
        D2["server.lifepilot.website → LifePilotServer"]
        D3["mcp.lifepilot.website → LifePilot_mcp"]
        D4["metaphorical.yanmengsss.xyz → Metaphorical"]
        D5["omnibase.yanmengsss.xyz → OmniBase"]
    end

    JFE -->|build & push| DFE
    JSER -->|build & push| DSER
    JMCP -->|build & push| DMCP
    JPY -->|build & push| DPY
    JMET -->|build & push| DMET
    JOMB -->|build & push| DOMB

    DFE --> D1
    DSER --> D2
    DMCP --> D3
    DMET --> D4
    DOMB --> D5
```

---

## 十一、技术栈汇总

| 分层 | 技术 |
|------|------|
| **前端框架** | Next.js 15/16 · React 19 · TypeScript |
| **UI 组件** | shadcn/ui · Radix UI · TailwindCSS |
| **状态管理** | MobX 6 |
| **后端框架** | Express 5 (Node.js) · FastAPI (Python) |
| **AI/Agent** | LangGraph · LangChain · Vercel AI SDK · GPT-4o（主力 LLM）· DeepSeek（仅路由意图识别）|
| **Agent 模式** | Router → ReAct（trivel/howToGo） / 三角色（build/what_todo） / RAG |
| **MCP** | @modelcontextprotocol/sdk（Streamable HTTP Transport）· 高德地图 MCP · 小红书 MCP |
| **Human-in-Loop** | LangGraph `interrupt()` + `Command({ resume })` + MemorySaver |
| **ORM** | Prisma 6（MySQL）· Mongoose（MongoDB）|
| **数据库** | MySQL（主数据）· MongoDB（对话历史/日志）· Redis（缓存/会话）· Weaviate（向量）|
| **语音** | TTS: yanmengsClient → FastAPI / ASR: SiliconFlow SenseVoiceSmall |
| **存储/CDN** | 七牛云 OSS + CDN |
| **部署** | Docker + Jenkins CI/CD |
| **包管理** | pnpm |
| **日志 SDK** | `yanmengs-logs`（正式 npm 包 `^1.0.0`，`projectKey + tableName` 初始化）|
| **数据平台** | OmniBase（`omnibase.yanmengsss.xyz`）— 多源可视化：Weaviate / MySQL / MongoDB / Redis |
| **日志看板** | Metaphorical（`metaphorical.yanmengsss.xyz`）— 集中式日志监控看板 |
