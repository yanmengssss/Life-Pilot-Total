#!/bin/bash

TOKEN="Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6ImQ2MzA2YTFjLWI5YWUtNGFjOC1hYzhlLWIxNzlkZDViZTQ4MCIsInR5cGUiOiJhdCIsImlhdCI6MTc3NTU3NjEzNiwiZXhwIjoxNzc1NTk0MTM2fQ.zSWI3sIT-iIP6sXMNq9UoC14Db33HoxZVpFPlwcjUkE"
USER_ID="d6306a1c-b9ae-4ac8-ac9e-b179dd5be480"
API_URL="https://mcp.lifepilot.website/mcp"

create_task() {
    local id=$1
    local title=$2
    local desc=$3
    local priority=$4
    local endAt=$5

    local payload=$(cat <<EOF
{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
        "name": "create_task",
        "arguments": {
            "userID": "$USER_ID",
            "title": "$title",
            "description": "$desc",
            "priority": $priority,
            "needTips": true
            ${endAt:+"\"endAt\": \"$endAt\""}
        }
    },
    "id": $id
}
EOF
)

    echo "Creating: $title"
    curl -s -X POST "$API_URL" \
        -H "Authorization: $TOKEN" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json, text/event-stream" \
        -d "$payload" | grep -o '"success":[^,]*'
}

# event_001: 项目评审会议提醒
create_task 1 "项目评审会议提醒" "下午3点需参加项目评审会议，请提前准备PPT和项目进度报告，会议时长约1小时，地点在A栋3楼会议室。" 5 "2026-04-06T14:30:00.000Z"

# event_002: 到达公司后提醒打卡
create_task 2 "到达公司后提醒打卡" "当检测到用户到达公司附近（GPS坐标在公司500米范围内）时，自动提醒打卡签到，并询问是否需要预订午餐。" 3 ""

# event_003: 每日喝水提醒
create_task 3 "每日喝水提醒" "每隔2小时提醒用户喝水，保持身体健康。建议每次饮用200-300ml水，全天摄入量不少于1500ml。" 1 ""

# event_004: 午餐后服药提醒
create_task 4 "午餐后服药提醒" "午饭后30分钟需服用维生素D软胶囊1粒，请用温水送服，避免与咖啡、茶同服。药品放置在厨房药盒中。" 3 "2026-04-06T13:00:00.000Z"

# event_005: 下雨天气带伞提醒
create_task 5 "下雨天气带伞提醒" "当气象预报显示未来2小时内有降雨概率超过70%时，自动提醒用户出门带伞。查看当前天气：多云转阴，下午有30%降雨概率。" 3 ""

# event_006: 好友生日祝福提醒
create_task 6 "好友生日祝福提醒" "今天是好友李明的生日，记得在晚上8点前发送生日祝福。可以选择发送微信消息或打电话问候。" 1 "2026-04-06T15:00:00.000Z"

# event_007: 高温防暑提醒
create_task 7 "高温防暑提醒" "当气温超过35摄氏度时，自动提醒用户注意防暑降温。建议减少户外活动，多补充水分，避免中暑。" 5 ""

# event_008: 周一工作计划提醒
create_task 8 "周一工作计划提醒" "每周一早上9点提醒用户制定本周工作计划，请登录项目管理系统查看本周任务清单，并安排好工作优先级。" 5 ""

# event_009: 每周工作报告提交提醒
create_task 9 "每周工作报告提交提醒" "提醒提交本周工作周报，需包含：本周完成事项、下周计划、存在的问题和需要的支持。请在17:00前提交至邮件列表。" 3 "2026-04-06T16:30:00.000Z"

# event_010: 工作日早高峰出行提醒
create_task 10 "工作日早高峰出行提醒" "工作日早上8:00-9:00期间，当用户位于家附近时，自动提醒今日路况和最佳出行时间，避开早高峰拥堵。" 3 ""

# event_011: 结婚纪念日提醒
create_task 11 "结婚纪念日提醒" "明天是与妻子的结婚3周年纪念日，记得提前准备礼物和晚餐安排。建议预订她喜欢的餐厅，准备一束玫瑰花。" 5 "2026-04-06T18:00:00.000Z"

# event_012: 任务完成后提醒下一步行动
create_task 12 "任务完成后提醒下一步行动" "当检测到用户完成整理文档任务后，自动提醒执行下一步发送邮件给团队成员，并在附件中包含整理好的文档。" 3 ""

# event_013: 每月账单还款提醒
create_task 13 "每月账单还款提醒" "每月1号提醒用户检查并偿还上月信用卡账单，请登录银行APP查看账单金额，确保在还款日前完成支付以避免滞纳金。" 5 ""

# event_014: 股票价格预警提醒
create_task 14 "股票价格预警提醒" "当腾讯控股(00700)股价超过450港元时，自动提醒用户股价已达到预设目标价，建议查看是否需要获利了结。" 3 ""

# event_015: 晚间习惯养成提醒
create_task 15 "晚间习惯养成提醒" "提醒进行30分钟阅读习惯培养，建议阅读《原子习惯》，每天坚持一个小习惯，一年后的你会感谢现在的自己。" 1 "2026-04-06T21:30:00.000Z"

# event_016: 连续未运动健康提醒
create_task 16 "连续未运动健康提醒" "检测到您已连续3天未进行任何运动（步数少于3000步），提醒您起身活动一下。建议进行15分钟伸展运动或快走。" 3 ""

# event_017: 工作日考勤打卡提醒
create_task 17 "工作日考勤打卡提醒" "每个工作日早上8:30提醒用户考勤打卡，请确保在9:00前到达公司并完成钉钉打卡，如有异常请及时联系HR。" 5 ""

# event_018: 年度体检提醒
create_task 18 "年度体检提醒" "提醒预约本年度员工体检，请在本周五前登录公司HR系统选择体检日期。体检当天需空腹8小时，携带身份证原件。" 3 "2026-04-07T10:00:00.000Z"

# event_019: 快递送达提醒
create_task 19 "快递送达提醒" "当物流信息显示您的快递已送达菜鸟驿站时，自动提醒您及时取件。快递单号：YT1234567890，驿站地址：小区南门左侧。" 1 ""

# event_020: 久坐休息提醒
create_task 20 "久坐休息提醒" "每隔2小时提醒用户起身休息，进行5分钟眼部放松或伸展运动，有助于缓解颈椎和腰椎压力，保护身体健康。" 1 ""

echo "All events created!"