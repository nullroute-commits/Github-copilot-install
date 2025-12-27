# GitHub Copilot Agent Instructions

## Overview

This repository contains an **Enterprise CI/CD Pipeline** implementation using Python 3.12, Django 5, Docker Compose, and Ansible. It's a production-grade system with comprehensive testing, security scanning, and multi-environment deployment support.

---

## Architectural Design Decisions & Constraints

### Design Philosophy

This codebase follows these core architectural principles:

1. **Defense in Depth Security** - Multiple security layers (network, infrastructure, application, data)
2. **Separation of Concerns** - Clear boundaries between presentation, business logic, and data layers
3. **Configuration-Driven Environments** - Environment-specific behavior through configuration inheritance
4. **Audit-First Design** - All significant actions are logged for compliance and debugging
5. **Permission-Based Access** - RBAC system controls all resource access

### Critical Design Constraints

| Constraint | Rationale | Implementation |
|------------|-----------|----------------|
| UUID Primary Keys | Security (non-sequential), distributed systems compatibility | `BaseModel.id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)` |
| JSONB for Metadata | Flexible schema for audit logs, no migrations needed for new fields | `AuditLog.metadata = Column(JSONB, nullable=True)` |
| Soft Deletes via `is_active` | Data retention for audit trail, GDPR compliance | All models have `is_active = Column(Boolean, default=True)` |
| Cache-First Permission Checks | Performance at scale, 5-minute TTL prevents stale data | `RBACManager.cache_timeout = 300` |
| Superuser Bypass | Administrative access without permission enumeration | `if user.is_superuser: return True` |

---

## Architecture Summary

### Technology Stack

The project supports two deployment configurations:

**Django Configuration** (`requirements/base.txt`):

| Component | Technology | Version | Design Rationale |
|-----------|-----------|---------|------------------|
| Language | Python | 3.12.5 | Type hints, performance improvements |
| Framework | Django | 5.0.2 | Admin interface, middleware, forms |
| Database | PostgreSQL | 17.x | JSONB support, ACID compliance |
| ORM | SQLAlchemy | 1.4.49 | Used for RBAC/Audit models (explicit query control) |
| Cache | Memcached (python-memcached) | 1.59 | Session/permission caching |
| Message Queue | RabbitMQ (Pika) | 1.3.2 | Async task processing |
| WSGI Server | Gunicorn | 23.0.0 | Production-ready, multi-worker |
| Container Runtime | Docker Compose | v2.29+ | Service orchestration |
| Infrastructure | Ansible | 9.9.0 | Declarative deployments |

> **Note on ORM Choice:** This project uses SQLAlchemy (not Django ORM) for the core models in `app/core/models.py`. This decision provides explicit query control, cleaner async support, and ORM-agnostic patterns that work across both Django and FastAPI stacks.

**FastAPI Configuration** (`pyproject.toml`):

| Component | Technology | Version | Design Rationale |
|-----------|-----------|---------|------------------|
| Language | Python | 3.12 | Async support, type hints |
| Framework | FastAPI | 0.115.4 | Async-first, OpenAPI generation |
| Database | PostgreSQL (asyncpg) | 0.30.0 | Async database driver |
| ORM | SQLAlchemy | 2.0.36 | Async ORM support |
| Cache | Redis | 5.2.0 | Async cache, pub/sub capability |
| Observability | OpenTelemetry | 1.28.2 | Distributed tracing |
| Validation | Pydantic | 2.10.2 | Runtime type validation |

> **Architectural Note:** The repository supports two configuration approaches. The Django stack uses `requirements/` files while the FastAPI stack uses `pyproject.toml`. This dual-stack design allows teams to choose based on their needs: Django for admin-heavy apps, FastAPI for API-first services.

### Multi-Tier Architecture

**Base Infrastructure** (docker-compose.base.yml):
```
┌─────────────────────────────────────────────────────────────────┐
│  Presentation Layer: Nginx 1.27 (Load Balancer, SSL Termination)│
├─────────────────────────────────────────────────────────────────┤
│  Application Layer: Django/FastAPI + RBAC + Audit System        │
├─────────────────────────────────────────────────────────────────┤
│  Data Layer: PostgreSQL 17 + Redis 7.4                          │
└─────────────────────────────────────────────────────────────────┘
```

