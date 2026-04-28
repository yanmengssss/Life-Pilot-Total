# 东 莞 理 工 学 院

本 科 毕 业 设 计

毕业设计题目：基于Next.js的智能生活管家系统的设计与实现

学生姓名：黄震烁

学 号：2022463030709

学 院：计算机科学与技术学院（网络空间安全学院、软件学院）

专业班级：2022计算机科学与技术（工业软件方向）1班

指导教师姓名及职称：闫白 讲师

起止时间： 2025 年 12 月—— 2026 年 5 月

摘 要

面向个人事务管理、资料检索和多模态交互并存的使用场景，本项目设计并实现了基于 Next.js 的智能生活管家系统 LifePilot。针对传统待办工具难以处理自然语言输入、跨资料联动能力不足，以及大语言模型直接进入业务链路后容易带来结果不稳和访问边界不清的问题，系统采用前后端分离与多服务协作架构，在前端构建任务管理、对话交互、知识库和记录查看等功能，在后端引入 LangGraph 工作流、MCP 工具调用与检索增强生成机制，将自然语言理解、业务确认、知识检索和提醒调度收进同一条受控链路。测试结果表明，系统已能够稳定完成任务创建、知识问答、提醒触发和多端访问等主要流程；在知识库测试中，60 次上传、60 次查询与 60 次召回验证均成功完成，平均响应时间为 285 ms，整体准确度为 87.2%，查全率和查准率分别为 92.5% 与 91.7%。该系统说明“大语言模型 + 工作流编排 + 受控工具访问”能够落到个人智能助理的实际场景中，也为后续完善个性化建模、复杂文档处理和执行控制提供了可继续推进的基础。

关键词 Next.js、任务管理、检索增强生成、多模态交互、智能助理

Abstract

For usage scenarios where personal affairs management, information retrieval, and multimodal interaction coexist, this project designed and implemented LifePilot, an intelligent life assistant system based on Next.js. To address the limitations of traditional to-do tools in handling natural language input, their weak cross-resource linkage capability, and the instability and unclear access boundaries that can arise when large language models are directly inserted into business workflows, the system adopts a front-end/back-end decoupled, multi-service collaborative architecture. On the front end, it provides functions such as task management, conversational interaction, knowledge-base management, and record viewing. On the back end, it introduces a LangGraph workflow, MCP tool invocation, and a retrieval-augmented generation mechanism, integrating natural language understanding, business confirmation, knowledge retrieval, and reminder scheduling into a single controlled pipeline. Test results show that the system can reliably complete major workflows, including task creation, knowledge Q&A, reminder triggering, and multi-device access. In knowledge-base testing, all 60 uploads, 60 queries, and 60 retrieval validation runs were completed successfully, with an average response time of 285 ms, overall accuracy of 87.2%, recall of 92.5%, and precision of 91.7%. The system indicates that the combination of large language models, workflow orchestration, and controlled tool access can be effectively applied to real-world personal assistant scenarios, and it provides a solid foundation for further work on personalized modeling, complex document processing, and execution control.

Keywords Next.js, task management, retrieval-augmented generation, multimodal interaction, intelligent assistant

目 录

第1章 绪论 1

## 1.1 研究背景与研究意义 1

## 1.2 研究内容与论文结构安排 1

第2章 相关技术与开发工具 2

## 2.1 Web 前后端开发框架 2

### 2.1.1 项目组成 2

### 2.1.2 Next.js 前端框架 2

### 2.1.3 Express 后端框架 3

### 2.1.4 MobX 状态管理 3

### 2.1.5 SSE 通信方式 3

## 2.2 智能服务开发工具 3

### 2.2.1 大语言模型服务 4

### 2.2.2 LangGraph 工作流框架 4

### 2.2.3 MCP 工具调用协议 4

## 2.3 数据存储与数据访问工具 5

### 2.3.1 MySQL 5

### 2.3.2 MongoDB 5

### 2.3.3 Redis 5

### 2.3.4 Qdrant 5

### 2.3.5 Neo4j 5

### 2.3.6 对象存储 6

### 2.3.7 Prisma ORM 6

## 2.4 知识库服务框架 6

### 2.4.1 FastAPI 框架 6

