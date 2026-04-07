import os
from docx import Document
from docx.shared import Pt, Inches
from docx.oxml.ns import qn
from docx.enum.text import WD_PARAGRAPH_ALIGNMENT

def init_thesis_document(file_name="thesis_output.docx"):
    # 如果文件已存在，先删除，确保从头开始
    if os.path.exists(file_name):
        os.remove(file_name)
        
    doc = Document()

    # 1. 全局字体设置 (英文 Times New Roman，中文宋体)
    doc.styles['Normal'].font.name = 'Times New Roman'
    doc.styles['Normal']._element.rPr.rFonts.set(qn('w:eastAsia'), 'SimSun')
    doc.styles['Normal'].font.size = Pt(12) # 小四号字体

    # 2. 设置标题样式 (例如：Heading 1, Heading 2)
    # 一级标题：黑体，三号，居中
    h1_style = doc.styles['Heading 1']
    h1_style.font.name = 'Times New Roman'
    h1_style._element.rPr.rFonts.set(qn('w:eastAsia'), 'SimHei') # 中文黑体
    h1_style.font.size = Pt(16) # 三号
    h1_style.font.bold = True
    h1_style.paragraph_format.alignment = WD_PARAGRAPH_ALIGNMENT.CENTER
    h1_style.paragraph_format.space_after = Pt(12)

    # 二级标题：黑体，四号，左对齐
    h2_style = doc.styles['Heading 2']
    h2_style.font.name = 'Times New Roman'
    h2_style._element.rPr.rFonts.set(qn('w:eastAsia'), 'SimHei')
    h2_style.font.size = Pt(14) # 四号
    h2_style.font.bold = True
    h2_style.paragraph_format.space_before = Pt(12)
    h2_style.paragraph_format.space_after = Pt(6)

    # 三级标题：黑体，小四号，左对齐
    h3_style = doc.styles['Heading 3']
    h3_style.font.name = 'Times New Roman'
    h3_style._element.rPr.rFonts.set(qn('w:eastAsia'), 'SimHei')
    h3_style.font.size = Pt(12) # 小四
    h3_style.font.bold = True
    h3_style.paragraph_format.space_before = Pt(6)
    h3_style.paragraph_format.space_after = Pt(6)

    # 3. 页面边距设置 (常规设置，上下2.54cm，左右3.18cm)
    sections = doc.sections
    for section in sections:
        section.top_margin = Inches(1.0)
        section.bottom_margin = Inches(1.0)
        section.left_margin = Inches(1.25)
        section.right_margin = Inches(1.25)

    # 添加一个初始的大标题
    title = doc.add_heading('智能生活管家系统设计与实现', level=0)
    title.alignment = WD_PARAGRAPH_ALIGNMENT.CENTER

    # 保存文档
    doc.save(file_name)
    print(f"✅ 成功初始化论文文档：{file_name}，字体与段落样式已就绪。")
    print("Agent 可以开始读取 plan.md 并向其中追加内容了。")

if __name__ == "__main__":
    init_thesis_document()