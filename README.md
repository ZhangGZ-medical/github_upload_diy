# github_upload_diy

本地文件夹批量上传 GitHub 仓库工具。

## 功能

将本地技能文件夹批量上传至GitHub，自动完成：仓库创建、README生成、文件递归上传。

## 触发词

上传GitHub、上传仓库、github上传、批量上传GitHub、skill上传github

## 文件结构

```
github_upload_diy/
├── SKILL.md              # 技能定义与SOP
├── github_upload_diy.py  # 上传脚本模板
└── README.md             # 本说明文件
```

## 核心流程

1. 准备上传清单（Token + 用户名 + 文件夹列表）
2. 检查/创建GitHub仓库（API自动处理422已存在）
3. 生成README.md（按技能目录结构）
4. 递归上传文件（os.walk + base64编码）

## 依赖

- Python 3.8+
- `requests` 库
- GitHub Personal Access Token（需repo权限）
