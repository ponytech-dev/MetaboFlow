# 用户认证系统设计

> 确认日期：2026-03-21
> 状态：已确认

## 概述

邀请码 + 邮箱密码注册 + JWT 认证，实现多用户数据隔离。Phase 1 内测 5-10 个外部实验室。

## 认证方案

| 组件 | 选型 |
|------|------|
| 认证方式 | 邮箱 + 密码注册，需邀请码 |
| Token | JWT（access token 30min + refresh token 7d） |
| 密码存储 | bcrypt hash |
| 后端 | FastAPI + python-jose + passlib |
| 前端 | 登录/注册页 + JWT 拦截 |

## 数据隔离

- 每个 analysis 记录 `user_id` 外键
- API 层所有查询自动加 `WHERE user_id = current_user`
- 文件存储路径：`/data/uploads/{user_id}/{analysis_id}/`
- 结果路径：`/data/results/{user_id}/{analysis_id}/`

## 邀请码机制

- 管理员通过 API 或 CLI 生成邀请码
- 每个邀请码单次使用，绑定到注册用户
- Phase 1 不做自助注册，只有持邀请码才能注册

## 页面

- `/login` — 登录
- `/register` — 注册（需邀请码）
- 未登录访问任何页面 → 重定向到 `/login`
