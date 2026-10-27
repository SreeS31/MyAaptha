# MyAaptha — Low-Level Design (LLD)

## 1. Backend Package Structure

```
com.myaaptha
├── config          Security, CORS, OpenAPI, GraphQL, WebSocket
├── security        JWT filter, UserDetails, OAuth handlers
├── domain
│   ├── user        User, Device, LoginHistory, OtpToken
│   ├── circle      Circle, TreeVersion, TreeTemplate, TreeLink
│   ├── node        PersonNode, NodeMedia, NodeDocument, CustomField
│   ├── relationship Relationship, RelationshipType, ClosureEntry
│   ├── permission  AclEntry, RoleAssignment
│   ├── communication Message, MessageFilter
│   ├── event       CalendarEvent, Reminder
│   └── audit       AuditLog
├── repository      JPA + custom @Query
├── service         Business logic
├── engine          RelationshipEngine, DuplicateDetector, PermissionResolver
├── controller      REST resources
├── graphql         Query/Mutation resolvers
├── websocket       STOMP controllers
├── dto / mapper    MapStruct mappers
└── exception       GlobalExceptionHandler
```

## 2. Key Entities

### 2.1 PersonNode

```java
@Entity
@Table(name = "person_nodes")
public class PersonNode {
    @Id @GeneratedValue UUID id;
    UUID circleId;
    UUID parentId;          // adjacency list (nullable for root)
    String fullName;
    Gender gender;          // MALE, FEMALE, UNKNOWN
    LocalDate dateOfBirth;
    // ... profile fields
    @Version Long version;  // optimistic locking
}
```

### 2.2 Relationship

```java
@Entity
@Table(name = "relationships")
public class Relationship {
    UUID id;
    UUID sourceNodeId;
    UUID targetNodeId;
    RelationshipTypeEnum type;  // FATHER, MOTHER, SPOUSE, ...
    UUID circleId;
    boolean bidirectional;
}
```

### 2.3 Closure Table (for fast ancestry)

```sql
node_closure (ancestor_id, descendant_id, depth)
```

Maintained on INSERT/UPDATE/DELETE of parent-child links via service layer.

## 3. Relationship Engine

### 3.1 Path Composition

```java
public class RelationshipEngine {
    public KinshipResult resolve(UUID fromNodeId, UUID toNodeId) {
        List<PathStep> path = graphService.shortestPath(fromNodeId, toNodeId);
        return ruleRegistry.compose(path);
    }
}
```

Rule examples:
- `FATHER + BROTHER + SON → COUSIN`
- `SPOUSE + FATHER → FATHER_IN_LAW`

Rules stored in DB for extensibility (custom cultural relationships).

### 3.2 Duplicate Detection

Score = weighted fuzzy match on:
- Name (Levenshtein)
- DOB exact match (+high weight)
- Phone/email overlap
- Photo perceptual hash (optional phase 2)

Threshold ≥ 0.85 → suggest merge.

## 4. Permission Resolver

```java
public boolean can(User user, UUID nodeId, Permission perm) {
    if (user.isSuperAdmin()) return true;
    List<AclEntry> entries = aclRepo.findEffective(user, nodeId);
    return entries.stream()
        .anyMatch(e -> e.getPermissions().contains(perm));
}
```

Effective ACL = union of tree-level + branch (closure-filtered) + node-level grants.

## 5. REST API Endpoints (v1)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/auth/register` | Register user |
| POST | `/api/v1/auth/login` | Login |
| POST | `/api/v1/auth/refresh` | Refresh token |
| GET | `/api/v1/circles` | List user circles |
| POST | `/api/v1/circles` | Create circle |
| GET | `/api/v1/circles/{id}/tree` | Paginated tree subgraph |
| POST | `/api/v1/circles/{id}/nodes` | Add node |
| PUT | `/api/v1/nodes/{id}` | Update node |
| POST | `/api/v1/nodes/{id}/relationships` | Add relationship |
| GET | `/api/v1/nodes/{id}/kinship/{otherId}` | Resolve kinship |
| POST | `/api/v1/circles/{id}/merge` | Merge trees |
| GET | `/api/v1/search` | Global search |
| GET | `/api/v1/dashboard` | Dashboard stats |

## 6. GraphQL Schema (excerpt)

```graphql
type Circle {
  id: ID!
  name: String!
  treeType: TreeType!
  rootNodes: [PersonNode!]!
  statistics: TreeStatistics!
}

type PersonNode {
  id: ID!
  fullName: String!
  gender: Gender!
  children(page: Int, size: Int): NodeConnection!
  relationships: [Relationship!]!
}

type Query {
  circle(id: ID!): Circle
  kinship(fromId: ID!, toId: ID!): KinshipResult
  search(query: String!, filters: SearchFilters): SearchResult
}
```

## 7. Frontend Architecture

```
frontend/src/
├── app/                    Next.js App Router
│   ├── (auth)/login
│   ├── (dashboard)/dashboard
│   ├── circles/[id]/tree
│   └── layout.tsx
├── components/
│   ├── ui/                 shadcn-style primitives
│   ├── tree/               React Flow canvas, NodeCard, MiniMap
│   └── dashboard/          Charts (recharts)
├── features/
│   ├── auth/               Redux slice + React Query hooks
│   ├── circles/
│   └── nodes/
├── store/                  Redux Toolkit store
├── lib/                    api client, auth utils
└── hooks/
```

### 7.1 Tree Canvas

- **React Flow** for pan/zoom/minimap
- Custom node component with avatar, badges, role border colors
- Edge labels from relationship type
- Lazy fetch children on expand via React Query

### 7.2 State

| Concern | Tool |
|---------|------|
| Auth session | Redux Toolkit |
| Server data | TanStack React Query |
| Tree viewport | Local React state + React Flow store |
| Theme | next-themes (dark/light) |

## 8. Flutter Mobile LLD

```
lib/
├── core/           api, auth, theme, routing (go_router)
├── features/
│   ├── auth/
│   ├── circles/
│   ├── tree/       custom painter or graphview package
│   └── sync/       offline queue
├── models/
└── widgets/
```

- **State:** Riverpod
- **HTTP:** dio with interceptors for JWT refresh
- **Local DB:** drift (SQLite)
- **Biometric:** local_auth

## 9. Audit Log Format

```json
{
  "entityType": "PersonNode",
  "entityId": "uuid",
  "action": "UPDATE",
  "userId": "uuid",
  "timestamp": "ISO-8601",
  "changes": [
    { "field": "fullName", "oldValue": "John", "newValue": "John Doe" }
  ]
}
```

Rollback replays inverse changes within same transaction boundary.

## 10. Error Handling

Standard envelope:

```json
{
  "success": false,
  "error": {
    "code": "CIRCLE_NOT_FOUND",
    "message": "Circle not found",
    "timestamp": "2026-07-04T08:00:00Z"
  }
}
```

HTTP mapping: 400 validation, 401 auth, 403 forbidden, 404 not found, 409 conflict.
