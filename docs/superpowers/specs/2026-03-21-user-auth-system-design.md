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
- `analysis_id` 由服务端生成（UUID），不接受用户传入
- API 层所有查询自动加 `WHERE user_id = current_user`
- **文件下载端点必须校验 ownership**：先查 DB 确认 analysis.user_id == current_user，再返回文件流。禁止仅依赖路径规则
- 文件存储路径：`/data/uploads/{user_id}/{analysis_id}/`
- 结果路径：`/data/results/{user_id}/{analysis_id}/`

## JWT Token 存储与撤销

- refresh token 存储在 httpOnly cookie（防 XSS）
- access token 存储在内存（前端 state），不放 localStorage
- 前端 axios/fetch 拦截器：access token 过期时自动用 refresh token 续期
- 登出时：后端将 refresh token 加入黑名单（Redis 或 DB），前端清除 cookie

## 邀请码机制

- 管理员通过 API 或 CLI 生成邀请码
- 每个邀请码单次使用，绑定到注册用户
- 邀请码长度 ≥ 16 字符（crypto random），有效期 30 天
- 管理员 API 需要 `is_admin` 角色校验
- Phase 1 不做自助注册，只有持邀请码才能注册

## 数据库

- 选型：SQLite（Phase 1 内测规模足够，Phase 2 可迁移 PostgreSQL）
- ORM：SQLAlchemy（后端已在使用）
- 核心表：users、invite_codes、analyses

## 页面

- `/login` — 登录
- `/register` — 注册（需邀请码）
- 未登录访问任何页面 → 重定向到 `/login`
