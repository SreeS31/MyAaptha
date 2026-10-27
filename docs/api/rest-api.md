# MyAaptha REST API Documentation

Base URL: `http://localhost:8080/api/v1`

Authentication: Bearer JWT in `Authorization` header (except auth endpoints).

## Response Envelope

```json
{
  "success": true,
  "data": { },
  "error": null
}
```

## Authentication

### POST /auth/register
Register new user.

**Body:**
```json
{
  "fullName": "John Doe",
  "email": "john@example.com",
  "mobile": "+1234567890",
  "password": "securepass123"
}
```

### POST /auth/login
Login with email or mobile.

**Body:**
```json
{
  "email": "john@example.com",
  "password": "securepass123"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "userId": "uuid",
    "fullName": "John Doe",
    "email": "john@example.com",
    "accessToken": "eyJ...",
    "tokenType": "Bearer",
    "expiresIn": 900
  }
}
```

## Circles

### GET /circles
List circles for authenticated user. Supports pagination (`page`, `size`, `sort`).

### POST /circles
Create circle.

**Body:**
```json
{
  "name": "Family Tree",
  "description": "Our family",
  "category": "FAMILY",
  "treeType": "PRIVATE",
  "visibility": "PRIVATE"
}
```

### GET /circles/{id}
Get circle by ID.

## Nodes

### POST /circles/{circleId}/nodes
Add person node.

**Body:**
```json
{
  "fullName": "Jane Doe",
  "gender": "FEMALE",
  "dateOfBirth": "1990-05-15",
  "parentId": "uuid-or-null",
  "occupation": "Engineer",
  "city": "Hyderabad"
}
```

### GET /circles/{circleId}/nodes/roots
Root nodes (lazy tree entry points).

### GET /circles/{circleId}/nodes/{parentId}/children
Child nodes for lazy expansion.

### GET /nodes/{id}
Single node detail.

### GET /circles/{circleId}/search?q=john
Search nodes in circle.

## Relationships

### GET /nodes/{fromId}/kinship/{toId}
Resolve computed kinship.

**Response:**
```json
{
  "success": true,
  "data": {
    "label": "Cousin",
    "path": ["FATHER", "BROTHER", "SON"],
    "distance": 3,
    "bloodRelation": true
  }
}
```

## Dashboard

### GET /dashboard
User dashboard statistics.

## GraphQL

Endpoint: `POST /graphql`

Example query:
```graphql
query {
  circle(id: "uuid") {
    id
    name
    nodeCount
  }
}
```

## WebSocket

Endpoint: `/ws` (STOMP)

Topics:
- `/topic/circles/{id}/updates` — live tree changes
- `/user/queue/notifications` — personal notifications

## Error Codes

| Code | HTTP | Description |
|------|------|-------------|
| NOT_FOUND | 404 | Resource missing |
| VALIDATION_ERROR | 400 | Invalid input |
| INVALID_CREDENTIALS | 400 | Login failed |
| EMAIL_EXISTS | 400 | Duplicate email |
| FORBIDDEN | 403 | Insufficient permission |

Interactive docs: `/swagger-ui.html`