**Django Stack Additional Services:**
- Memcached 1.6 (Session cache, permission cache via Django's cache framework)
- RabbitMQ 3.12 (Message broker, async tasks)

> **Design Decision on Caching:** The base infrastructure (`docker-compose.base.yml`) defines Redis as the shared cache service. The Django stack additionally uses Memcached (configured in `config/settings/base.py`) for Django-specific caching patterns like sessions and RBAC permission lookups. Redis is used for the FastAPI stack and shared services. This dual-cache approach allows each stack to use its optimal caching backend.

---

## Project Structure

```
├── src/                    # FastAPI application source code
│   ├── api/               # FastAPI endpoints and routers
│   ├── core/              # Core business logic and configuration
│   └── utils/             # Utility functions and helpers
├── app/                    # Django application
│   └── core/              # Core Django models and systems
│       ├── rbac.py        # Role-Based Access Control (428 lines)
│       ├── audit.py       # Comprehensive audit logging (465 lines)
│       ├── models.py      # SQLAlchemy models (205 lines)
│       ├── cache/         # Memcached integration
│       ├── db/            # Database connection management
│       └── queue/         # RabbitMQ integration
├── tests/                  # Test suites (pytest)
│   ├── unit/              # Unit tests (isolated, fast)
│   ├── integration/       # Integration tests (with services)
│   ├── e2e/               # End-to-end tests (full stack)
│   └── performance/       # Performance/load tests (k6)
├── docker/                 # Docker configurations
├── environments/           # Environment-specific configs
├── ansible/                # Infrastructure as Code
│   ├── playbooks/         # Deployment playbooks (deploy.yml)
│   ├── inventories/       # Environment inventories (dev, test, prod)
│   └── templates/         # Ansible Jinja2 templates
├── config/                 # Django configuration
│   └── settings/          # Environment-specific settings
│       ├── base.py        # Shared settings (196 lines)
│       ├── development.py # Debug mode, verbose logging
│       ├── testing.py     # Test database, fast I/O
│       └── production.py  # Optimized, secure settings
├── ci/                     # CI/CD configurations and scripts
├── requirements/           # Django dependencies
│   ├── base.txt           # Core dependencies
│   ├── development.txt    # Dev tools (black, flake8)
│   ├── test.txt           # Test dependencies
│   └── production.txt     # Production dependencies
└── pyproject.toml          # FastAPI project configuration
```

---

## Core Systems (Detailed Analysis)

### 1. Role-Based Access Control (RBAC)

**Location:** `app/core/rbac.py` (428 lines)

**Architecture:**
```
┌──────────────────────────────────────────────────────────────┐
│                     RBAC System Architecture                  │
├──────────────────────────────────────────────────────────────┤
│  Decorator Layer: @require_permission, @require_role,        │
│                   @require_any_permission                    │
├──────────────────────────────────────────────────────────────┤
│  Manager Layer: RBACManager (singleton instance)             │
│  - get_user_permissions(user_id, use_cache=True)            │
│  - get_user_roles(user_id, use_cache=True)                  │
│  - has_permission(user_id, permission_name)                 │
│  - has_role(user_id, role_name)                             │
│  - assign_role(user_id, role_name, assigned_by)             │
│  - revoke_role(user_id, role_name, revoked_by)              │
│  - create_role(name, description, permissions, created_by)   │
│  - create_permission(name, resource, action, ...)           │
├──────────────────────────────────────────────────────────────┤
│  Cache Layer: Memcached (5-minute TTL)                       │
│  - Cache key format: "user_permissions:{user_id}"           │
│  - Cache key format: "user_roles:{user_id}"                 │
├──────────────────────────────────────────────────────────────┤
│  Data Layer: SQLAlchemy ORM                                  │
│  - Users ↔ user_roles ↔ Roles ↔ role_permissions ↔ Permissions│
└──────────────────────────────────────────────────────────────┘
```

**Design Decisions:**

| Decision | Rationale | Code Reference |
|----------|-----------|----------------|
| Global singleton `rbac_manager` | Single point of access, consistent state | Line 330: `rbac_manager = RBACManager()` |
| Cache-first lookups | Performance at scale | Lines 52-55: `if use_cache: cached_permissions = cache_get(cache_key)` |
| Superuser bypass | Admin access without permission enumeration | Lines 65-67: `if user.is_superuser: ... permissions = {perm.name for perm in all_permissions}` |
| Decorator-based enforcement | Clean separation, declarative security | Lines 334-358: `def require_permission(permission_name)` |
| Automatic cache invalidation | Consistency after role changes | Lines 176-177, 219-220: `self._clear_user_cache(user_id)` |

**Usage Pattern:**

```python
from app.core.rbac import require_permission, require_role, rbac_manager

# Decorator-based (preferred for endpoints)
@require_permission('user.create')
def create_user(request, username, email):
    # Permission automatically checked before function executes
    # Raises PermissionError if user lacks permission
    pass

@require_role('admin')
def admin_only_function(request):
    pass

@require_any_permission('user.read', 'user.list')
def flexible_access_function(request):
    pass

# Programmatic checking (for conditional logic)
if rbac_manager.has_permission(user_id, 'user.update'):
    # Perform action
    pass

# Role management
rbac_manager.assign_role(user_id, 'editor', assigned_by=admin_id)
rbac_manager.revoke_role(user_id, 'editor', revoked_by=admin_id)
```

### 2. Audit Logging System

**Location:** `app/core/audit.py` (465 lines)

**Architecture:**
```
┌──────────────────────────────────────────────────────────────┐
│                   Audit System Architecture                   │
├──────────────────────────────────────────────────────────────┤
│  Decorator Layer: @audit_activity, @audit_model_changes      │
├──────────────────────────────────────────────────────────────┤
│  Logger Class: AuditLogger (singleton instance)              │
│  - log_activity(action, user_id, resource_type, ...)        │
│  - log_model_change(action, model_instance, user_id, ...)   │
│  - log_authentication(action, user_id, username, success)   │
│  - log_request(method, path, user_id, ...)                  │
│  - get_user_activity(user_id, limit, offset)                │
│  - get_resource_history(resource_type, resource_id, limit)  │
├──────────────────────────────────────────────────────────────┤
│  Sanitization Layer: _sanitize_data()                        │
│  Sensitive fields: password, token, secret, key, etc.        │
├──────────────────────────────────────────────────────────────┤
│  Storage Layer: PostgreSQL (AuditLog table with JSONB)       │
└──────────────────────────────────────────────────────────────┘
```

**Design Decisions:**

| Decision | Rationale | Code Reference |
|----------|-----------|----------------|
| JSONB columns for values | Flexible schema, no migrations for new fields | `old_values`, `new_values`, `metadata`, `request_data` |
| Automatic sanitization | Security compliance, prevent credential leaks | Lines 320-350: `_sanitize_data()` method |
| Configurable via settings | Enable/disable per environment | Lines 31-34: `AUDIT_ENABLED`, `AUDIT_LOG_MODELS`, etc. |
| Decorator + manual API | Automatic for common cases, flexible for edge cases | Lines 358-416 (decorator), Lines 36-114 (manual) |
| Non-blocking design | Audit failures don't break application | Try/except with logging at Lines 80-114 |

**Sensitive Fields (Always Redacted):**
```python
sensitive_fields = {
    'password', 'password_hash', 'token', 'secret', 'key',
    'authorization', 'cookie', 'session', 'csrf_token'
}
```

**Usage Pattern:**

```python
from app.core.audit import audit_activity, audit_logger, log_user_activity

# Decorator-based (automatic logging)
@audit_activity('USER_UPDATE', resource_type='User')
def update_user(request, user_id, **fields):
    # Activity automatically logged with context
    # Logs both success and failure (with error details)
    pass

# Manual logging
audit_logger.log_activity(
    action='CUSTOM_ACTION',
    user_id=user_id,
    resource_type='Resource',
    resource_id=resource_id,
    old_values={'status': 'draft'},
    new_values={'status': 'published'},
    message='Action description'
)

# Helper function
log_user_activity(
    action='ACTION_NAME',
    user_id=user_id,
    resource_type='ResourceType',
    resource_id=resource_id,
    message='Description of what happened'
)

# Retrieve audit history
user_activities = audit_logger.get_user_activity(user_id, limit=50)
resource_history = audit_logger.get_resource_history('User', user_id, limit=20)
```

### 3. Data Models

**Location:** `app/core/models.py` (205 lines)

**Entity Relationship Diagram:**
```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│     Users       │      │   user_roles    │      │     Roles       │
│─────────────────│      │─────────────────│      │─────────────────│
│ id (UUID) [PK]  │◄────►│ user_id [FK]    │◄────►│ id (UUID) [PK]  │
│ username        │      │ role_id [FK]    │      │ name            │
│ email           │      └─────────────────┘      │ description     │
│ password_hash   │                               │ is_active       │
│ is_active       │                               │ is_system       │
│ is_staff        │                               └────────┬────────┘
│ is_superuser    │                                        │
└─────────────────┘                                        │
                                                           │
┌─────────────────┐      ┌─────────────────┐              │
│   Permissions   │◄────►│role_permissions │◄─────────────┘
│─────────────────│      │─────────────────│
│ id (UUID) [PK]  │      │ role_id [FK]    │
│ name            │      │ permission_id   │
│ resource        │      └─────────────────┘
│ action          │
│ is_active       │
│ is_system       │
└─────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         AuditLog                                 │
│─────────────────────────────────────────────────────────────────│
│ id (UUID) [PK] | user_id [FK] | action | resource_type          │
│ old_values (JSONB) | new_values (JSONB) | metadata (JSONB)      │
│ request_method | request_path | response_status | message       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     SystemConfiguration                          │
│─────────────────────────────────────────────────────────────────│
│ id (UUID) [PK] | key (UNIQUE) | value (JSONB) | description     │
│ is_active | is_system | created_at | updated_at                 │
└─────────────────────────────────────────────────────────────────┘
```

**BaseModel Pattern (All Models Inherit):**
```python
class BaseModel(Base):
    __abstract__ = True
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), ..., onupdate=lambda: datetime.now(timezone.utc))
    created_by = Column(UUID(as_uuid=True), ForeignKey('users.id'), nullable=True)
    updated_by = Column(UUID(as_uuid=True), ForeignKey('users.id'), nullable=True)
    
    def to_dict(self):
        return {column.name: getattr(self, column.name) for column in self.__table__.columns}
```

### 4. Configuration System

**Location:** `config/settings/` (base.py: 196 lines)

**Configuration Hierarchy (Highest to Lowest Priority):**

```
1. Environment Variables (os.environ)
   └── Set at runtime, container orchestration

2. Docker Secrets (/run/secrets/*)
   └── Secure credential storage

3. Environment-specific settings
   └── config/settings/{development,testing,production}.py

4. Base settings
   └── config/settings/base.py

5. Default values in code
   └── os.environ.get('KEY', 'default')
```

**Environment Files:**

| File | Purpose |
|------|---------|
| `.env.example` | Template for environment variables |
| `.env.app.example` | Application-specific settings |
| `.env.db.example` | Database connection settings |
| `.env.cache.example` | Cache configuration |
| `.env.queue.example` | RabbitMQ settings |
| `.env.security.example` | Security-related settings |
| `.env.logging.example` | Logging configuration |

**Key Configuration Settings:**

```python
# Database (config/settings/base.py:69-80)
DATABASES = {
    'default': {
        'ENGINE': os.environ.get('DATABASE_ENGINE', 'django.db.backends.postgresql'),
        'NAME': os.environ.get('POSTGRES_DB', 'django_app'),
        'USER': os.environ.get('POSTGRES_USER', 'postgres'),
        'PASSWORD': os.environ.get('POSTGRES_PASSWORD', 'postgres'),
        'HOST': os.environ.get('POSTGRES_HOST', 'localhost'),
        'PORT': os.environ.get('POSTGRES_PORT', '5432'),
    }
}

# Cache (config/settings/base.py:119-133)
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.memcached.PyMemcacheCache',
        'LOCATION': os.environ.get('MEMCACHED_SERVERS', 'memcached:11211'),
    }
}

# RBAC Settings (config/settings/base.py:189-190)
RBAC_CACHE_TIMEOUT = int(os.environ.get('RBAC_CACHE_TIMEOUT', '300'))
RBAC_SESSION_TIMEOUT = int(os.environ.get('RBAC_SESSION_TIMEOUT', '3600'))

# Audit Settings (config/settings/base.py:193-196)
AUDIT_ENABLED = os.environ.get('AUDIT_ENABLED', 'True').lower() == 'true'
AUDIT_LOG_MODELS = os.environ.get('AUDIT_LOG_MODELS', 'True').lower() == 'true'
AUDIT_LOG_REQUESTS = os.environ.get('AUDIT_LOG_REQUESTS', 'True').lower() == 'true'
AUDIT_LOG_AUTHENTICATION = os.environ.get('AUDIT_LOG_AUTHENTICATION', 'True').lower() == 'true'
```

---

## Development Guidelines

### Code Style and Conventions

**Python Standards:**

| Aspect | Django Stack | FastAPI Stack |
|--------|--------------|---------------|
| Version | Python 3.12.5 | Python 3.12 |
| Formatter | Black 24.3.0 | Black 24.10.0 |
| Linter | Flake8 6.1.0 | Ruff 0.8.1 |
| Type Checker | MyPy 1.5.1 | MyPy 1.13.0 |
| Test Runner | pytest 7.4.3 | pytest 8.3.4 |

**Code Conventions:**

1. **Type hints required** - All function signatures must have type annotations
2. **Docstrings required** - All public functions/classes need docstrings (Google style)
3. **Line length** - 88 characters (Black default)
4. **Import order** - stdlib → third-party → local (isort-compatible)

### Running Linters

**Django Stack:**
```bash
# Format code
black src tests app

# Lint code
flake8 src tests app

# Type checking
mypy src

# All quality checks
make lint
```

**FastAPI Stack (pyproject.toml configuration):**
```bash
# Format code
black src tests

# Lint code (Ruff replaces flake8 + isort + pylint)
ruff check src tests

# Type checking
mypy src

# Security scan
bandit -r src

# All checks
pip install -e ".[dev,security]"
```

### Testing Strategy

**Test Categories:**

| Category | Location | Purpose | Command |
|----------|----------|---------|---------|
| Unit | `tests/unit/` | Isolated component tests | `pytest tests/unit -v` |
| Integration | `tests/integration/` | Cross-component tests | `pytest tests/integration -v` |
| E2E | `tests/e2e/` | Full stack tests | `pytest tests/e2e -v` |
| Performance | `tests/performance/` | Load tests (k6) | `k6 run tests/performance/load-test.js` |

**Test Commands:**

```bash
# Run all tests
make test

# Run unit tests only
pytest tests/unit -v

# Run integration tests (requires services)
pytest tests/integration -v

# Run with coverage
pytest --cov=src --cov=app --cov-report=html --cov-report=term-missing

# Run specific test file
pytest tests/unit/test_rbac.py -v

# Run with debug (drop into pdb on failure)
pytest tests/ -v --pdb

# Parallel execution
pytest tests/ -n auto
```

**Coverage Requirements:** Minimum 80% coverage (enforced in CI)

### Docker Development

**Development Workflow:**

```bash
# Start development environment
make dev-up
# Or explicitly:
docker compose -f docker-compose.base.yml -f docker-compose.dev.yml up -d

# View logs
docker compose -f docker-compose.base.yml -f docker-compose.dev.yml logs -f

# Run tests in Docker
docker compose -f docker-compose.base.yml -f docker-compose.test.yml run --rm app pytest

# Shell into app container
docker compose -f docker-compose.base.yml -f docker-compose.dev.yml exec app bash

# Rebuild after dependency changes
docker compose -f docker-compose.base.yml -f docker-compose.dev.yml build

# Stop environment
make dev-down
```

**Docker Compose Files:**

| File | Purpose |
|------|---------|
| `docker-compose.base.yml` | Base services (postgres, redis, nginx) |
| `docker-compose.dev.yml` | Development overrides (debug, hot-reload) |
| `docker-compose.development.yml` | Alternative dev config |
| `docker-compose.test.yml` | Test environment (ephemeral DB) |
| `docker-compose.testing.yml` | Alternative test config |
| `docker-compose.prod.yml` | Production optimizations |
| `docker-compose.production.yml` | Alternative prod config |
| `docker-compose.ci.yml` | CI/CD services |
| `docker-compose.pipeline.yml` | Pipeline executor |

---

## Database Design

### Key Models

| Model | Purpose | Primary Key | Key Fields |
|-------|---------|-------------|------------|
| `User` | User accounts | UUID | username, email, password_hash, is_active, is_superuser |
| `Role` | RBAC roles | UUID | name, is_active, is_system |
| `Permission` | RBAC permissions | UUID | name, resource, action, is_active |
| `AuditLog` | Activity audit trail | UUID | action, resource_type, old_values (JSONB), new_values (JSONB) |
| `SystemConfiguration` | Runtime settings | UUID | key (unique), value (JSONB) |

### Relationships

```
Users ←→ user_roles ←→ Roles ←→ role_permissions ←→ Permissions
  │
  └──→ AuditLog (user_id foreign key)
```

- `Users` ↔ `Roles`: Many-to-Many via `user_roles` junction table
- `Roles` ↔ `Permissions`: Many-to-Many via `role_permissions` junction table
- `Users` → `AuditLog`: One-to-Many (user actions logged)
- All tables use UUID primary keys for security and distributed systems

### Database Conventions

1. **UUID Primary Keys** - Never use sequential IDs (security, distribution)
2. **JSONB for Metadata** - Flexible schema, avoid migrations for new attributes
3. **Audit Fields** - All tables include `created_at`, `updated_at`, `created_by`, `updated_by`
4. **Soft Deletes** - Use `is_active=False` instead of DELETE for audit compliance
5. **System Flags** - `is_system=True` prevents deletion of critical records
6. **Naming** - PostgreSQL snake_case convention
7. **Indexing** - Index all foreign keys and frequently queried fields

### Database Commands

```bash
# Django Stack
python manage.py migrate              # Run migrations
python manage.py makemigrations       # Create new migrations
python manage.py showmigrations       # Show migration status

# FastAPI Stack (Alembic)
alembic upgrade head                  # Run migrations
alembic downgrade -1                  # Rollback one migration
alembic revision --autogenerate -m "Description"  # Create migration
alembic history                       # Show migration history

# Makefile shortcuts
make db-migrate                       # Run migrations in Docker
make db-rollback                      # Rollback one migration
make db-reset                         # Reset to base + upgrade
```

---

## Security Best Practices

### Security Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Security Layers                          │
├─────────────────────────────────────────────────────────────────┤
│  Network: Firewall, WAF, DDoS Protection, Rate Limiting        │
├─────────────────────────────────────────────────────────────────┤
│  Infrastructure: Container Scanning, Image Security, Secrets   │
├─────────────────────────────────────────────────────────────────┤
│  Application: RBAC, Input Validation, Output Encoding, CSRF    │
├─────────────────────────────────────────────────────────────────┤
│  Data: Encryption (rest/transit), Access Control, Audit Logs   │
└─────────────────────────────────────────────────────────────────┘
```

### Required Security Checks for All Code Changes

| Check | Requirement | Enforcement |
|-------|-------------|-------------|
| Input Validation | Validate all user inputs | Forms, Pydantic models |
| Output Encoding | Prevent XSS attacks | Django auto-escaping, `escape()` |
| SQL Injection | Use ORM, parameterized queries | SQLAlchemy, Django ORM |
| Sensitive Data | Never log passwords/tokens | `_sanitize_data()` in audit |
| CSRF Protection | Use CSRF middleware | Django middleware enabled |
| Authentication | Check user identity | `@require_permission` decorator |
| Authorization | Check permissions | RBAC system |
| Secure Headers | X-Frame-Options, CSP, etc. | Nginx configuration |

### Sensitive Fields (Always Redacted in Logs)

```python
# From app/core/audit.py:333-336
sensitive_fields = {
    'password', 'password_hash', 'token', 'secret', 'key',
    'authorization', 'cookie', 'session', 'csrf_token'
}
```

### Security Scanning Tools

| Tool | Purpose | Command |
|------|---------|---------|
| Bandit | Python AST security scanner | `bandit -r src -f json -o bandit-report.json` |
| Safety | Dependency vulnerability scanner | `safety check --json > safety-report.json` |
| pip-audit | Dependency vulnerability scanner | `pip-audit --desc --format json > pip-audit-report.json` |
| Trivy | Container vulnerability scanner | `trivy image <image-name>` |

### Security Configuration (config/settings/base.py)

```python
# Security headers and settings
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_HTTPONLY = True

# Production settings (production.py)
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
```

---

## CI/CD Pipeline

### Pipeline Architecture (`.github/workflows/ci-cd.yml`)

```
┌─────────────────────────────────────────────────────────────────┐
│                      CI/CD Pipeline Flow                        │
├─────────────────────────────────────────────────────────────────┤
│  1. quality-checks (parallel with unit-tests)                   │
│     └── Checkout → Python setup → Install deps                  │
│         └── black --check → ruff check → mypy → bandit/safety   │
├─────────────────────────────────────────────────────────────────┤
│  2. unit-tests (matrix: dev, test)                              │
│     └── Services: postgres:17-alpine, redis:7.4-alpine          │
│         └── pytest --cov → Upload coverage                      │
├─────────────────────────────────────────────────────────────────┤
│  3. integration-tests (needs: quality-checks, unit-tests)       │
│     └── docker compose up → health check → pytest integration   │
├─────────────────────────────────────────────────────────────────┤
│  4. build-images (needs: integration-tests, on main/release)    │
│     └── docker/setup-buildx → login → metadata → build+push     │
├─────────────────────────────────────────────────────────────────┤
│  5. security-scan (needs: build-images)                         │
│     └── trivy image scan → upload results                       │
├─────────────────────────────────────────────────────────────────┤
│  6. deploy (needs: security-scan, matrix: environments)         │
│     └── ansible-playbook deploy.yml → health check              │
├─────────────────────────────────────────────────────────────────┤
│  7. performance-tests (needs: deploy, staging only)             │
│     └── k6 load test → upload results                           │
├─────────────────────────────────────────────────────────────────┤
│  8. cleanup (needs: deploy, always runs)                        │
│     └── docker system prune                                     │
└─────────────────────────────────────────────────────────────────┘
```

### Pipeline Stages

| Stage | Purpose | Trigger |
|-------|---------|---------|
| Code Quality | Linting, formatting, type checking | All pushes/PRs |
| Security Scanning | Bandit, Safety, pip-audit | All pushes/PRs |
| Unit Tests | Isolated component tests | All pushes/PRs |
| Integration Tests | Cross-component tests | After quality + unit |
| Build | Multi-stage Docker builds | main, release/* only |
| Security Scan | Trivy container scanning | After build |
| Deploy | Ansible deployment | After security scan |
| Performance | k6 load tests | Staging only |

### Deployment Environments

| Environment | Trigger | Inventory | Approval |
|-------------|---------|-----------|----------|
| Development | `develop` branch | `ansible/inventories/dev/` | Auto |
| Test | `main` branch | `ansible/inventories/test/` | Auto |
| Production | `release/*` branch | `ansible/inventories/prod/` | Manual |

> **Note:** The CI workflow references `staging` environment but the actual Ansible inventories are `dev`, `test`, and `prod`.

### Makefile Targets

```bash
# Development
make dev-up          # Start dev environment
make dev-down        # Stop dev environment
make dev-logs        # View dev logs

# Testing
make test            # Run tests in pipeline
make test-up         # Start test environment
make test-down       # Stop test environment

# Quality
make lint            # Run code quality checks
make security        # Run security scans

# Build & Deploy
make build           # Build Docker images
make deploy ENVIRONMENT=prod  # Deploy to environment
make pipeline        # Run full pipeline (lint → test → build → security)

# CI/CD Infrastructure
make ci-up           # Start CI services
make ci-down         # Stop CI services
make ci-logs         # View CI logs

# Cleanup
make clean           # Clean all resources and caches
```

### Blue-Green Deployment

The system uses blue-green deployment for zero-downtime updates:

1. **Deploy** to inactive environment (blue or green)
2. **Health check** verification
3. **Switch** load balancer to new environment
4. **Monitor** and verify new deployment
5. **Keep** previous environment for rollback (configurable retention)

---

## Common Tasks

### Adding a New Permission

```python
from app.core.rbac import rbac_manager

# Create permission (returns UUID or None)
permission_id = rbac_manager.create_permission(
    name='resource.action',      # e.g., 'user.create', 'document.delete'
    resource='resource',          # e.g., 'user', 'document', 'report'
    action='action',              # e.g., 'create', 'read', 'update', 'delete'
    description='Permission description',
    created_by=admin_user_id      # UUID of admin creating this
)

if permission_id:
    print(f"Created permission with ID: {permission_id}")
else:
    print("Permission already exists or creation failed")
```

### Adding a New Role

```python
from app.core.rbac import rbac_manager

# Create role with permissions
role_id = rbac_manager.create_role(
    name='editor',
    description='Can edit and publish content',
    permissions=['document.read', 'document.update', 'document.publish'],
    created_by=admin_user_id
)

# Assign role to user
success = rbac_manager.assign_role(
    user_id=target_user_id,
    role_name='editor',
    assigned_by=admin_user_id
)
```

### Logging User Activity

```python
from app.core.audit import audit_logger, log_user_activity, audit_activity

# Method 1: Decorator (automatic, preferred)
@audit_activity('DOCUMENT_PUBLISH', resource_type='Document')
def publish_document(request, document_id, **kwargs):
    # Activity logged automatically on success/failure
    pass

# Method 2: Helper function
log_user_activity(
    action='DOCUMENT_PUBLISH',
    user_id=user_id,
    resource_type='Document',
    resource_id=document_id,
    message='Document published successfully'
)

# Method 3: Direct logger (most control)
audit_logger.log_activity(
    action='DOCUMENT_PUBLISH',
    user_id=user_id,
    session_id=request.session.session_key,
    ip_address=request.META.get('REMOTE_ADDR'),
    user_agent=request.META.get('HTTP_USER_AGENT'),
    resource_type='Document',
    resource_id=document_id,
    old_values={'status': 'draft'},
    new_values={'status': 'published'},
    metadata={'publish_channel': 'web'},
    message='Document published successfully'
)
```

### Adding Environment Configuration

1. **Add to `.env.example`:**
   ```bash
   # New feature setting
   NEW_FEATURE_ENABLED=true
   NEW_FEATURE_TIMEOUT=30
   ```

2. **Add to `config/settings/base.py`:**
   ```python
   # New feature configuration
   NEW_FEATURE_ENABLED = os.environ.get('NEW_FEATURE_ENABLED', 'False').lower() == 'true'
   NEW_FEATURE_TIMEOUT = int(os.environ.get('NEW_FEATURE_TIMEOUT', '30'))
   ```

3. **Add environment-specific overrides (optional):**
   ```python
   # config/settings/development.py
   NEW_FEATURE_ENABLED = True  # Always on in dev
   
   # config/settings/production.py
   NEW_FEATURE_TIMEOUT = 60    # Longer timeout in prod
   ```

### Adding a New API Endpoint (FastAPI)

```python
# src/api/routers/new_feature.py
from fastapi import APIRouter, Depends, HTTPException
from app.core.rbac import require_permission
from app.core.audit import audit_activity

router = APIRouter(prefix="/features", tags=["features"])

@router.post("/")
@require_permission('feature.create')
@audit_activity('FEATURE_CREATE', resource_type='Feature')
async def create_feature(request: FeatureCreate, user_id: str = Depends(get_current_user_id)):
    # Implementation
    pass
```

### Adding a New Model

```python
# app/core/models.py
class NewModel(BaseModel):
    """New model description."""
    
    __tablename__ = 'new_models'
    
    name = Column(String(100), unique=True, nullable=False, index=True)
    description = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    metadata = Column(JSONB, nullable=True)
    
    def __repr__(self):
        return f'<NewModel(name={self.name})>'
```

Then create migration:
```bash
# FastAPI/Alembic
alembic revision --autogenerate -m "Add new_models table"
alembic upgrade head

# Django
python manage.py makemigrations
python manage.py migrate
```

---

## Documentation

| Document | Description |
|----------|-------------|
| `README.md` | Project overview and quick start |
| `ARCHITECTURE.md` | System architecture details |
| `SECURITY_MODEL.md` | Security implementation details |
| `DATABASE_DESIGN.md` | Database schema and design |
| `CI_CD_PIPELINE.md` | CI/CD pipeline documentation |
| `CONFIGURATION_SYSTEM.md` | Configuration management |
| `DESIGN_PATTERNS_AND_SOLUTIONS.md` | Design patterns used |
| `DEPLOYMENT_PIPELINE.md` | Deployment procedures |

---

## Troubleshooting

### Database Connection Issues

```bash
# Check PostgreSQL is running
docker compose ps postgres

# Check connection from host
docker compose exec postgres psql -U postgres -d django_app -c "SELECT 1"

# Check database logs
docker compose logs postgres

# Common issues:
# - POSTGRES_PASSWORD not set → Check .env file
# - Port conflict → Check if 5432 is available
# - Data corruption → docker compose down -v (loses data!)
```

### Cache Issues

**Django Stack (Memcached):**
```bash
# Check Memcached is running
docker compose ps memcached

# Restart Memcached
docker compose restart memcached

# Flush cache (if accessible)
echo "flush_all" | nc localhost 11211
```

**FastAPI Stack (Redis):**
```bash
# Check Redis is running
docker compose ps redis

# Check Redis connectivity
docker compose exec redis redis-cli ping

# Check Redis memory usage
docker compose exec redis redis-cli info memory

# Flush all keys (development only!)
docker compose exec redis redis-cli FLUSHALL
```

### Test Failures

```bash
# Run tests with verbose output
pytest tests/ -v --tb=long

# Run specific test file
pytest tests/unit/test_rbac.py -v

# Run tests matching pattern
pytest tests/ -k "test_permission" -v

# Debug mode (drop into pdb on failure)
pytest tests/ -v --pdb

# Show local variables in traceback
pytest tests/ -v --tb=long --showlocals

# Run tests with fresh database
docker compose -f docker-compose.base.yml -f docker-compose.test.yml down -v
docker compose -f docker-compose.base.yml -f docker-compose.test.yml up -d
pytest tests/
```

### Permission/RBAC Issues

```python
# Debug permission checking
from app.core.rbac import rbac_manager

# Check user's permissions (bypass cache)
permissions = rbac_manager.get_user_permissions(user_id, use_cache=False)
print(f"User permissions: {permissions}")

# Check user's roles
roles = rbac_manager.get_user_roles(user_id, use_cache=False)
print(f"User roles: {roles}")

# Check specific permission
has_perm = rbac_manager.has_permission(user_id, 'user.create', use_cache=False)
print(f"Has user.create: {has_perm}")

# Clear user's cache
rbac_manager._clear_user_cache(user_id)
```

### Docker Issues

```bash
# View all container logs
docker compose logs -f

# View specific service logs
docker compose logs -f app

# Check container health
docker compose ps

# Rebuild all images (after Dockerfile changes)
docker compose build --no-cache

# Remove all volumes (database data!)
docker compose down -v

# Check resource usage
docker stats

# Shell into running container
docker compose -f docker-compose.base.yml -f docker-compose.dev.yml exec app bash
# Shortcut: make shell ENVIRONMENT=dev

# Check container's environment
docker compose -f docker-compose.base.yml -f docker-compose.dev.yml exec app env | sort
```

> **Tip:** Use `make shell ENVIRONMENT=dev` instead of the long docker compose command. The Makefile provides shortcuts for common operations.

---

## Quick Reference Commands

### Development Commands

```bash
# Environment Management
make dev-up                    # Start development environment
make dev-down                  # Stop development environment
make dev-logs                  # View development logs
make test-up                   # Start test environment
make test-down                 # Stop test environment
make prod-up                   # Start production environment
make prod-down                 # Stop production environment

# Quality & Testing
make test                      # Run all tests in pipeline
make lint                      # Run code quality checks
make security                  # Run security scans
make pipeline                  # Run full pipeline (lint → test → build → security)

# Build & Deploy
make build                     # Build Docker images
make deploy ENVIRONMENT=dev    # Deploy to development
make deploy ENVIRONMENT=test   # Deploy to test
make deploy ENVIRONMENT=prod   # Deploy to production

# Cleanup
make clean                     # Clean all resources and caches
```

### Docker Commands

```bash
# Container Management
docker compose build           # Build/rebuild containers
docker compose logs -f         # Follow all logs
docker compose ps              # List containers
docker compose down            # Stop containers
docker compose down -v         # Stop and remove volumes

# Shell Access
docker compose -f docker-compose.base.yml -f docker-compose.dev.yml exec app bash
docker compose -f docker-compose.base.yml -f docker-compose.dev.yml exec postgres psql -U postgres
docker compose -f docker-compose.base.yml -f docker-compose.dev.yml exec redis redis-cli
```

### Database Commands

```bash
# Django Stack
python manage.py migrate              # Run migrations
python manage.py makemigrations       # Create migrations
python manage.py showmigrations       # Show migration status
python manage.py dbshell              # Database shell

# FastAPI Stack (Alembic)
alembic upgrade head                  # Run all pending migrations
alembic downgrade -1                  # Rollback one migration
alembic revision --autogenerate -m "Description"  # Create auto migration
alembic revision -m "Description"     # Create empty migration
alembic history                       # Show migration history
alembic current                       # Show current revision

# Makefile shortcuts
make db-migrate                       # Run migrations in Docker
make db-rollback                      # Rollback one migration
make db-reset                         # Reset database
```

### Ansible Commands

```bash
# Deploy to specific environment
ansible-playbook -i ansible/inventories/dev/hosts.yml ansible/playbooks/deploy.yml
ansible-playbook -i ansible/inventories/test/hosts.yml ansible/playbooks/deploy.yml
ansible-playbook -i ansible/inventories/prod/hosts.yml ansible/playbooks/deploy.yml

# With variables
ansible-playbook -i ansible/inventories/prod/hosts.yml ansible/playbooks/deploy.yml \
  -e 'app_version=abc123' -e 'environment=prod'

# Check mode (dry run)
ansible-playbook -i ansible/inventories/prod/hosts.yml ansible/playbooks/deploy.yml --check

# Verbose mode
ansible-playbook -i ansible/inventories/prod/hosts.yml ansible/playbooks/deploy.yml -vvv
```

---

## Notes for AI Agents

### Critical Rules

1. **Always check RBAC permissions** when implementing user-facing features
   - Use `@require_permission('resource.action')` decorator for endpoints
   - Check `rbac_manager.has_permission(user_id, 'permission')` for conditional logic

2. **Always log significant activities** using the audit system
   - Use `@audit_activity('ACTION', resource_type='Type')` decorator
   - Include `old_values` and `new_values` for data changes
   - Never log sensitive fields (passwords, tokens, etc.)

3. **Validate all inputs** and sanitize outputs
   - Use Pydantic models for FastAPI endpoints
   - Use Django forms for Django endpoints
   - Always escape user content in templates

4. **Follow existing patterns** - Check similar implementations in the codebase before creating new approaches

5. **Run tests** before committing changes
   - `make test` for full test suite
   - `pytest tests/unit -v` for quick feedback

6. **Use type hints** for all new Python code
   - All function signatures need type annotations
   - Use `Optional`, `List`, `Dict`, etc. from typing module

7. **Update documentation** when making significant changes
   - Update this file for architectural changes
   - Update relevant `.md` files for feature changes

8. **Security-first approach** - Consider security implications of all changes
   - Never expose sensitive data in logs or responses
   - Always use parameterized queries (ORM preferred)
   - Check for CSRF, XSS, SQL injection vulnerabilities

### Code Patterns to Follow

**Permission Check Pattern:**
```python
@require_permission('resource.action')
@audit_activity('ACTION_NAME', resource_type='Resource')
def endpoint(request, resource_id):
    # Permission and audit handled by decorators
    pass
```

**Error Handling Pattern:**
```python
try:
    result = perform_action()
    return success_response(result)
except PermissionError as e:
    logger.warning(f"Permission denied: {e}")
    raise HTTPException(status_code=403, detail=str(e))
except ValidationError as e:
    logger.warning(f"Validation failed: {e}")
    raise HTTPException(status_code=400, detail=str(e))
except Exception as e:
    logger.error(f"Unexpected error: {e}", exc_info=True)
    raise HTTPException(status_code=500, detail="Internal server error")
```

**Configuration Pattern:**
```python
# Always use environment variables with sensible defaults
SETTING = os.environ.get('SETTING_NAME', 'default_value')
NUMERIC_SETTING = int(os.environ.get('NUMERIC_SETTING', '100'))
BOOLEAN_SETTING = os.environ.get('BOOLEAN_SETTING', 'False').lower() == 'true'
```

### Files You Should NOT Modify Without Careful Review

| File | Reason |
|------|--------|
| `app/core/rbac.py` | Core security system |
| `app/core/audit.py` | Core compliance system |
| `app/core/models.py` | Database schema (requires migrations) |
| `config/settings/base.py` | Shared configuration |
| `.github/workflows/ci-cd.yml` | CI/CD pipeline |
| `docker-compose.base.yml` | Base infrastructure |
| `ansible/playbooks/deploy.yml` | Production deployment |

### Related Documentation

| Document | Description |
|----------|-------------|
| `README.md` | Project overview and quick start |
| `ARCHITECTURE.md` | Detailed system architecture |
| `SECURITY_MODEL.md` | Security implementation details |
| `DATABASE_DESIGN.md` | Database schema and design |
| `CI_CD_PIPELINE.md` | CI/CD pipeline documentation |
| `CONFIGURATION_SYSTEM.md` | Configuration management |
| `DESIGN_PATTERNS_AND_SOLUTIONS.md` | Design patterns used |
| `DEPLOYMENT_PIPELINE.md` | Deployment procedures |
| `ARCHITECTURE_REVIEW.md` | Architecture review notes |
| `REVIEW_SUMMARY.md` | Code review summary |
