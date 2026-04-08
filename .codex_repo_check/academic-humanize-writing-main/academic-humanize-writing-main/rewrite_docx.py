#!/usr/bin/env python3
from __future__ import annotations

import copy
import re
import shutil
import tempfile
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile
from xml.etree import ElementTree as ET


W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
XML_NS = "http://www.w3.org/XML/1998/namespace"
NS = {"w": W_NS}

ET.register_namespace("w", W_NS)


def qn(tag: str) -> str:
    return f"{{{W_NS}}}{tag}"


def contains_chinese(text: str) -> bool:
    return bool(re.search(r"[\u4e00-\u9fff]", text))


def is_english_heavy(text: str) -> bool:
    letters = len(re.findall(r"[A-Za-z]", text))
    chinese = len(re.findall(r"[\u4e00-\u9fff]", text))
    return letters > chinese * 2 and letters > 30


def is_heading_or_fixed(text: str) -> bool:
    stripped = text.strip()
    if not stripped:
        return True
    fixed = {
        "摘 要",
        "ABSTRACT",
        "目 录",
        "参考文献",
        "绪论",
        "基础理论与相关技术",
        "致谢",
    }
    if stripped in fixed:
        return True
    if re.match(r"^第[一二三四五六七八九十]+章", stripped):
        return True
    if re.match(r"^\d+(\.\d+)+\s*", stripped):
        return True
    if re.match(r"^(图|表)\d", stripped):
        return True
    if re.match(r"^(关键词|Keywords)[:：]", stripped):
        return True
    if re.search(r"(分\s*类\s*号|学校代码|学\s*号|密\s*级|保密日期|保密期限)", stripped):
        return True
    if re.match(r"^\[\d+\]", stripped):
        return True
    if re.match(r"^[\dA-Za-z .,:;()（）/-]{1,80}$", stripped) and not contains_chinese(stripped):
        return True
    if re.search(r"\.{3,}", stripped) or re.search(r"\d+$", stripped):
        # 目录项或页码行
        return True
    return False


def is_candidate(text: str) -> bool:
    if len(text.strip()) < 28:
        return False
    if not contains_chinese(text):
        return False
    if is_english_heavy(text):
        return False
    if is_heading_or_fixed(text):
        return False
    return True


def polish_text(text: str) -> str:
    original = text
    text = text.strip()

    replacements = [
        (r"综上所述", "综合来看"),
        (r"总体而言", "总体来看"),
        (r"整体而言", "总体来看"),
        (r"可以看出", "可以发现"),
        (r"由此可以看出", "由此可以发现"),
        (r"具有重要意义", "具有重要价值"),
        (r"具有显著的实际应用价值", "具有较强的实际应用价值"),
        (r"导致了", "导致"),
        (r"提升了", "提升了"),
        (r"提高了", "提升了"),
        (r"呈现出", "呈现"),
        (r"已成为", "已逐渐成为"),
        (r"值得注意的是", "需要说明的是"),
        (r"为了有效", "为更好地"),
        (r"为了进一步", "为进一步"),
        (r"为了提升", "为提升"),
        (r"(?<!围绕上述问题，)本文开展了如下研究[:：]", "围绕上述问题，本文主要开展了以下研究："),
        (r"本文开展了一系列系统性研究", "本文围绕这一问题展开了系统研究"),
        (r"本文共六章，结构安排如下[:：]", "全文共分六章，结构安排如下："),
        (r"综上，本章", "综合来看，本章"),
        (r"与此同时", "同时"),
    ]
    for pattern, repl in replacements:
        text = re.sub(pattern, repl, text)

    text = text.replace("针对上述问题，围绕上述问题，", "围绕上述问题，")
    text = text.replace("针对上述问题，本文主要开展了以下研究：", "围绕上述问题，本文主要开展了以下研究：")

    # 弱化过于模板化的段首连接词，但保留枚举含义。
    text = re.sub(r"^首先，", "首先需要指出的是，", text)
    text = re.sub(r"(^|。)其次，", r"\1此外，", text)
    text = re.sub(r"(^|。)最后，", r"\1最后，", text)

    # 缓和“本文”重复。
    if text.count("本文") >= 3:
        first = text.find("本文")
        second = text.find("本文", first + 2)
        third = text.find("本文", second + 2)
        if second != -1:
            text = text[:second] + "本研究" + text[second + 2 :]
        if third != -1:
            third = text.find("本文", second + 2)
            if third != -1:
                text = text[:third] + "这一工作" + text[third + 2 :]

    # 打散极长句，尽量只在明显并列结构处断句。
    if len(text) > 130 and text.count("，") >= 6:
        text = re.sub(r"，因此，", "。因此，", text, count=1)

    return text if text else original


def get_paragraph_text(p: ET.Element) -> str:
    texts = []
    for node in p.iter():
        if node.tag == qn("t"):
            texts.append(node.text or "")
    return "".join(texts)


def replace_paragraph_text(p: ET.Element, new_text: str) -> bool:
    runs = p.findall("w:r", NS)
    if not runs:
        return False

    template_rpr = None
    for run in runs:
        rpr = run.find("w:rPr", NS)
        if rpr is not None:
            template_rpr = copy.deepcopy(rpr)
            break

    ppr = p.find("w:pPr", NS)
    for child in list(p):
        if child.tag != qn("pPr"):
            p.remove(child)

    run = ET.Element(qn("r"))
    if template_rpr is not None:
        run.append(template_rpr)
    text_el = ET.SubElement(run, qn("t"))
    if new_text.startswith(" ") or new_text.endswith(" "):
        text_el.set(f"{{{XML_NS}}}space", "preserve")
    text_el.text = new_text
    if ppr is not None:
        insert_at = 1
        p.insert(insert_at, run)
    else:
        p.append(run)
    return True


def rewrite_docx(src: Path, dst: Path) -> tuple[int, int]:
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        with ZipFile(src, "r") as zin:
            zin.extractall(tmp)

        doc_xml = tmp / "word" / "document.xml"
        tree = ET.parse(doc_xml)
        root = tree.getroot()

        changed = 0
        seen = 0
        for p in root.findall(".//w:body/w:p", NS):
            text = get_paragraph_text(p).strip()
            if not is_candidate(text):
                continue
            seen += 1
            new_text = polish_text(text)
            if new_text != text and replace_paragraph_text(p, new_text):
                changed += 1

        tree.write(doc_xml, encoding="utf-8", xml_declaration=True)

        if dst.exists():
            dst.unlink()
        with ZipFile(dst, "w", ZIP_DEFLATED) as zout:
            for file in sorted(tmp.rglob("*")):
                if file.is_file():
                    zout.write(file, file.relative_to(tmp))

    return changed, seen


def main() -> None:
    src = Path("my-paper.docx")
    dst = Path("new-paper.docx")
    changed, seen = rewrite_docx(src, dst)
    print(f"candidate_paragraphs={seen}")
    print(f"changed_paragraphs={changed}")
    print(f"output={dst}")


if __name__ == "__main__":
    main()
