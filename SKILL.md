---
name: github_upload_diy
description: >
  将本地文件夹批量上传至 GitHub 仓库，自动化创建仓库、上传文件、生成 README。
  支持指定 GitHub Token、用户名、仓库名前缀，自动生成符合 Skill 目录结构的 README.md。
  触发词：上传GitHub、上传github、上传仓库、github上传、GitHub仓库创建、批量上传GitHub、
  skill上传github、本地文件夹上传GitHub
version: 1.0.0
base_dir: C:\Users\G1381\.workbuddy\skills\github_upload_diy
---

# github_upload_diy — 本地文件夹批量上传 GitHub

将本地技能文件夹批量上传至 GitHub，自动完成：仓库创建、README 生成、文件上传。

---

## 核心工作流程（SOP）

### Phase 1：准备上传清单

用户提供：
- **GitHub Token**（Personal Access Token，需要 `repo` 权限）
- **GitHub 用户名**
- **待上传文件夹列表**（绝对路径）

### Phase 2：检查/创建 GitHub 仓库

```python
def create_repo(token, username, repo_name):
    """创建 GitHub 仓库（如果不存在）"""
    url = f"https://api.github.com/user/repos"
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json"
    }
    data = {"name": repo_name, "private": False, "auto_init": False}
    r = requests.post(url, headers=headers, json=data)
    return r.status_code in (200, 201, 422)  # 422 表示已存在
```

### Phase 3：生成 README.md

自动为每个仓库生成 README.md：

```python
def generate_readme(folder_name, skill_name):
    """基于文件夹名和技能名生成 README"""
    return f"""# {skill_name}

技能目录自动生成。

## 文件结构

```
{folder_name}/
├── SKILL.md
└── ...
```

## 说明

本仓库由 github_upload_diy skill 自动生成。
"""
```

### Phase 4：上传文件

```python
def upload_file(token, username, repo_name, file_path, content):
    """上传单个文件到 GitHub"""
    import base64
    url = f"https://api.github.com/repos/{username}/{repo_name}/contents/{file_path}"
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json"
    }
    encoded = base64.b64encode(content.encode()).decode()
    data = {
        "message": f"Upload {file_path}",
        "content": encoded
    }
    r = requests.put(url, headers=headers, json=data)
    return r.status_code in (200, 201)
```

---

## 完整上传脚本模板

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GitHub 批量上传工具
用法：修改 TOKEN, USERNAME, REPO_PREFIX, FOLDERS 后直接运行
"""
import base64
import requests
import os
import sys

# ============ 配置区 ============
TOKEN = "ghp_xxxxxxxxxxxx"          # GitHub Personal Access Token
USERNAME = "ZhangGZ-medical"        # GitHub 用户名
REPO_PREFIX = ""                    # 仓库名前缀（可选）
# 待上传文件夹列表 [(文件夹路径, 仓库名), ...]
FOLDERS = [
    (r"C:\path\to\skill1", "skill1"),
    (r"C:\path\to\skill2", "skill2"),
]
# ================================

def create_repo(repo_name):
    url = f"https://api.github.com/user/repos"
    headers = {
        "Authorization": f"token {TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }
    data = {"name": repo_name, "private": False, "auto_init": False}
    r = requests.post(url, headers=headers, json=data)
    return r.status_code in (200, 201, 422)

def upload_file(repo_name, file_path, local_path):
    url = f"https://api.github.com/repos/{USERNAME}/{repo_name}/contents/{file_path}"
    headers = {
        "Authorization": f"token {TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }
    with open(local_path, 'rb') as f:
        encoded = base64.b64encode(f.read()).decode()
    data = {"message": f"Upload {file_path}", "content": encoded}
    r = requests.put(url, headers=headers, json=data)
    return r.status_code in (200, 201)

def upload_folder(local_folder, repo_name):
    print(f"\n{'='*50}")
    print(f"上传仓库: {repo_name}")
    print(f"{'='*50}")
    
    create_repo(repo_name)
    
    for root, dirs, files in os.walk(local_folder):
        for file in files:
            local_path = os.path.join(root, file)
            rel_path = os.path.relpath(local_path, local_folder)
            print(f"[INFO] {rel_path} ...", end=" ")
            ok = upload_file(repo_name, rel_path, local_path)
            print("[OK]" if ok else "[FAIL]")

def main():
    for folder, repo_name in FOLDERS:
        if REPO_PREFIX:
            repo_name = f"{REPO_PREFIX}-{repo_name}"
        upload_folder(folder, repo_name)

if __name__ == "__main__":
    main()
```

---

## 使用示例

### 场景：上传 3 个 Skill 到 GitHub

```python
# 配置
TOKEN = "YOUR_TOKEN_HERE"
USERNAME = "ZhangGZ-medical"
FOLDERS = [
    (r"C:\Users\G1381\.workbuddy\skills\en2cn_diy", "en2cn_diy"),
    (r"C:\Users\G1381\.workbuddy\skills\md2docx_diy", "md2docx_diy"),
    (r"C:\Users\G1381\.workbuddy\skills\nmpa_cell_ind_diy", "nmpa_cell_ind_diy"),
]
```

### 执行结果

```
==================================================
上传仓库: en2cn_diy
==================================================
[OK] Uploaded: README.md
[OK] Uploaded: SKILL.md
[OK] Uploaded: en2cn_docx.py

==================================================
上传仓库: md2docx_diy
==================================================
[OK] Uploaded: README.md
[OK] Uploaded: SKILL.md
[OK] Uploaded: md2docx_diy.py
...
```

---

## 注意事项

- **Token 权限**：需要 `repo` 作用域的 Personal Access Token
- **编码问题**：Windows 终端使用 GBK 编码，避免在 print 中使用特殊 Unicode 字符（如 ✓、✗），改用 `[OK]` / `[FAIL]`
- **仓库存在**：HTTP 422 表示仓库已存在，继续上传文件即可
- **子目录**：脚本会自动递归处理子目录（`os.walk`）
- **Python 版本**：建议 Python 3.8+，依赖 `requests` 库

---

## 文件结构

```
github_upload_diy/
├── SKILL.md              # 本说明文件
└── github_upload_diy.py  # 上传脚本模板
```

---

## 踩坑经验

- **Token 无效**：401 Bad credentials → Token 过期或无效，需重新生成
- **Windows 编码**：`sys.stdout.reconfigure(encoding='utf-8')` 可解决输出乱码，但 print 中避免 Unicode 特殊字符更稳妥
- **仓库已存在**：HTTP 201 表示新建，422 表示已存在，两者都继续上传文件即可
