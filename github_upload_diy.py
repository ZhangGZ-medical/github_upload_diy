#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GitHub 批量上传工具 - github_upload_diy skill
将本地文件夹批量上传至 GitHub 仓库

使用方法：
1. 修改下方配置区的 TOKEN, USERNAME, REPO_PREFIX, FOLDERS
2. 运行: python github_upload_diy.py
"""

import base64
import requests
import os
import sys

# ============ 配置区 ============
TOKEN = ""          # GitHub Personal Access Token
USERNAME = ""       # GitHub 用户名
REPO_PREFIX = ""    # 仓库名前缀（可选，留空则无前缀）
# 待上传文件夹列表 [(文件夹绝对路径, 仓库名), ...]
FOLDERS = [
    # (r"", ""),
]
# ================================


def create_repo(repo_name):
    """创建 GitHub 仓库（如果已存在则跳过）"""
    url = f"https://api.github.com/user/repos"
    headers = {
        "Authorization": f"token {TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }
    data = {"name": repo_name, "private": False, "auto_init": False}
    r = requests.post(url, headers=headers, json=data)
    return r.status_code in (200, 201, 422)


def upload_file(repo_name, file_path, local_path):
    """上传单个文件到 GitHub"""
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
    """上传整个文件夹到指定仓库"""
    print(f"\n{'='*50}")
    print(f"上传仓库: {repo_name}")
    print(f"{'='*50}")
    
    create_repo(repo_name)
    
    for root, dirs, files in os.walk(local_folder):
        for file in files:
            local_path = os.path.join(root, file)
            rel_path = os.path.relpath(local_path, local_folder)
            print(f"[INFO] {rel_path} ...", end=" ", flush=True)
            ok = upload_file(repo_name, rel_path, local_path)
            print("[OK]" if ok else "[FAIL]")


def main():
    if not TOKEN or not USERNAME:
        print("[ERROR] 请先配置 TOKEN 和 USERNAME")
        return
    
    if not FOLDERS or all(not f[0] for f in FOLDERS):
        print("[ERROR] 请先配置 FOLDERS 列表")
        return
    
    for folder, repo_name in FOLDERS:
        if not folder or not repo_name:
            continue
        full_repo_name = f"{REPO_PREFIX}-{repo_name}" if REPO_PREFIX else repo_name
        upload_folder(folder, full_repo_name)
    
    print(f"\n{'='*50}")
    print("全部上传完成！")
    print(f"{'='*50}")


if __name__ == "__main__":
    # Windows GBK 环境兼容
    if sys.stdout.encoding != 'utf-8':
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    
    main()