第3章 系统需求分析 7

## 3.1 用户与智能生活管家业务需求分析 7

### 3.1.1 应用场景概述 7

### 3.1.2 用户特征分析 7

### 3.1.3 业务流程分析 8

### 3.1.4 需求目标转化 8

## 3.2 核心功能需求分析 8

### 3.2.1 任务管理 8

### 3.2.2 AI 对话 9

### 3.2.3 RAG 知识库 9

### 3.2.4 语音交互 9

### 3.2.5 出行规划 9

### 3.2.6 自我记录 9

## 3.3 性能与可靠性需求分析 9

### 3.3.1 性能需求 10

### 3.3.2 可靠性需求 10

### 3.3.3 可维护性需求 10

第4章 系统总体设计 11

## 4.1 系统功能模块划分与业务流程设计 11

### 4.1.1 系统模块架构 11

### 4.1.2 业务流程设计 11

## 4.2 系统整体架构与 Agent 协同设计 12

### 4.2.1 分层架构设计 12

### 4.2.2 Agent 协同机制 13

## 4.3 核心数据模型与模块关系设计 16

### 4.3.1 实体数据模型 16

### 4.3.2 模块间关系 17

## 4.4 知识子系统补充设计 18

第5章 系统实现与关键问题解决 20

## 5.1 用户模块与多交互方式实现 20

### 5.1.1 前端实现组织方式 20

### 5.1.2 语音交互方案 21

### 5.1.3 响应式布局方案 21

### 5.1.4 数据持久化与离线支持 22

## 5.2 Agent设计与用户意图处理实现 22

### 5.2.1 LangGraph 工作流设计 22

### 5.2.2 MCP 协议实现 24

### 5.2.3 RAG 检索实现 25

### 5.2.4 意图路由实现 25

## 5.3 WebRTC记录模块与提醒机制实现 26

### 5.3.1 Canvas 渲染管线设计 29

### 5.3.2 录制与编码方案 29

### 5.3.3 提醒调度机制 31

### 5.3.4 SSE 流式输出设计 32

第6章 系统编码及部署 35

## 6.1 部署方案 35

### 6.1.1 Docker 容器组织 35

### 6.1.2 Nginx 统一入口 36

### 6.1.3 Jenkins 流水线 36

## 6.2 前端关键实现 38

### 6.2.1 记录画布渲染 38

## 6.3 后端关键实现 39

### 6.3.1 RAG 检索服务 39

### 6.3.2 提醒调度服务 40

第7章 系统测试与总结 42

## 7.1 后端服务与业务功能测试 42

### 7.1.1 知识库准确度测试 42

### 7.1.2 任务提醒调度测试 44

### 7.1.3 MCP服务调用测试 46

### 7.1.4 用户鉴权与数据隔离测试 48

## 7.2 UI兼容与适配性测试 49

### 7.2.1 多终端界面适配测试 49

### 7.2.2 多浏览器兼容性测试 52

第8章 总结与展望 54

## 8.1 毕业设计工作总结 54

## 8.2 未来拓展与研究展望 54

参考文献 56

致谢 57

第1章 绪论

## 1.1 研究背景与研究意义

移动互联网普及后，个人日程、待办事项、学习资料和沟通记录被拆散到不同应用中。用户处理学习、工作和生活事务时，常常要在聊天工具、日历、备忘录和文档之间来回切换，再把任务内容、时间信息和提醒方式重新整理一遍。事务一多，真正耗费精力的往往不是任务本身，而是把这些分散信息重新拼回一条可执行安排。

现有待办系统更适合处理表单式录入。输入一旦变成自然语言描述，或者任务判断还要参考历史安排、文档资料和外部信息，规则驱动的方法就很难继续扩展。大语言模型为此提供了新的实现入口，但模型结果若直接进入业务通路，随之而来的问题也同样明显，包括输出不稳定、权限边界不清和数据访问失控。

基于上述背景，本项目把任务管理放在业务中心，将智能对话、知识库服务和语音交互组织到同一系统框架中。项目关注的并不只是模型如何接入界面，更关心自然语言任务生成、用户确认、工具调用和知识问答怎样落到同一业务闭环里。从研究和工程实现两个角度看，这项工作为个人智能助理场景下的大语言模型落地提供了一个较完整的参考样例。

