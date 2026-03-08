# LifePilot 生态 — 智能日程与私人知识库助理

> **核心体验载体**：LifePilot（AI 日程 & 任务助理）  
> **定位**：一个以大语言模型（LLM）和 LangGraph 工作流为大脑，支持多模态（语音、文本、图片、文档）交互的“全能型私人任务与知识助理”。

## 一、 项目简介

在信息与任务碎片化时代，人们需要一个能理解自然语言、结合个人上下文历史记录并主动辅助规划的智能系统。LifePilot 将用户从繁琐的日程排期、计划制定与资料翻找中彻底解放出来。它不仅仅是一个记录工具，更是一个能“听懂复杂指令、自主进行规划切分、查阅用户私人资料、连接外部世界（地图/社交内容）”的主动型数字伴侣。

**核心亮点功能：**
- 🤖 **智能任务规划**：自然语言对话（如“帮我规划今天下午的任务”），AI 自动分析并调用 MCP 工具拆解任务、排期并在前端呈现。包含人在回路（Human-in-the-Loop）确认机制。
- 📚 **私人知识库（RAG）**：支持上传多种格式文档，AI 基于私有数据精准问答。
- 🎙️ **多模态交互**：内置流式语音识别（ASR）与高质量语音合成（TTS）。
- 🗺️ **出行规划**：集成高德地图与小红书等 MCP 工具，支持复杂城市路线规划与旅游攻略检索（基于 ReAct Agent 架构）。

---

## 二、 项目生态圈及目录结构

本项目由多个子项目协同组成，各子模块通过明确的接口约定（REST、SSE、MCP、HTTP SDK）相互解耦，可独立部署与扩展。

| 模块名称 | 目录 | 核心职责 | 技术栈 |
|---------|------|---------|--------|
| **前端主应用** | `/LifePilot` | 任务看板、日历、知识库、AI对话 UI | Next.js 15, React 19, MobX, TailwindCSS |
| **AI 后端服务** | `/LifePilotServer` | AI 对话流式响应、LangGraph 核心工作流 | Express 5, LangGraph, LLM (GPT-4o) |
| **MCP 工具服务** | `/LifePilot_mcp` | 安全的数据访问代理，为 AI 提供数据库读写工具 | Express, @modelcontextprotocol/sdk |
| **知识库 / RAG** | `/ai-server` | 文档解析、向量检索、ASR/TTS 集成 | FastAPI, LangChain, Weaviate |
| **日志监控看板** | `/Metaphorical` | 查看/管理所有项目上报的运行日志 | Next.js 16, Mongoose, shadcn/ui |
| **架构与数据库监控** | `/OmniBase` | 多数据源 (MySQL/Redis/Weaviate) 可视化平台 | Next.js 16, weaviate-client, mysql2 |
| **共享 SDK** | `/yanmengs-ragPackage` | RAG/TTS/ASR/OSS 统一前端调用与配置聚合 | TypeScript (npm 发布包) |
| **日志埋点 SDK** | `/yanmengs-logs` | 提供跨端日志埋点并上报至 Metaphorical | TypeScript (npm 发布包) |

---

## 三、 系统整体架构

系统涵盖用户端、AI 后端、MCP 服务、Python RAG 服务以及完善的可观测性基础设施环节。AI 核心层通过 Router 分发任务至不同智能体（ReAct/三角色）。

```mermaid
graph TB
    subgraph 用户端 / 前端
        NextApp["LifePilot 前端\n(Next.js 15)"]
    end

    subgraph Node.js AI 后端
        Express["LifePilotServer\n(Express + LangGraph)"]
        McpClient["MCP Client"]
        McpServer["LifePilot_mcp\n(MCP 服务器)"]
    end

    subgraph Python RAG 服务
        FastAPI["ai-server\n(FastAPI + Weaviate)"]
    end

    subgraph 数据底层与可观测平台
        MySQL[("MySQL (核心业务表)")]
        Weaviate[("Weaviate (向量库)")]
        Metaphorical["Metaphorical 看板\n(全链路日志集中监控)"]
        OmniBase["OmniBase 数据平台\n(多源数据观测看板)"]
    end

    NextApp <-->|REST / SSE 流式回复| Express
    Express <-->|流程决策与调用| McpClient
    McpClient <-->|MCP 协议交互| McpServer
    McpServer -->|Prisma 读写代理| MySQL

    NextApp -->|yanmengs-rag-package (HTTP)| FastAPI
    FastAPI --> Weaviate

    NextApp -->|yanmengs-logs (HTTP POST)| Metaphorical
    Express -->|yanmengs-logs| Metaphorical
    OmniBase -.->|直连监控大屏| MySQL
    OmniBase -.->|直连监控大屏| Weaviate
```

---

## 四、 快速开始指南

### 4.1 环境准备
- **运行环境**: Node.js (>= 20.x)、Python (>= 3.10)
- **依赖管理**: `pnpm` 
- **中间件依赖**: MySQL (>= 8.0)、Redis、MongoDB、Weaviate 实例

### 4.2 本地常规开发启动（Normal Startup）

本系统为微服务架构，开发环境下推荐按以下顺序分别启动各个子服务。具体各子项目的环境变量要求详见其各自的内部 `.env.example`。

**1. 启动 MCP 工具服务**
```bash
cd LifePilot_mcp
pnpm install
# 配置好 .env 里的 DATABASE_URL 后生成客户端与推表
pnpm prisma generate
pnpm prisma db push
# 运行
pnpm dev
# 默认端口：7000
```

**2. 启动 AI 后端服务**
```bash
cd LifePilotServer
pnpm install
# 配置 LLM API Key 与数据库链接参数
npm run dev
# 默认端口：5000 (前端将会默认请求该端口层)
```

**3. 启动 RAG Python 层服务**
```bash
cd ai-server
pip install -r requirements.txt
# 设置七牛云 OSS 及第三方服务密钥信息
uvicorn main:app --reload --port 8000
```

**4. 启动前端主应用（面向用户层）**
```bash
cd LifePilot
pnpm install
# 配置前端专属 .env.local 
pnpm dev
# 成功启动后主页访问地址为：http://localhost:3000
```

### 4.3 基于 Docker 的自动化部署配置（Docker-based Startup）

项目中每个微服务都已编排有完备的标准 `Jenkinsfile` 以及 `Dockerfile` 脚本支持。若需要将项目快速打包启动，也可用 Docker Direct 方式。

**构建与独立运行示例（以前端 LifePilot 服务部署为例）：**
```bash
cd LifePilot
# 步骤 1：构建基础镜像
docker build -t lifepilot:latest .

# 步骤 2：注入环境变量运行独立容器
docker run -d \
  --name lifepilot \
  -p 3000:3000 \
  -e DATABASE_URL="mysql://<user>:<pwd>@<host>:3306/<db>" \
  -e MONGODB_URI="mongodb://..." \
  -e REDIS_URL="rediss://..." \
  -e NEXTAUTH_SECRET="<your_secret>" \
  -e LIFEPILOT_SERVER_URL="http://<your-ip>:5000" \
  lifepilot:latest
```

> **备注**: 
> 1. 其他项目诸如 `LifePilotServer`, `ai-server`, `Metaphorical`, `OmniBase` 部署方式同理，进入各自根目录运行 `docker build` 并补齐内部所需的 `-e` 环境变量即可。
> 2. 原则上，线上集群统一采用 Jenkins 触发代码拉取、打包并分发到容器编排中的代理网关 (Nginx)。