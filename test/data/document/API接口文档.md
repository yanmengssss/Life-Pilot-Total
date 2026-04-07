# API接口文档

## 用户服务API

### 1. 用户注册

**请求信息**
```
POST /api/v1/user/register
Content-Type: application/json
```

**请求参数**
```json
{
  "username": "string",      // 用户名，6-20位字母或数字
  "password": "string",     // 密码，8-20位，必须包含字母和数字
  "phone": "string",         // 手机号，11位数字
  "email": "string",         // 邮箱地址
  "captcha": "string"        // 验证码
}
```

**响应示例**
```json
{
  "code": 200,
  "message": "注册成功",
  "data": {
    "userId": "u_123456789",
    "username": "zhangsan",
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

### 2. 用户登录

**请求信息**
```
POST /api/v1/user/login
Content-Type: application/json
```

**请求参数**
```json
{
  "account": "string",       // 账号（用户名/手机号/邮箱）
  "password": "string",     // 密码
  "rememberMe": "boolean"    // 记住登录状态
}
```

**响应示例**
```json
{
  "code": 200,
  "message": "登录成功",
  "data": {
    "userId": "u_123456789",
    "username": "zhangsan",
    "nickname": "张三",
    "avatar": "https://example.com/avatar/123.jpg",
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": 7200
  }
}
```

### 3. 获取用户信息

**请求信息**
```
GET /api/v1/user/info
Authorization: Bearer {token}
```

**响应示例**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "userId": "u_123456789",
    "username": "zhangsan",
    "nickname": "张三",
    "phone": "138****8888",
    "email": "zhangsan@example.com",
    "avatar": "https://example.com/avatar/123.jpg",
    "gender": 1,
    "birthday": "1990-01-01",
    "createTime": "2023-01-15 10:30:00"
  }
}
```

### 4. 更新用户信息

**请求信息**
```
PUT /api/v1/user/info
Authorization: Bearer {token}
Content-Type: application/json
```

**请求参数**
```json
{
  "nickname": "string",      // 昵称
  "gender": "number",        // 性别：0-未知，1-男，2-女
  "birthday": "string",      // 生日，格式：YYYY-MM-DD
  "avatar": "string"         // 头像URL
}
```

## 错误码说明

| 错误码 | 说明 |
|--------|------|
| 200 | 成功 |
| 400 | 请求参数错误 |
| 401 | 未授权或token过期 |
| 403 | 禁止访问 |
| 404 | 资源不存在 |
| 500 | 服务器内部错误 |