## 1.2 研究内容与论文结构安排

本项目围绕个人事务管理场景中的智能化需求展开。文章先分析任务创建、信息整理、提醒跟踪和知识检索中的实际问题，再给出系统需求、总体设计、关键实现、部署方案和测试结果，用来验证方案的可行性。

全文共分为八章。第1章交代研究背景和论文安排。第2章介绍系统实现所使用的框架、数据库与开发工具。第3章从业务需求、功能需求和性能可靠性三个方面展开分析。第4章给出系统总体设计。第5章说明关键功能的实现过程。第6章介绍系统编码组织、服务部署与持续集成方案。第7章通过功能测试和典型场景验证系统可用性。第8章总结全文工作，并讨论后续完善方向。

第2章 相关技术与开发工具

## 2.1 Web 前后端开发框架

### 2.1.1 项目组成

系统并非单体实现，而是由主业务模块与若干配套模块协同组成。各模块采用的技术栈及职责划分见表。

表2-1 项目组成与职责

| 模块 | 技术栈 | 职责 |
| --- | --- | --- |
| LifePilot | Next.js 16、React 19、MobX | 用户侧前端界面与交互 |
| LifePilotServer | Express 5、LangGraph | 智能对话入口与业务服务 |
| LifePilot_mcp | Express、Prisma、MCP SDK | 工具调用服务与任务数据操作 |
| ai-server | FastAPI、Qdrant、Neo4j | 文档处理与知识库服务 |
| Metaphorical | Next.js 16、MongoDB | 日志展示与运行观测 |
| OmniBase | Next.js 16、MySQL、Redis、MongoDB | 多数据源管理与调试 |
| yanmengs-ragPackage | TypeScript | 前端统一调用 SDK |
| yanmengs-logs | TypeScript | 日志采集与上报 SDK |

表2-2 项目启动环境

| Next.js | 16.22 |
| --- | --- |
| React | 19.1.0 |
| Express | 5.1 |
| Node | >20 |
| Python | >3.10 |
| Prisma | >6.0 |
| MySQL | 8.0 |
| Redis | 7-alpine |
| MondoDB | 6 |
| Qdrant | v1.16.3 |
| Neo4j | 5 |
| Docker | 3.8 |

### 2.1.2 Next.js 前端框架

前端主应用基于 Next.js 构建，负责登录、任务列表、日历、知识库、对话抽屉和自我记录等页面。该框架建立在 React 之上，用来统一页面路由、组件开发和前端构建流程会顺手很多。

项目使用 App Router 管理页面结构，把不同业务页面放在同一前端工程内，后续维护和部署都更直接。在这个项目里，Next.js 主要就是用户界面的开发框架[1]。

### 2.1.3 Express 后端框架

业务后端与工具服务统一采用 Express 实现。其中，LifePilotServer 负责接收前端请求并协调智能服务与数据层；LifePilot_mcp 负责封装任务、标签等工具接口。

Express 提供了较轻的 Web 服务框架，便于组织路由、中间件和接口转发逻辑。主业务后端与工具服务都运行在 Node.js 环境中，统一采用 Express 后，服务层的实现风格也更容易保持一致。

### 2.1.4 MobX 状态管理

前端共享状态由 MobX 管理，覆盖任务列表、筛选条件、用户信息、知识库文件状态和对话面板状态等内容。

采用 MobX 的原因比较直接：页面之间存在不少共享状态，若全部依赖组件逐层传递，维护成本会明显上升。将这部分状态集中起来后，界面更新与状态同步会更稳定，它本身并不负责业务规则。

### 2.1.5 SSE 通信方式

智能对话场景采用 SSE 传输流式结果，前端可以逐步接收后端返回内容，并及时更新对话界面。

此处将 SSE 作为通信方式使用，用于支撑流式文本返回。更具体的交互过程将在后文结合实现部分展开。

## 2.2 智能服务开发工具

### 2.2.1 大语言模型服务

系统接入大语言模型服务处理自然语言输入、任务建议生成和知识问答等任务。不同模型承担的职责会在后续实现章节说明，这里先交代项目确实依赖独立的模型服务，这也是 AI Agent 方案能落地的前提之一[4][5]。

