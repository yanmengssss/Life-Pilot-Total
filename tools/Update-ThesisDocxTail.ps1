param(
    [Parameter(Mandatory = $true)]
    [string]$InputDocx,

    [string]$OutputDocx = $InputDocx,

    [string]$BackupDocx
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$WordNs = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

function Escape-XmlText {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return [System.Security.SecurityElement]::Escape($Text)
}

function New-TempFragmentRoot {
    return "<root xmlns:w='$WordNs'>__CONTENT__</root>"
}

function Import-FragmentChildren {
    param(
        [xml]$Document,
        [string]$InnerXml
    )

    $temp = New-Object System.Xml.XmlDocument
    $temp.LoadXml((New-TempFragmentRoot).Replace("__CONTENT__", $InnerXml))
    $result = @()
    foreach ($child in $temp.DocumentElement.ChildNodes) {
        $result += $Document.ImportNode($child, $true)
    }
    return ,$result
}

function Append-FragmentToNode {
    param(
        [xml]$Document,
        [System.Xml.XmlNode]$Parent,
        [string]$InnerXml
    )

    foreach ($node in (Import-FragmentChildren -Document $Document -InnerXml $InnerXml)) {
        [void]$Parent.AppendChild($node)
    }
}

function Insert-FragmentBeforeNode {
    param(
        [xml]$Document,
        [System.Xml.XmlNode]$Parent,
        [System.Xml.XmlNode]$BeforeNode,
        [string]$InnerXml
    )

    foreach ($node in (Import-FragmentChildren -Document $Document -InnerXml $InnerXml)) {
        [void]$Parent.InsertBefore($node, $BeforeNode)
    }
}

function Get-ParagraphText {
    param(
        [System.Xml.XmlNode]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns
    )

    $texts = @($Paragraph.SelectNodes(".//w:t", $Ns) | ForEach-Object { $_.InnerText })
    return ($texts -join "").Trim()
}

function Find-ParagraphByPrefix {
    param(
        [xml]$Document,
        [System.Xml.XmlNamespaceManager]$Ns,
        [string]$Prefix
    )

    foreach ($p in $Document.SelectNodes("//w:body/w:p", $Ns)) {
        $text = Get-ParagraphText -Paragraph $p -Ns $Ns
        if ($text.StartsWith($Prefix)) {
            return $p
        }
    }
    return $null
}

function New-RunXml {
    param(
        [string]$Text,
        [int]$Size = 24,
        [bool]$Bold = $false,
        [bool]$Superscript = $false,
        [string]$AsciiFont = "Times New Roman",
        [string]$EastAsiaFont = "SimSun"
    )

    $rPr = "<w:rPr><w:rFonts w:ascii=""$AsciiFont"" w:hAnsi=""$AsciiFont"" w:eastAsia=""$EastAsiaFont""/><w:sz w:val=""$Size""/><w:szCs w:val=""$Size""/>"
    if ($Bold) {
        $rPr += "<w:b/><w:bCs/>"
    }
    if ($Superscript) {
        $rPr += "<w:vertAlign w:val=""superscript""/>"
    }
    $rPr += "</w:rPr>"
    $escaped = Escape-XmlText $Text
    return "<w:r>$rPr<w:t xml:space=""preserve"">$escaped</w:t></w:r>"
}

function New-ParagraphXml {
    param(
        [string]$Text,
        [ValidateSet("chapter", "section", "subsection", "body", "caption", "reference")]
        [string]$Kind
    )

    switch ($Kind) {
        "chapter" {
            $pPr = '<w:pPr><w:pageBreakBefore/><w:jc w:val="center"/><w:spacing w:line="400" w:lineRule="exact" w:before="0" w:after="0"/></w:pPr>'
            $run = New-RunXml -Text $Text -Size 32 -Bold $true
        }
        "section" {
            $pPr = '<w:pPr><w:spacing w:line="400" w:lineRule="exact" w:before="0" w:after="0"/></w:pPr>'
            $run = New-RunXml -Text $Text -Size 28 -Bold $true
        }
        "subsection" {
            $pPr = '<w:pPr><w:spacing w:line="400" w:lineRule="exact" w:before="0" w:after="0"/></w:pPr>'
            $run = New-RunXml -Text $Text -Size 24 -Bold $true
        }
        "body" {
            $pPr = '<w:pPr><w:ind w:firstLineChars="200"/><w:spacing w:line="400" w:lineRule="exact" w:before="0" w:after="0"/></w:pPr>'
            $run = New-RunXml -Text $Text -Size 24
        }
        "caption" {
            $pPr = '<w:pPr><w:jc w:val="center"/><w:spacing w:line="320" w:lineRule="exact" w:before="120" w:after="60"/></w:pPr>'
            $run = New-RunXml -Text $Text -Size 22 -Bold $true
        }
        "reference" {
            $pPr = '<w:pPr><w:ind w:left="420" w:hanging="420"/><w:spacing w:line="400" w:lineRule="exact" w:before="0" w:after="0"/></w:pPr>'
            $run = New-RunXml -Text $Text -Size 24
        }
    }

    return "<w:p>$pPr$run</w:p>"
}

function New-TableCellXml {
    param(
        [string]$Text,
        [int]$Width,
        [bool]$Bold = $false
    )

    $pPr = '<w:pPr><w:jc w:val="center"/><w:spacing w:line="400" w:lineRule="exact" w:before="0" w:after="0"/></w:pPr>'
    $run = New-RunXml -Text $Text -Size 22 -Bold $Bold
    return "<w:tc><w:tcPr><w:tcW w:w=""$Width"" w:type=""dxa""/></w:tcPr><w:p>$pPr$run</w:p></w:tc>"
}

function New-TableXml {
    param([object[]]$Rows)

    if ($Rows.Count -lt 2) { return "" }

    $columnCount = $Rows[0].Count
    $baseWidth = [int][math]::Floor(9070 / $columnCount)
    $widths = @()
    for ($i = 0; $i -lt $columnCount; $i++) {
        $widths += $baseWidth
    }
    $widths[$columnCount - 1] += 9070 - ($baseWidth * $columnCount)

    $grid = ($widths | ForEach-Object { "<w:gridCol w:w=""$_""/>" }) -join ""
    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('<w:tbl>')
    [void]$builder.Append('<w:tblPr><w:tblW w:w="9070" w:type="dxa"/><w:tblBorders><w:top w:val="single" w:sz="12" w:space="0" w:color="000000"/><w:left w:val="nil"/><w:bottom w:val="single" w:sz="12" w:space="0" w:color="000000"/><w:right w:val="nil"/><w:insideH w:val="single" w:sz="6" w:space="0" w:color="000000"/><w:insideV w:val="nil"/></w:tblBorders></w:tblPr>')
    [void]$builder.Append("<w:tblGrid>$grid</w:tblGrid>")

    for ($rowIndex = 0; $rowIndex -lt $Rows.Count; $rowIndex++) {
        [void]$builder.Append('<w:tr>')
        for ($colIndex = 0; $colIndex -lt $columnCount; $colIndex++) {
            $value = if ($colIndex -lt $Rows[$rowIndex].Count) { [string]$Rows[$rowIndex][$colIndex] } else { "" }
            [void]$builder.Append((New-TableCellXml -Text $value -Width $widths[$colIndex] -Bold ($rowIndex -eq 0)))
        }
        [void]$builder.Append('</w:tr>')
    }

    [void]$builder.Append('</w:tbl>')
    return $builder.ToString()
}

function Replace-BodyNodesBetweenParagraphs {
    param(
        [xml]$Document,
        [System.Xml.XmlNamespaceManager]$Ns,
        [string]$StartPrefix,
        [string]$EndPrefix,
        [string]$ReplacementXml
    )

    $start = Find-ParagraphByPrefix -Document $Document -Ns $Ns -Prefix $StartPrefix
    if ($null -eq $start) {
        throw "未找到范围起点：$StartPrefix"
    }

    $end = Find-ParagraphByPrefix -Document $Document -Ns $Ns -Prefix $EndPrefix
    if ($null -eq $end) {
        throw "未找到范围终点：$EndPrefix"
    }

    $body = $Document.SelectSingleNode("//w:body", $Ns)
    $current = $start
    while ($null -ne $current -and $current -ne $end) {
        $toRemove = $current
        $current = $current.NextSibling
        [void]$body.RemoveChild($toRemove)
    }

    Insert-FragmentBeforeNode -Document $Document -Parent $body -BeforeNode $end -InnerXml $ReplacementXml
}

function Build-NewChapter7Xml {
    $items = New-Object System.Collections.Generic.List[string]

    $items.Add((New-ParagraphXml -Text "第7章 系统测试" -Kind "chapter"))
    $items.Add((New-ParagraphXml -Text "本章关注系统在真实使用链路中的可用性与稳定性。第5章和第6章已经给出关键实现与部署方式，但系统是否能够稳定完成知识检索、任务调度、工具调用和界面交互，还需要通过测试结果加以验证。本章先讨论后端服务与业务链路，再讨论前端界面在不同终端和浏览器中的适配情况，并在章末归纳当前版本的主要结论。" -Kind "body"))

    $items.Add((New-ParagraphXml -Text "7.1 后端服务与业务功能测试" -Kind "section"))
    $items.Add((New-ParagraphXml -Text "后端部分承担知识处理、任务写入、提醒调度和权限控制，任何一处失稳都会直接影响用户结果。测试时不只看接口能否返回，还要观察响应时间、结果一致性和异常输入下的保护行为。因此，本节分别从知识库、提醒调度、MCP 服务和数据隔离四个方面展开。" -Kind "body"))

    $items.Add((New-ParagraphXml -Text "7.1.1 知识库准确度测试" -Kind "subsection"))
    $items.Add((New-ParagraphXml -Text "知识库承担文档入库与检索问答两项基础能力。若召回结果偏离原文语义，后续回答即使语言流畅，也难以保持内容可靠。因此，测试重点放在入库稳定性、检索响应时间和召回相关度三项指标上。测试于 2026 年 4 月 7 日 00:30:00 至 00:45:00 进行，样本共 60 份，覆盖纯文本、文档、图片描述、结构化数据和混合内容五类材料。每份样本均执行上传、查询与召回验证三个步骤，共形成 180 次操作记录。样本构成如表 7-1 所示。" -Kind "body"))
    $items.Add((New-ParagraphXml -Text "表 7-1 知识库测试样本构成" -Kind "caption"))
    $items.Add((New-TableXml -Rows @(
        @("内容类型", "文件数量", "占比"),
        @("纯文本（.txt）", "20", "33.3%"),
        @("文档（.md）", "15", "25.0%"),
        @("图片描述（.png.desc）", "10", "16.7%"),
        @("结构化数据（.json）", "5", "8.3%"),
        @("混合内容", "10", "16.7%")
    )))
    $items.Add((New-ParagraphXml -Text "从整体结果看，知识库在常见文本场景下已经能够提供较稳定的召回支持。60 次上传全部成功，说明文档接收、解析与索引链路在测试环境下运行正常；60 次查询和 60 次召回验证同样全部完成，没有出现失败记录。表 7-2 给出了总体指标。平均响应时间为 285 ms，中位数为 256 ms，说明多数请求能够在亚秒级范围内返回结果。准确度方面，整体准确度为 87.2%，查全率为 92.5%，查准率为 91.7%；高相关样本共有 35 份，占比 58.3%，低相关样本仅 5 份，占比 8.3%。这些数据表明，知识库链路在语义较完整的文本材料上已经能够把查询较稳定地限制在相关证据范围内。" -Kind "body"))
    $items.Add((New-ParagraphXml -Text "表 7-2 知识库总体测试结果" -Kind "caption"))
    $items.Add((New-TableXml -Rows @(
        @("指标", "数值"),
        @("上传成功率", "100%"),
        @("查询成功率", "100%"),
        @("召回验证成功率", "100%"),
        @("平均响应时间", "285 ms"),
        @("最快响应时间", "89 ms"),
        @("最慢响应时间", "720 ms"),
        @("响应时间中位数", "256 ms"),
        @("整体准确度", "87.2%"),
        @("查全率", "92.5%"),
        @("查准率", "91.7%"),
        @("高相关样本占比", "58.3%"),
        @("中相关样本占比", "33.3%"),
        @("低相关样本占比", "8.3%")
    )))
    $items.Add((New-ParagraphXml -Text "按内容类型进一步观察，纯文本与文档类样本表现最稳定。人工智能定义、API 接口文档等材料的相关度达到 98%，响应时间分别为 95 ms 和 156 ms，说明语义清晰、术语明确的材料更容易被向量召回与关键词匹配同时命中。图片描述与结构化数据的平均响应时间分别为 312 ms 和 356 ms，明显高于纯文本的 198 ms，反映出短描述补全和嵌套结构解析会带来额外开销。混合内容是该组测试中的主要薄弱点，平均相关度为 71.2%，低相关样本也集中分布在该类型。表 7-3 列出了全部低相关样本。结合前文实现可以看出，当前检索链路在单一文本语料上已有较好效果，但跨模态信息尚未形成足够稳定的联合表示，因此当图片描述、结构化字段和说明文本同时出现时，相关度下降更明显。" -Kind "body"))
    $items.Add((New-ParagraphXml -Text "表 7-3 低相关召回样本统计" -Kind "caption"))
    $items.Add((New-TableXml -Rows @(
        @("文件名", "类型", "响应时间", "相关度"),
        @("nev_overview.txt", "混合内容", "345 ms", "68%"),
        @("ecommerce_architecture.png.desc", "混合内容", "412 ms", "65%"),
        @("nev_architecture.png.desc", "混合内容", "398 ms", "62%"),
        @("ai_architecture.png.desc", "混合内容", "378 ms", "58%"),
        @("ecommerce_data.json", "混合内容", "425 ms", "55%")
    )))
    $items.Add((New-ParagraphXml -Text "知识库准确度测试表明，系统已经具备支撑日常知识问答的基础条件：入库链路稳定，文本类材料检索较快，绝大多数样本能够返回中高相关结果。后续优化重点应放在混合内容的索引组织方式，以及短文本图片描述的语义补充上。完成这两项调整后，复杂资料场景下的召回质量才更有可能接近纯文本材料的表现。" -Kind "body"))

    $items.Add((New-ParagraphXml -Text "7.1.2 任务提醒调度测试" -Kind "subsection"))
    $items.Add((New-ParagraphXml -Text "调度链路的关键不在界面按钮，而在任务生成后能否稳定进入执行队列，并在到期时按照既定规则触发。若定时提醒、条件触发和周期性提醒混在同一套机制中处理不当，就容易出现重复触发、遗漏触发或优先级失序。本次测试结合事件日志样本进行核验，共覆盖 20 个提醒事件，触发窗口从 30 分钟延伸到 30 小时，兼顾短时任务和跨天任务。样本分布如表 7-4 所示。" -Kind "body"))
    $items.Add((New-ParagraphXml -Text "表 7-4 提醒调度测试样本分布" -Kind "caption"))
    $items.Add((New-TableXml -Rows @(
        @("测试维度", "数量", "说明"),
        @("定时提醒", "8", "按固定时间触发的单次提醒"),
        @("条件触发", "7", "依赖位置、天气或任务状态变化"),
        @("周期性提醒", "5", "按日、周、月等周期重复执行"),
        @("高优先级", "5", "需要优先关注的提醒任务"),
        @("中优先级", "10", "日常事务跟踪"),
        @("低优先级", "5", "习惯维护和一般提示")
    )))
    $items.Add((New-ParagraphXml -Text "从样本覆盖范围看，这组测试已经囊括提醒系统最常见的三类触发方式，并把触发时间分散到不同时间窗口，便于检查队列写入、到期扫描和重复入队逻辑是否一致。联调过程中，事件文件能够正确写出标题、触发时间、类型、优先级与通知渠道等字段，没有出现时间字段缺失和格式错乱。日志中还为每个事件保留了预计触发时间与状态位，这为后续继续追踪真实触发结果提供了基础。" -Kind "body"))
    $items.Add((New-ParagraphXml -Text "需要说明的是，当前日志中的实际触发结果栏仍待补录，因此本节更适合作为调度链路的准备度验证，而不是最终稳定性结论。若要形成更有说服力的量化结论，还需要在更长观察窗口下继续记录实际触发时间、重复入队情况和失败重试次数。" -Kind "body"))

    $items.Add((New-ParagraphXml -Text "7.1.3 MCP 服务调用测试" -Kind "subsection"))
    $items.Add((New-ParagraphXml -Text "MCP 服务承担模型调用与业务执行之间的中间层。测试关注点不是工具数量，而是工作流是否只能通过工具层访问任务数据，参数校验是否在写入前完成，以及异常返回是否会被前端正确接收。只要这一层边界不清，模型生成文本与真实业务写入之间就很难保持可控关系。" -Kind "body"))
    $items.Add((New-ParagraphXml -Text "结合调用链联调和接口路径核对可以看出，工作流侧只表达工具意图与参数，真实数据库写入仍由 MCP 服务完成。任务创建、任务查询和标签处理几类高频操作都经过统一入口，参数不完整时接口会返回错误信息或等待确认，而不会直接落库。这种处理方式符合 AI Agent 工程中模型负责生成建议、工具负责受控执行的基本思路[5]。" -Kind "body"))
    $items.Add((New-ParagraphXml -Text "对毕业设计场景而言，这组测试说明系统已经把智能推理层与业务写入层分开。后续若继续扩展地图、资料检索或消息通知等更多工具，仍可沿用这一路径维持统一的参数校验与执行边界。" -Kind "body"))

    $items.Add((New-ParagraphXml -Text "7.1.4 用户鉴权与数据隔离测试" -Kind "subsection"))
    $items.Add((New-ParagraphXml -Text "鉴权与数据隔离直接关系到个人任务和私有知识文件能否在多用户场景下安全共存。测试重点放在未登录访问、用户间资源串读和删除操作越权三类问题上，因为这几类问题一旦出现，系统即使功能完整也难以进入真实使用场景。" -Kind "body"))
    $items.Add((New-ParagraphXml -Text "从接口行为与数据组织核对结果看，任务、标签、会话历史和知识文件都以用户标识作为关联条件，前端请求进入业务层后也会先经过身份校验。未携带有效身份信息时，接口不会返回业务数据；即便资源类型不同，查询范围仍会收敛到当前用户所属记录内。这样一来，是否允许访问与允许访问什么分别落在鉴权入口和数据过滤两层处理。" -Kind "body"))
    $items.Add((New-ParagraphXml -Text "这组结果说明，系统已经形成了基础的数据边界控制能力。对个人助理场景而言，这种分层方式比单纯依赖前端隐藏按钮更可靠，也为后续接入更多外部工具保留了安全余量。" -Kind "body"))

    $items.Add((New-ParagraphXml -Text "7.2 UI 兼容与适配性测试" -Kind "section"))
    $items.Add((New-ParagraphXml -Text "前端界面是用户直接感知系统质量的部分。任务列表、对话抽屉、知识库上传和日历视图在桌面端与移动端上都要保持可读，浏览器差异也不能破坏流式对话、文件上传和媒体采集等关键交互。因此，本节从多终端适配和浏览器兼容两个角度进行说明。" -Kind "body"))

    $items.Add((New-ParagraphXml -Text "7.2.1 多终端界面适配测试" -Kind "subsection"))
    $items.Add((New-ParagraphXml -Text "多终端适配主要围绕桌面宽屏、平板中屏和手机窄屏三类视口展开。测试时重点观察任务列表、对话抽屉、知识库上传区和日历视图在布局收缩后的可读性。若窄屏条件下仍保留桌面端并列结构，用户很容易遇到面板遮挡和横向滚动问题。" -Kind "body"))
    $items.Add((New-ParagraphXml -Text "结合响应式布局方案的实际表现可以看到，窄屏条件下页面会回落为单列结构，主操作区域仍保持在首屏可触达位置。任务卡片、搜索栏和对话面板不会同时挤占同一行，这降低了移动端出现遮挡和误触的概率。上传文档、查看提醒和新增任务等主要操作在不同终端上都能够顺利完成，说明当前界面适配已经满足毕业设计阶段的基本使用要求。" -Kind "body"))

    $items.Add((New-ParagraphXml -Text "7.2.2 多浏览器兼容性测试" -Kind "subsection"))
    $items.Add((New-ParagraphXml -Text "浏览器兼容性主要关注文本输入、SSE 流式输出、文件上传和媒体权限四类交互，因为这些部分分别对应对话、知识库和录制功能。若浏览器对流式响应或媒体能力支持不稳定，界面层很容易出现消息中断、录音失败或预览异常。" -Kind "body"))
    $items.Add((New-ParagraphXml -Text "检查结果表明，任务管理、知识库上传和对话流式展示在主流桌面浏览器中表现一致，普通文本类操作没有出现明显差异。差异更多出现在录音授权和媒体能力初始化阶段，首次访问时需要用户显式授予麦克风权限；权限建立后，语音采集和结果回显能够回到原有对话流程。当前版本已经具备基本兼容性，但多媒体能力的边缘场景仍值得继续跟踪。" -Kind "body"))

    $items.Add((New-ParagraphXml -Text "7.3 本章小结" -Kind "section"))
    $items.Add((New-ParagraphXml -Text "本章从知识库检索、提醒调度、MCP 工具边界、鉴权隔离和界面适配几个方面对系统进行了验证。现有结果说明，文本知识检索与任务处理链路已经具备较稳定的可用性，提醒调度与多终端体验也形成了可运行基础。剩余问题主要集中在混合内容召回和多媒体能力兼容性上，第8章将在此基础上对全文工作作总结，并讨论后续完善方向。" -Kind "body"))

    return ($items -join "")
}

function Build-AcknowledgementXml {
    $items = New-Object System.Collections.Generic.List[string]
    $items.Add((New-ParagraphXml -Text "致谢" -Kind "chapter"))
    $items.Add((New-ParagraphXml -Text "本论文完成过程中，得到学院教师、项目指导老师和同学们的帮助。选题、系统实现、论文撰写和修改阶段的意见，对本文结构调整和细节完善都有直接作用。" -Kind "body"))
    $items.Add((New-ParagraphXml -Text "在系统开发与联调过程中，项目资料整理、测试环境准备和多次讨论为论文写作提供了支撑。反复阅读、修改和排查问题的过程，也让本文从初稿逐步收敛为当前版本。" -Kind "body"))
    $items.Add((New-ParagraphXml -Text "家人的理解与支持为毕业设计的持续推进提供了稳定条件。谨以此文向在学习和完成毕业设计过程中给予帮助的老师、同学和亲友表示感谢。" -Kind "body"))
    return ($items -join "")
}

if (-not (Test-Path $InputDocx)) {
    throw "找不到输入文件：$InputDocx"
}

$resolvedInput = (Resolve-Path $InputDocx).Path
$resolvedOutput = if (Test-Path $OutputDocx) { (Resolve-Path $OutputDocx).Path } else { [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputDocx)) }
$resolvedBackup = if ($BackupDocx) { [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $BackupDocx)) } else { "" }

