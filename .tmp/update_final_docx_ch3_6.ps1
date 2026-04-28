param(
  [string]$DocxPath = 'F:\Graduation Project\最终论文.docx',
  [string]$NewImgDir = 'F:\Graduation Project\新图'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workspace = Split-Path -Parent $DocxPath
$tmpRoot = Join-Path $workspace '.tmp'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $tmpRoot ("最终论文.backup.before_ch3_6_update_$stamp.docx")
$workZip = Join-Path $tmpRoot ("final_docx_work_$stamp.zip")
$extractDir = Join-Path $tmpRoot ("final_docx_work_$stamp")

if (-not (Test-Path -LiteralPath $DocxPath)) { throw "Docx not found: $DocxPath" }
if (-not (Test-Path -LiteralPath $NewImgDir)) { throw "Image folder not found: $NewImgDir" }
if (-not (Test-Path -LiteralPath $tmpRoot)) { New-Item -ItemType Directory -Path $tmpRoot | Out-Null }

Copy-Item -LiteralPath $DocxPath -Destination $backup -Force
if (Test-Path -LiteralPath $extractDir) { Remove-Item -LiteralPath $extractDir -Recurse -Force }
if (Test-Path -LiteralPath $workZip) { Remove-Item -LiteralPath $workZip -Force }
Copy-Item -LiteralPath $DocxPath -Destination $workZip -Force
Expand-Archive -LiteralPath $workZip -DestinationPath $extractDir -Force

$docXmlPath = Join-Path $extractDir 'word\document.xml'
$relsPath = Join-Path $extractDir 'word\_rels\document.xml.rels'
$mediaDir = Join-Path $extractDir 'word\media'

[xml]$doc = Get-Content -LiteralPath $docXmlPath -Raw -Encoding UTF8
[xml]$rels = Get-Content -LiteralPath $relsPath -Raw -Encoding UTF8

$wordNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
$relNs = 'http://schemas.openxmlformats.org/package/2006/relationships'
$officeRelNs = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
$body = $doc.DocumentElement.SelectSingleNode('//*[local-name()="body"]')
if ($null -eq $body) { throw 'w:body not found' }

function Get-ParaText([System.Xml.XmlNode]$p) {
  return (@($p.SelectNodes('.//*[local-name()="t"]') | ForEach-Object { $_.InnerText }) -join '')
}

function Set-ParaText([System.Xml.XmlNode]$p, [string]$text) {
  $tNodes = @($p.SelectNodes('.//*[local-name()="t"]'))
  if ($tNodes.Count -eq 0) { return }
  $tNodes[0].InnerText = $text
  for ($k = 1; $k -lt $tNodes.Count; $k++) { $tNodes[$k].InnerText = '' }
}

function Get-ParagraphNodeAtIndex([int]$idx) {
  return $body.ChildNodes[$idx]
}

function ReplaceByIndex([hashtable]$map) {
  foreach ($k in ($map.Keys | Sort-Object {[int]$_})) {
    $idx = [int]$k
    $node = Get-ParagraphNodeAtIndex $idx
    if ($null -eq $node -or $node.LocalName -ne 'p') { continue }
    Set-ParaText -p $node -text $map[$k]
  }
}

# 1) 文本改写（仅第3-6章）
$textMap = @{
  175 = '第3章 可行性分析'
  177 = '本节从工程基础、资源投入和使用门槛三个维度评估系统落地可行性。当前版本已打通任务管理、对话交互、文档入库与检索问答链路，前后端分层和服务边界也已稳定。基于这些实现结果，本章重点判断方案能否在既定周期内持续迭代并稳定运行。'
  179 = '系统采用 TypeScript 与 Python 协同实现。前端以 Next.js 和 React 承担页面渲染与交互，后端负责流程编排与数据服务。这套技术组合在工程实践中较成熟，文档和社区支持完整，能够满足毕业设计阶段的开发与维护需求。'
  180 = '服务端按职责划分为业务编排服务、工具服务和知识服务。业务编排层负责对话与任务流程，工具服务执行受控数据读写，知识服务承担文档解析与语义检索。各服务通过 HTTP 接口协同，模块可独立升级，不会引发整体重构。'
  181 = '数据层采用 MySQL、MongoDB、Redis 与 Weaviate 组合。MySQL 保存结构化业务数据，MongoDB 存放对话与日志，Redis 负责缓存与定时队列，Weaviate 支撑向量检索。该分工与各数据库优势相匹配，有利于控制实现复杂度和后续迁移成本。'
  182 = '工程实现方面，项目已完成 Docker 部署链路和 Jenkins 发布链路，并通过多服务联调验证核心流程。文件上传、文档处理与语音能力已接入对象存储和 Python 服务。当前风险主要来自外部模型接口波动与网络抖动，系统通过服务解耦和降级路径进行缓冲。'
  184 = '课题方案主要依赖开源框架与通用云资源，初期投入集中在算力、存储与基础运维，不涉及专用硬件采购。前端、后端和知识服务都可在常规服务器部署，开发阶段可按需启停服务。'
  185 = '运行成本方面，系统采用模块化拆分策略。任务管理链路与知识检索链路可独立扩缩容，避免全量服务同步升级造成冗余开销。文档存储与向量检索按量计费，适合论文阶段的渐进式数据增长。'
  186 = '维护成本方面，项目已经形成容器化部署与持续集成流程，版本迭代不依赖大规模人工发布。综合开发投入、部署复杂度和运行开销，当前方案能够满足课题周期内的资源约束。'
  188 = '本课题面向日程管理与个人知识管理场景。目标用户在学习和工作中普遍接触待办清单、日历应用和对话助手，交互认知门槛较低。'
  189 = '界面围绕任务、日历、知识库和对话四类高频功能组织，主要操作入口保持固定。关键按钮提供明确标签与状态反馈，用户在少量尝试后即可完成创建任务、调整计划、上传文档和检索问答。涉及数据状态变更时，系统在提交前提供确认步骤，用于降低误操作风险。'
  190 = '当前版本已完成多模块联调，主要功能链路可以连续闭环。交互结构与用户既有习惯基本一致，能够支持日常使用场景。'
  192 = '3.1 节说明了技术与部署条件，3.2 节进一步验证需求覆盖与功能落地。评估重点不在模块数量，而在功能是否对应真实场景并能稳定执行。为此，本节从用户任务出发，逐项分析需求与功能之间的对应关系。'
  194 = '在日程管理场景中，系统需要支持任务拆解、任务创建、提醒调度和状态跟踪。用户输入计划后，系统应生成可执行任务，并在执行阶段持续更新状态。'
  195 = '在信息查询场景中，系统需要同时支持知识库检索和任务信息检索。查询结果应能直接回流到任务调整流程，保证信息利用链路连续。'
  196 = '在个人记录场景中，系统需要支持基于 WebRTC 的视频采集与保存能力，包括摄像头和麦克风采集、视频上传以及记录管理。'
  197 = '在交互场景中，系统需要降低输入负担和页面切换成本。为此，系统提供文本与语音双通道输入，并把任务、查询和记录能力收敛到统一界面。'
  202 = '功能可行性需要落实到可执行流程。针对 3.2.1 提出的各项需求，系统均给出完整处理链路，而不是停留在概念描述。'
  203 = '如图 3-2 所示，请求先进入对话入口，系统完成任务拆解并生成计划。涉及关键变更时，界面先展示确认信息，再写入任务存储。任务进入调度阶段后触发提醒与状态更新，执行结果回写到对话层，作为下一轮调整依据。'
  206 = '知识库及任务信息查询流程见图 3-3。请求进入系统后先做意图识别；知识库查询走语义召回与问答生成链路，任务信息查询走任务检索链路。两类结果在同一界面返回，可直接用于后续任务调整。'
  209 = '个人状态视频记录流程见图 3-4。用户进入记录页面后开启设备采集，系统将实时画面与音频写入记录流；结束录制后上传对象存储，并把时长、体积和资源地址写入记录库。'
  212 = '文本与语音双通道输入流程见图 3-5。用户可选择文本或语音输入，语音先转写为文本，再进入统一请求入口，随后路由到日程、查询或记录功能。'
  215 = '任务调度流程见图 3-6。任务创建或更新后，系统计算触发时间并写入调度队列。调度进程按时间窗口拉取到期任务，再根据当前状态决定提醒、重排或终止。'
  221 = '第4章 概要设计'
  223 = '系统设计目标对应三类高频业务：任务规划与执行、知识入库与问答、个人状态记录。整体设计要求三类业务在同一应用中连续完成，降低页面切换与信息割裂。同时，系统需支持持续迭代，因此前端、业务服务、工具服务和知识服务采用独立演进方式。'
  224 = '如图 4-1 所示，设计目标与系统能力形成明确映射，后续架构划分和流程组织均以该映射为依据。'
  230 = '系统采用四层架构。表现层对应 LifePilot，负责页面组织与交互；业务层对应 LifePilotServer，负责对话编排、流程路由和调度控制；工具层对应 LifePilot_mcp，负责任务域数据操作；能力层对应 ai-server，负责文档解析、检索问答和语音处理。数据层由 MySQL、MongoDB、Redis、向量存储和对象存储组成。'
  231 = '如图 4-3 所示，当前版本的部署节点与连接方向已经固定，主链路从前端进入业务服务，再按意图分发到工具服务和知识服务。'
  237 = '前端模块按用户任务组织，主页面覆盖清单、日历、知识库和记录四类入口。业务服务模块按能力划分，包含对话编排、任务规划、任务操作、出行规划、检索问答和提醒调度。工具服务负责任务与标签操作，知识服务负责文档解析、检索召回、语音识别和语音合成。'
  238 = '如图 4-5 所示，前端功能围绕 home 主路径组织，知识库和记录能力在同一应用内独立成页，并与任务模块联动。'
  241 = '如图 4-6 所示，业务服务内部通过路由节点组织多个工作流。不同工作流共享上下文准备节点，再进入各自处理链路。'
  245 = '第3章侧重业务流程可行性，本节转向结构设计。图 4-7 至图 4-11 分别展示职责分配、状态模型、事件协议、索引结构和调度协作。'
  246 = '如图 4-7 所示，系统按前端交互层、业务编排层、工具服务层和知识服务层分配职责，各层通过清晰接口协作。'
  249 = '如图 4-8 所示，任务对象通过状态迁移组织，提醒逻辑与超时逻辑都以状态变化作为触发条件。'
  252 = '如图 4-9 所示，对话链路采用事件协议返回内容。事件类型用于区分过程信息、结果信息和界面刷新信号。'
  255 = '如图 4-10 所示，知识服务先将原始文档切分为片段，再分别写入向量索引和图结构索引，问答阶段从双索引取回证据后生成结果。'
  258 = '如图 4-11 所示，调度模块与缓存、任务库和通知模块形成协作闭环。到期任务先从队列取出，再按任务状态执行提醒或结束处理。'
  262 = '数据层按职责分工。MySQL 承载任务、用户、标签与会话索引数据，MongoDB 承载对话消息与日志，Redis 承载调度队列。知识服务把文档切片写入向量存储并维护图结构索引，媒体文件统一进入对象存储。'
  263 = '如图 4-12 所示，当前项目的数据落点关系已经固定，业务域与存储域呈一对多映射。'
  266 = '接口层按通信对象分为三组：前端到业务服务、业务服务到工具服务、业务服务到知识服务。前端对话链路使用流式返回，文件和任务操作使用请求响应；服务间调用采用协议化或标准 HTTP 调用，接口语义围绕任务、知识和媒体三类业务组织。'
  267 = '如图 4-13 所示，不同接口通道承担不同职责，接口层与存储层之间没有跨域直连。'
  271 = '第5章 详细设计'
  273 = '登录层目标有两点：覆盖多入口身份接入，并在认证通过后统一下发会话凭证。系统当前提供密码登录、邮箱验证码登录、Google 登录和微信扫码登录四条入口，其中 Google 与微信流程包含首次登录建档分支。登录成功后返回短周期访问令牌，并由服务端写入长周期续签令牌。'
  274 = '认证链路采用“前端发起、认证校验、令牌写入、页面跳转”流程。密码与邮箱验证码登录走本地账号体系，Google 与微信登录走外部身份体系，再回写本地用户映射。图 5-1 展示统一认证流程。'
  284 = '任务子系统由任务实体、标签实体、过滤检索和提醒调度组成。业务主线不是简单的增删改查，而是计划生成、状态演进、提醒执行和结果回写的闭环。任务对象核心字段包括标题、描述、状态、优先级、截止时间、提醒开关、收藏标记与标签集合。'
  296 = '个人记录子系统面向日常复盘场景，包含视频录制、贴图叠加、资源上传、元数据管理和回放。系统在浏览器端将摄像画面绘制到画布，贴图直接作用于画布层，再由录制器导出视频。该路径将编辑和录制合并在同一流水线内，用户无需二次剪辑。'
  303 = '该子系统与任务子系统通过同一用户标识贯通，记录内容可作为后续任务调整的输入证据，形成“执行记录—计划修订”闭环。'
  306 = '智能代理并非单一问答器，而是处理写入型任务、分析型任务、开放规划、路径规划和知识问答五类请求。若将五类请求放在同一提示词内，约束会相互冲突：写入场景强调校验，开放问答强调覆盖，路线规划依赖外部工具。系统因此采用“入口路由 + 专用子图”编排，先判定任务类型，再进入对应流程。'
  307 = '路由节点输出目标工作流、置信度和决策理由。前两项用于服务端分发与兜底，决策理由通过流式事件回传到前端，便于用户理解当前分支。若路由结果解析失败，系统默认回退到知识问答分支，保证请求可达。'
  308 = '五条工作流中，前四条属于智能代理子系统：build_todo、what_to_do、trivel 和 howToGo；第五条为 rag，其工程细节在 5.5 节展开。图 5-8 给出路由分发关系。'
  311 = '四条代理工作流共享两个前置节点：时间注入节点和上下文准备节点。时间注入统一使用北京时间，避免容器时区差异导致截止时间偏移；上下文准备按“历史消息裁剪 + 当前任务快照”组织输入，控制模型上下文长度。'
  313 = 'build_todo 属于写入型流程，目标是将自然语言计划转换为可落库任务集合。流程主线为“生成、校验、确认、写入”，回环用于处理时间冲突、字段缺失和语义偏差。图 5-9 给出节点级流程。'
  318 = 'what_to_do 属于分析型流程，目标是将任务状态转为可执行建议。流程采用“事实生成 + 质量校验 + 结果整理”结构，并在回环次数过高时走直接输出分支，用于控制对话时延。图 5-10 给出节点级流程。'
  321 = '该流程把事实生成与表达整理分开处理，降低单节点同时承担两类目标时的偏移风险。'
  323 = 'trivel 面向开放型出行咨询，输入通常包含模糊偏好和连续追问。流程采用 ReAct 工具协同：规划节点按需调用地图与内容工具，回读结果后继续推理，直到形成可执行行程建议。图 5-11 给出节点级流程。'
  326 = '该流程不涉及数据库写入，重点放在信息补齐、规划收敛和答案生成的循环效率。'
  328 = 'howToGo 面向路径与通勤问题，流程约束是“先位置、后路线、再比较方案”。规划节点围绕起终点、交通方式和耗时估计编排工具，输出聚焦可执行路线。图 5-12 给出节点级流程。'
  333 = '为支撑多工作流统一接入，系统定义了统一事件协议，事件消息包含类型、节点标识和负载内容。协议层不直接暴露内部节点实现细节，前端依据事件类型更新界面状态。'
  336 = '从交互链路看，id 事件建立会话上下文，think 和 response 负责过程可视化与正文渲染，confirm 与 thread_id 组成可恢复中断握手，refresh 驱动业务数据重拉，done 标记流结束。异常时服务端发送 error 后再发送结束信号，前端按统一收尾逻辑释放连接。图 5-13 展示协议时序。'
  340 = 'rag 是第五条工作流，采用“入口分流 + RAG 深管线”结构。入口侧负责命中判断与回退，服务侧负责检索融合与答案生成。'
  384 = '向量层按集合管理用户知识，片段元数据保存用户标识、文件标识、来源信息和分片序号。图层保存实体与关系，供图检索分支使用。对象存储统一承接知识文件、语音和视频资源，业务层仅保存访问地址与元数据，不在数据库中存储二进制内容。'
  399 = '异常处理采用统一返回码和错误事件。同步接口统一返回 code/data/message 结构，流式接口异常时返回 error 事件并跟随完成事件。幂等控制集中在任务调度抢占、知识文件状态回写和扫码状态一次性消费三处。'
  402 = '部署环境基于 Ubuntu 长期维护版本构建。该版本在容器生态和运维工具方面支持稳定，维护周期也覆盖本课题交付周期。图 6-1 给出了生产部署拓扑：外部请求经网关进入前端与业务服务，再按功能分发到工具服务和知识服务。'
  403 = '部署初期先完成宿主机统一配置，包括软件仓库、时区、账号权限和网络策略。先处理系统层，再部署应用层，可以避免在同一窗口同时排查两类故障。'
  404 = '宿主机资源按最小可运行原则分配，运行时依赖统一放入镜像。即便迁移到新节点，也可以通过同一镜像与编排文件快速恢复服务状态。'
  405 = '系统服务采用 Docker 容器化封装。前端服务、业务服务、工具服务与 AI 服务以独立容器运行，通过容器网络完成内部通信，对外仅暴露代理层端口。该组织方式减少依赖冲突，也降低版本升级时的替换成本。'
  406 = '6.2 CI/CD 流水线部署'
  407 = '发布流程由 Jenkins 统一调度，流水线包含代码拉取、镜像构建、镜像推送、目标节点部署与健康检查。图 6-2 展示了执行路径。'
  408 = '每次发布都会生成独立构建记录，记录提交版本、执行编号和阶段状态。发布阶段采用“先启动新实例，再切换流量”策略；健康检查失败时中止切换并保留旧实例。'
  409 = '系统部署还复用 yanmengs-logs 与 yanmengs-rag-package 两个已发布 npm 包，分别用于统一日志上报和 AI 能力调用封装。'
  410 = '两个 npm 包作为代码依赖管理，不作为独立进程部署，也不进入容器编排。应用在发布阶段安装指定版本，可将“应用部署变更”与“SDK 发版变更”分开追踪。'
  411 = '6.3 访问与域名配置'
  412 = '公网入口由 Nginx Proxy Manager 统一维护。每个业务入口配置独立代理主机，条目内包含域名、目标地址、转发端口和访问策略。外部请求先到达 80 或 443 端口，再按域名路由到目标容器。'
  413 = 'HTTPS 证书由 Let''s Encrypt 自动签发和续期。证书生命周期由代理层管理后，业务服务只需关注接口逻辑与数据处理。域名或端口映射调整时，修改点集中在同一管理面板，验证路径更短。'
  414 = '当前生产环境使用四个公网域名，分别对应前端、业务服务、工具服务和 AI 服务入口。域名映射关系见表 6-1。'
  417 = '入口分离后，访问路径与职责边界保持清晰：前端域名承载用户交互，业务域名处理核心接口，工具域名提供工具调用，AI 域名承载模型与知识处理。后续扩容可按单入口压力独立调整。'
}
ReplaceByIndex -map $textMap

# 去除第3-6章中反引号，统一图题间距
for ($i = 175; $i -le 417; $i++) {
  $n = $body.ChildNodes[$i]
  if ($null -eq $n -or $n.LocalName -ne 'p') { continue }
  $txt = Get-ParaText $n
  if ([string]::IsNullOrWhiteSpace($txt)) { continue }
  $new = $txt -replace '`', ''
  $new = $new -replace '^图([3-6]-\d+)', '图 $1'
  $new = $new -replace '^图\s+([3-6]-\d+)\s+', '图 $1 '
  if ($new -ne $txt) { Set-ParaText -p $n -text $new }
}

# 2) 替换已有图3-1~图5-17对应图片
$imageRels = @{}
foreach ($rel in $rels.Relationships.Relationship) {
  if ($rel.Type -like '*image*') { $imageRels[$rel.Id] = $rel.Target }
}
$figRidMap = @{
  '3-1'='rId9';  '3-2'='rId10'; '3-3'='rId11'; '3-4'='rId12'; '3-5'='rId13'; '3-6'='rId14';
  '4-1'='rId15'; '4-2'='rId16'; '4-3'='rId17'; '4-4'='rId18'; '4-5'='rId19'; '4-6'='rId20';
  '4-7'='rId21'; '4-8'='rId22'; '4-9'='rId23'; '4-10'='rId24'; '4-11'='rId25'; '4-12'='rId26'; '4-13'='rId27';
  '5-1'='rId28'; '5-2'='rId29'; '5-3'='rId30'; '5-4'='rId31'; '5-5'='rId32'; '5-6'='rId33'; '5-7'='rId34';
  '5-8'='rId35'; '5-9'='rId36'; '5-10'='rId37'; '5-11'='rId38'; '5-12'='rId39'; '5-13'='rId40'; '5-14'='rId41';
  '5-15'='rId42'; '5-16'='rId43'; '5-17'='rId44'
}

foreach ($fig in $figRidMap.Keys) {
  $rid = $figRidMap[$fig]
  if (-not $imageRels.ContainsKey($rid)) { continue }
  $target = $imageRels[$rid]
  $src = Join-Path $NewImgDir ("图$fig.png")
  if (-not (Test-Path -LiteralPath $src)) { continue }
  $dest = Join-Path (Join-Path $extractDir 'word') ($target -replace '/', '\\')
  Copy-Item -LiteralPath $src -Destination $dest -Force
}

# 3) 新增图6-1~图6-7：关系+段落(引用文本+图片+图题)
if (-not (Test-Path -LiteralPath $mediaDir)) { New-Item -ItemType Directory -Path $mediaDir | Out-Null }

$relList = @($rels.Relationships.Relationship)
$maxRid = 0
foreach ($r in $relList) {
  if ($r.Id -match '^rId(\d+)$') {
    $num = [int]$matches[1]
    if ($num -gt $maxRid) { $maxRid = $num }
  }
}
$docPrMax = 0
foreach ($d in $doc.SelectNodes('//*[local-name()="docPr"]')) {
  $idAttr = $d.Attributes['id']
  if ($idAttr) {
    $idVal = [int]$idAttr.Value
    if ($idVal -gt $docPrMax) { $docPrMax = $idVal }
  }
}

$templateDrawing = $body.ChildNodes[199]
$templateCaption = $body.ChildNodes[200]
$templateNormal = $body.ChildNodes[402]
$templateH2 = $body.ChildNodes[401]

$fig6Rid = @{}
Add-Type -AssemblyName System.Drawing

foreach ($n in 1..7) {
  $src = Join-Path $NewImgDir ("图6-$n.png")
  if (-not (Test-Path -LiteralPath $src)) { throw "Missing figure image: $src" }
  $mediaName = "ch6_fig$n.png"
  $dest = Join-Path $mediaDir $mediaName
  Copy-Item -LiteralPath $src -Destination $dest -Force

  $maxRid++
  $rid = "rId$maxRid"
  $fig6Rid["6-$n"] = $rid

  $newRel = $rels.CreateElement('Relationship', $relNs)
  [void]$newRel.SetAttribute('Id', $rid)
  [void]$newRel.SetAttribute('Type', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image')
  [void]$newRel.SetAttribute('Target', "media/$mediaName")
  [void]$rels.DocumentElement.AppendChild($newRel)
}

function New-DrawingPara([string]$rid, [string]$name, [string]$imgPath) {
  $p = $doc.ImportNode($templateDrawing, $true)
  $blip = $p.SelectSingleNode('.//*[local-name()="blip"]')
  if ($null -eq $blip) { throw 'template drawing missing blip' }
  [void]$blip.SetAttribute('embed', $officeRelNs, $rid)

  $img = [System.Drawing.Image]::FromFile($imgPath)
  try {
    $targetCx = 5486400
    $targetCy = [int]([double]$targetCx * $img.Height / $img.Width)
    if ($targetCy -gt 9000000) {
      $targetCy = 9000000
      $targetCx = [int]([double]$targetCy * $img.Width / $img.Height)
    }
  }
  finally {
    $img.Dispose()
  }

  $extent = $p.SelectSingleNode('.//*[local-name()="extent"]')
  if ($extent) { $extent.SetAttribute('cx', [string]$targetCx); $extent.SetAttribute('cy', [string]$targetCy) }
  $xext = $p.SelectSingleNode('.//*[local-name()="xfrm"]/*[local-name()="ext"]')
  if ($xext) { $xext.SetAttribute('cx', [string]$targetCx); $xext.SetAttribute('cy', [string]$targetCy) }

  $script:docPrMax++
  $docPr = $p.SelectSingleNode('.//*[local-name()="docPr"]')
  if ($docPr) { $docPr.SetAttribute('id', [string]$script:docPrMax); $docPr.SetAttribute('name', $name) }
  $cNvPr = $p.SelectSingleNode('.//*[local-name()="cNvPr"]')
  if ($cNvPr) { $cNvPr.SetAttribute('id', [string]$script:docPrMax); $cNvPr.SetAttribute('name', $name) }

  return $p
}

function New-CaptionPara([string]$text) {
  $p = $doc.ImportNode($templateCaption, $true)
  Set-ParaText -p $p -text $text
  return $p
}

function New-NormalPara([string]$text) {
  $p = $doc.ImportNode($templateNormal, $true)
  Set-ParaText -p $p -text $text
  return $p
}

function New-H2Para([string]$text) {
  $p = $doc.ImportNode($templateH2, $true)
  Set-ParaText -p $p -text $text
  return $p
}

function Find-ParagraphByExact([string]$text) {
  foreach ($n in $body.ChildNodes) {
    if ($n.LocalName -ne 'p') { continue }
    if ((Get-ParaText $n) -eq $text) { return $n }
  }
  return $null
}

function Insert-After([System.Xml.XmlNode]$ref, [System.Xml.XmlNode[]]$nodes) {
  $cursor = $ref
  foreach ($n in $nodes) {
    $inserted = $body.InsertAfter($n, $cursor)
    $cursor = $inserted
  }
  return $cursor
}

# 图6-1 插入到 6.1 架构段后
$anchorA = Find-ParagraphByExact '系统服务采用 Docker 容器化封装。前端服务、业务服务、工具服务与 AI 服务以独立容器运行，通过容器网络完成内部通信，对外仅暴露代理层端口。该组织方式减少依赖冲突，也降低版本升级时的替换成本。'
if ($null -eq $anchorA) { throw 'Anchor A not found' }
$fig61Nodes = @(
  (New-DrawingPara -rid $fig6Rid['6-1'] -name 'Figure 6-1' -imgPath (Join-Path $NewImgDir '图6-1.png')),
  (New-CaptionPara -text '图 6-1 生产部署拓扑图')
)
[void](Insert-After -ref $anchorA -nodes $fig61Nodes)

# 图6-2 插入到 CI/CD 段后
$anchorB = Find-ParagraphByExact '每次发布都会生成独立构建记录，记录提交版本、执行编号和阶段状态。发布阶段采用“先启动新实例，再切换流量”策略；健康检查失败时中止切换并保留旧实例。'
if ($null -eq $anchorB) { throw 'Anchor B not found' }
$fig62Nodes = @(
  (New-DrawingPara -rid $fig6Rid['6-2'] -name 'Figure 6-2' -imgPath (Join-Path $NewImgDir '图6-2.png')),
  (New-CaptionPara -text '图 6-2 CI/CD 执行流水图')
)
[void](Insert-After -ref $anchorB -nodes $fig62Nodes)

# 图6-3~6-7 插入到 6.2 末尾
$anchorC = Find-ParagraphByExact '两个 npm 包作为代码依赖管理，不作为独立进程部署，也不进入容器编排。应用在发布阶段安装指定版本，可将“应用部署变更”与“SDK 发版变更”分开追踪。'
if ($null -eq $anchorC) { throw 'Anchor C not found' }

$nodesC = @(
  (New-H2Para -text '6.3 关键流程实现'),
  (New-NormalPara -text '中断恢复流程见图 6-3。以 build_todo 为例，流程在人工确认节点暂停，接收 accept 或 reject 后恢复执行，并将结果回写任务服务。'),
  (New-DrawingPara -rid $fig6Rid['6-3'] -name 'Figure 6-3' -imgPath (Join-Path $NewImgDir '图6-3.png')),
  (New-CaptionPara -text '图 6-3 build_todo 中断恢复流程图'),
  (New-NormalPara -text '前端对话链路的事件状态机见图 6-4。前端根据 id、think、response、confirm、refresh、done 等事件更新界面，流式过程可追踪。'),
  (New-DrawingPara -rid $fig6Rid['6-4'] -name 'Figure 6-4' -imgPath (Join-Path $NewImgDir '图6-4.png')),
  (New-CaptionPara -text '图 6-4 SSE 事件协议与前端状态图'),
  (New-NormalPara -text '任务提醒调度抢占流程见图 6-5。调度器先从到期集合取任务，再以抢占结果控制后续处理，避免同一任务被重复执行。'),
  (New-DrawingPara -rid $fig6Rid['6-5'] -name 'Figure 6-5' -imgPath (Join-Path $NewImgDir '图6-5.png')),
  (New-CaptionPara -text '图 6-5 提醒调度抢占流程图'),
  (New-NormalPara -text '知识入库的异步回写状态见图 6-6。文档处理完成后，服务通过状态回写接口更新业务库，前端据此刷新入库进度。'),
  (New-DrawingPara -rid $fig6Rid['6-6'] -name 'Figure 6-6' -imgPath (Join-Path $NewImgDir '图6-6.png')),
  (New-CaptionPara -text '图 6-6 知识入库异步回写状态图'),
  (New-NormalPara -text '视频录制与上传管线见图 6-7。采集流先在画布合成，再封装上传到对象存储，最后写入元数据并回显列表。'),
  (New-DrawingPara -rid $fig6Rid['6-7'] -name 'Figure 6-7' -imgPath (Join-Path $NewImgDir '图6-7.png')),
  (New-CaptionPara -text '图 6-7 视频录制与上传管线图')
)
$endC = Insert-After -ref $anchorC -nodes $nodesC

# 原 6.3 调整为 6.4
$old64 = Find-ParagraphByExact '6.3 访问与域名配置'
if ($old64 -ne $null) { Set-ParaText -p $old64 -text '6.4 访问与域名配置' }

# 6.5 小结（插在第7章前）
$chapter7 = Find-ParagraphByExact '第7章 系统测试与总结'
if ($null -eq $chapter7) { throw 'Chapter 7 heading not found' }
$summaryNodes = @(
  (New-H2Para -text '6.5 本章小结'),
  (New-NormalPara -text '本章围绕部署与运行给出了可落地方案：在架构层通过容器化与统一入口保持服务边界清晰，在发布层通过 CI/CD 流程控制版本变更风险，并补充了关键执行链路图用于验证流程可追踪性。由此，系统在单机环境下具备可复现、可回退和可维护的运行基础。')
)
[void](Insert-After -ref ($chapter7.PreviousSibling) -nodes $summaryNodes)

# 4) 保存并打包回 docx
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($docXmlPath, $doc.OuterXml, $utf8NoBom)
[System.IO.File]::WriteAllText($relsPath, $rels.OuterXml, $utf8NoBom)

$outZip = Join-Path $tmpRoot ("final_docx_out_$stamp.zip")
if (Test-Path -LiteralPath $outZip) { Remove-Item -LiteralPath $outZip -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($extractDir, $outZip)
Copy-Item -LiteralPath $outZip -Destination $DocxPath -Force

Write-Output ("updated-docx: " + $DocxPath)
Write-Output ("backup-docx: " + $backup)