从技术选型看，大语言模型服务是智能功能得以落地的前提之一，它与前端框架、后端框架和数据库共同构成系统运行环境[5]。

### 2.2.2 LangGraph 工作流框架

LifePilotServer 中的智能流程基于Next.js的智能生活管家系统的设计与实现用于管理带状态的智能工作流，放在这个项目里，主要作用就是把路由、工具调用和结果回收串成可控流程[5]。

### 2.2.3 MCP 工具调用协议

项目通过 MCP 组织模型侧的工具调用能力，并在 LifePilot_mcp 模块中实现相关服务。任务创建、任务查询、任务更新和标签操作等能力，都经由这层服务对外提供，这样模型侧的意图和真实业务写入就不会直接绑死在一起[4]。

从选型角度看，MCP 的价值就在于先把接口形式统一下来，模型生成与业务执行也就能拆开处理。对项目来说，这一步很实用，因为后面补工具、换流程时不会把整条链路一起带乱[4][5]。

### 2.2.4 reAct 推理模式

ReAct 是将推理过程与行动过程结合的智能体组织方式。模型在回答问题时，不是一次性输出结果，而是先判断当前信息是否充足；当信息不足时，先调用外部工具获取证据，再基于返回内容继续推理。该模式适合处理依赖实时信息或外部知识的问题。

从方法特征看，ReAct 的重点不在“调用了多少工具”，而在“调用行为是否由推理过程驱动”。工具调用结果会回流到后续推理阶段，模型据此更新判断，直到形成满足问题约束的回答。该机制有助于降低纯语言猜测带来的偏差，提高回答与外部事实的一致性。

### 2.2.5 Human In Loop

Human-in-the-loop是指在自动化链路中设置人工决策节点。模型负责生成候选结果并提供依据，用户负责对关键动作作出最终确认[5]。该机制的核心目标是把“模型建议”与“业务执行”明确分离。

在任务管理场景中，新增与修改操作会影响提醒调度、统计结果和日历展示。若模型输出直接落库，偏差会沿后续流程传播。将确认节点放在写入前，可以把多数问题控制在候选阶段，降低错误扩散风险。

该机制并不否定自动化能力，而是对自动化结果增加执行边界。系统仍可利用模型完成任务理解与方案生成，用户只在关键节点进行确认。这样既保留效率提升，也保持结果可控。

## 2.3 数据存储与数据访问工具

### 2.3.1 MySQL

MySQL 是系统的主业务数据库，主要保存用户、任务、标签和会话索引等结构化数据。任务管理相关的核心业务数据都放在这里，原因也比较直接：这类结构化数据用关系型数据库来管更稳妥[2]。

### 2.3.2 MongoDB

MongoDB 用来保存聊天消息明细和运行日志等文档型数据。Metaphorical 等日志相关模块也依赖它存储日志内容。

### 2.3.3 Redis

Redis 负责缓存短期状态数据，同时保存提醒相关的队列与调度数据，在系统里对应缓存与临时状态组件。

### 2.3.4 Qdrant

在知识库子系统中，Qdrant 用作向量数据库，负责存储文档向量及检索相关数据，为知识问答阶段提供向量检索支撑。

### 2.3.5 Neo4j

Neo4j 在知识库中承担图数据库角色，主要保存实体关系数据，并与 Qdrant 共同构成知识检索的数据支撑层。

### 2.3.6 对象存储

对象存储用于保存原始文档、图片、视频和音频等文件资源。系统只在业务数据库中保留文件地址与元数据，不直接保存文件本体。

### 2.3.7 Prisma ORM

项目在 Node.js 服务中使用 Prisma 访问 MySQL。Prisma 用于统一管理数据模型和数据库操作接口，和 MySQL 配合后，数据结构、迁移脚本与查询代码更容易放在同一套约束下维护[2]。

## 2.4 知识库服务框架

### 2.4.1 FastAPI 框架

ai-server 基于 FastAPI 构建，用于提供文档处理和知识问答接口。该模块是系统中的 Python 服务部分。

FastAPI 在这里承担知识库服务接口，为前端和业务后端提供统一调用入口。