if ($resolvedBackup) {
    Copy-Item -LiteralPath $resolvedInput -Destination $resolvedBackup -Force
}

$workZip = Join-Path (Get-Location) ".docx_incremental_edit.zip"
$workDir = Join-Path (Get-Location) ".docx_incremental_edit"
$xmlPath = Join-Path $workDir "word\document.xml"

if (Test-Path $workDir) { Remove-Item -Recurse -Force $workDir }
if (Test-Path $workZip) { Remove-Item -Force $workZip }

Copy-Item -LiteralPath $resolvedInput -Destination $workZip -Force
Expand-Archive -LiteralPath $workZip -DestinationPath $workDir -Force

[xml]$document = Get-Content -Path $xmlPath -Encoding UTF8
$ns = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
$ns.AddNamespace("w", $WordNs)

$chapter7Xml = Build-NewChapter7Xml
Replace-BodyNodesBetweenParagraphs -Document $document -Ns $ns -StartPrefix "第7章 系统测试" -EndPrefix "第8章 总结与展望" -ReplacementXml $chapter7Xml

$body = $document.SelectSingleNode("//w:body", $ns)
$sectPr = $body.SelectSingleNode("w:sectPr", $ns)
if ($null -eq $sectPr) {
    throw "未找到文档节属性节点"
}

if ($null -eq (Find-ParagraphByPrefix -Document $document -Ns $ns -Prefix "致谢")) {
    $ackXml = Build-AcknowledgementXml
    Insert-FragmentBeforeNode -Document $document -Parent $body -BeforeNode $sectPr -InnerXml $ackXml
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($xmlPath, $document.OuterXml, $utf8NoBom)

if (Test-Path $workZip) { Remove-Item -Force $workZip }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($workDir, $workZip)
Move-Item -LiteralPath $workZip -Destination $resolvedOutput -Force
Remove-Item -Recurse -Force $workDir

Write-Output "output-docx: $resolvedOutput"
if ($resolvedBackup) {
    Write-Output "backup-docx: $resolvedBackup"
}



