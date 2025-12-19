# GitHub Copilot Agent Instructions

## Overview

This repository contains an **Enterprise CI/CD Pipeline** implementation using Python 3.12, Django 5, Docker Compose, and Ansible. It's a production-grade system with comprehensive testing, security scanning, and multi-environment deployment support.

---

## Architecture Summary

### Technology Stack

The project supports two deployment configurations:

**Django Configuration** (`requirements/`):

| Component | Technology | Version |
|-----------|-----------|---------|
| Language | Python | 3.12.5 |
| Framework | Django | 5.0.2 |
| Database | PostgreSQL | 17.2 |
| ORM | SQLAlchemy | 1.4.49 |
| Cache | Memcached (python-memcached) | 1.59 |
| Message Queue | RabbitMQ (Pika) | 1.3.2 |
| Container Runtime | Docker Compose | v2.29+ |
| Infrastructure | Ansible | 10.5.0 |

**FastAPI Configuration** (`pyproject.toml`):

| Component | Technology | Version |
|-----------|-----------|---------|
| Language | Python | 3.12 |
| Framework | FastAPI | 0.115.4 |
| Database | PostgreSQL (asyncpg) | 0.30.0 |
| ORM | SQLAlchemy | 2.0.36 |
| Cache | Redis | 5.2.0 |
| Observability | OpenTelemetry | 1.28.2 |

> **Note:** The repository supports two configuration approaches. The Django stack uses `requirements/` files while the FastAPI stack uses `pyproject.toml`. Choose the appropriate configuration based on your deployment needs.

### Multi-Tier Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Presentation Layer: Nginx Load Balancer + Django Web Interface │
├─────────────────────────────────────────────────────────────────┤
│  Application Layer: Django Business Logic + RBAC + Audit System │
├─────────────────────────────────────────────────────────────────┤
│  Data Layer: PostgreSQL + Memcached + RabbitMQ                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
├── src/                    # Application source code
│   ├── api/               # FastAPI application endpoints
│   ├── core/              # Core business logic and configuration
│   └── utils/             # Utility functions
├── app/                    # Django application
│   └── core/              # Core models, RBAC, audit systems
│       ├── rbac.py        # Role-Based Access Control system
│       ├── audit.py       # Comprehensive audit logging
│       └── models.py      # SQLAlchemy/Django models
├── tests/                  # Test suites
│   ├── unit/              # Unit tests
│   ├── integration/       # Integration tests
│   ├── e2e/               # End-to-end tests
│   └── performance/       # Performance tests
├── docker/                 # Docker configurations
├── environments/           # Environment-specific configs
├── ansible/                # Infrastructure as Code
│   ├── playbooks/         # Deployment playbooks
│   ├── inventories/       # Environment inventories
│   └── roles/             # Reusable roles
├── ci/                     # CI/CD configurations and scripts
└── config/                 # Django configuration
    └── settings/          # Environment-specific settings
```

---

## Core Systems

### 1. Role-Based Access Control (RBAC)

**Location:** `app/core/rbac.py`

The RBAC system implements a three-level hierarchy:

```
Users → Roles → Permissions
```

**Key Components:**

- `RBACManager` class for all permission operations
- Decorator-based permission checking: `@require_permission()`, `@require_role()`
- Cached permission lookups (Memcached) with 5-minute TTL
- Superuser bypass for administrative accounts

**Usage Example:**

```python
from app.core.rbac import require_permission, rbac_manager

@require_permission('user.create')
def create_user(request, username, email):
    # Permission automatically checked before function executes
    pass

# Check permissions programmatically
if rbac_manager.has_permission(user_id, 'user.update'):
    # Perform action
    pass
```

### 2. Audit Logging System

**Location:** `app/core/audit.py`

Comprehensive activity tracking for security and compliance:

**Key Features:**

- Automatic activity logging
- Model change detection (old_values, new_values)
- Request/response logging
- Sensitive data sanitization (passwords, tokens redacted)
- JSONB storage for flexible querying

**Usage Example:**

```python
from app.core.audit import audit_activity, audit_logger

@audit_activity('USER_UPDATE', resource_type='User')
def update_user(request, user_id, **fields):
    # Activity automatically logged with context
    pass

# Manual logging
audit_logger.log_activity(
    action='CUSTOM_ACTION',
    user_id=user_id,
    resource_type='Resource',
    message='Action description'
)
```

### 3. Configuration System

**Location:** `config/settings/` and environment files

**Hierarchy (highest to lowest priority):**

1. Environment Variables
2. Docker Secrets (`/run/secrets/`)
3. Environment-specific settings (`config/settings/{env}.py`)
4. Base settings (`config/settings/base.py`)
5. Default values

**Environment Management:**

- `development` - Debug enabled, hot-reload
- `testing` - Isolated databases, fast I/O
- `staging` - Production-like, approval gates
- `production` - Fully optimized, secure

---

## Development Guidelines

### Code Style and Conventions

1. **Python Version:** Python 3.12 with type hints
2. **Code Formatting:** Black (v24.3.0 for Django, v24.10.0 for FastAPI)
3. **Linting:** 
   - Django: Flake8
   - FastAPI: Ruff
4. **Type Checking:** MyPy
5. **Security Scanning:** Bandit + Safety

> **Note:** Version differences between configurations are intentional to maintain compatibility with each framework's ecosystem.

### Running Linters

**Django Stack:**
```bash
# Format code
black src tests app

# Lint code
flake8 src tests app

# Type checking
mypy src
```

**FastAPI Stack:**
```bash
# Format code
black src tests

# Lint code
ruff check src tests

# Type checking
mypy src

# Security scan
bandit -r src
```

### Testing

**Test Commands:**

```bash
# Run all tests
make test

# Run unit tests only
pytest tests/unit -v

# Run integration tests
pytest tests/integration -v

# Run with coverage
pytest --cov=src --cov=app --cov-report=html
```

**Coverage Requirements:** Minimum 80% coverage

### Docker Development

```bash
# Start development environment
make dev-up
# Or:
docker compose -f docker-compose.base.yml -f docker-compose.dev.yml up -d

# Run tests in Docker
docker compose -f docker-compose.base.yml -f docker-compose.test.yml run --rm app pytest

# View logs
docker compose logs -f web
```

---

## Database Design

### Key Models

| Model | Purpose | Primary Key |
|-------|---------|-------------|
| `User` | User accounts | UUID |
| `Role` | RBAC roles | UUID |
| `Permission` | RBAC permissions | UUID |
| `AuditLog` | Activity audit trail | UUID |
| `SystemConfiguration` | Runtime settings | UUID |

### Relationships

- `Users` ↔ `Roles`: Many-to-Many via `user_roles`
- `Roles` ↔ `Permissions`: Many-to-Many via `role_permissions`
- All tables use UUID primary keys for security

### Database Conventions

1. Always use UUID primary keys
2. Use JSONB for flexible metadata storage
3. Include `created_at`, `updated_at`, `created_by`, `updated_by` audit fields
4. Use proper indexing for performance
5. Follow PostgreSQL naming conventions (snake_case)

---

## Security Best Practices

### Required for All Code Changes

1. **Input Validation:** Validate all user inputs
2. **Output Encoding:** Prevent XSS with proper encoding
3. **SQL Injection Prevention:** Always use ORM or parameterized queries
4. **Sensitive Data Handling:** Never log passwords, tokens, or secrets
5. **CSRF Protection:** Use Django's CSRF middleware
6. **Authentication:** Check user authentication before actions
7. **Authorization:** Use RBAC decorators for permission checks

### Sensitive Fields to Redact

```python
sensitive_fields = {
    'password', 'password_hash', 'token', 'secret', 'key',
    'authorization', 'cookie', 'session', 'csrf_token'
}
```

### Security Scanning Tools

- **Bandit:** Python AST security scanner
- **Safety:** Dependency vulnerability scanner
- **Trivy:** Container vulnerability scanner

---

## CI/CD Pipeline

### Pipeline Stages

1. **Code Quality:** Linting, formatting, type checking
2. **Security Scanning:** Bandit, Safety, dependency audit
3. **Testing:** Unit, integration, E2E tests
4. **Build:** Multi-stage Docker builds
5. **Deploy:** Environment-specific deployment via Ansible

### Deployment Environments

| Environment | Branch Trigger | Approval |
|-------------|----------------|----------|
| Development | `develop` | Auto |
| Staging | `main` | Auto |
| Production | `release/*` | Manual |

### Blue-Green Deployment

The system uses blue-green deployment for zero-downtime updates:

1. Deploy to inactive environment
2. Health check verification
3. Switch load balancer
4. Monitor and verify
5. Keep previous environment for rollback

---

## Common Tasks

### Adding a New Permission

```python
from app.core.rbac import rbac_manager

# Create permission
permission_id = rbac_manager.create_permission(
    name='resource.action',
    resource='resource',
    action='action',
    description='Permission description',
    created_by=admin_user_id
)
```

### Adding a New Role

```python
role_id = rbac_manager.create_role(
    name='role_name',
    description='Role description',
    permissions=['permission.read', 'permission.write'],
    created_by=admin_user_id
)
```

### Logging User Activity

```python
from app.core.audit import audit_logger, log_user_activity

# Using log_user_activity helper
log_user_activity(
    action='ACTION_NAME',
    user_id=user_id,
    resource_type='ResourceType',
    resource_id=resource_id,
    message='Description of what happened'
)

# Using audit_logger directly
audit_logger.log_activity(
    action='ACTION_NAME',
    user_id=user_id,
    resource_type='ResourceType',
    resource_id=resource_id,
    message='Description of what happened'
)
```

### Adding Environment Configuration

1. Add to `.env.example`:
   ```bash
   NEW_SETTING=default_value
   ```

2. Add to `config/settings/base.py`:
   ```python
   NEW_SETTING = os.environ.get('NEW_SETTING', 'default_value')
   ```

3. Add validation if required in `ConfigurationValidator`

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
docker compose ps db

# Check connection
docker compose exec db psql -U postgres -d django_app -c "SELECT 1"
```

### Cache Issues

**Django Stack (Memcached):**
```bash
# Check Memcached is running
docker compose ps memcached

# Restart Memcached
docker compose restart memcached
```

**FastAPI Stack (Redis):**
```bash
# Check Redis is running
docker compose ps redis

# Check Redis connectivity
docker compose exec redis redis-cli ping
```

### Test Failures

```bash
# Run tests with verbose output
pytest tests/ -v --tb=long

# Run specific test
pytest tests/unit/test_rbac.py -v

# Debug mode
pytest tests/ -v --pdb
```

---

## Quick Reference Commands

```bash
# Development
make dev-up          # Start dev environment
make dev-down        # Stop dev environment
make test            # Run all tests
make lint            # Run linters
make format          # Format code

# Docker
docker compose build # Rebuild containers
docker compose logs  # View logs
docker compose exec web bash  # Shell into container

# Database (Django Stack)
python manage.py migrate        # Run migrations
python manage.py makemigrations # Create migrations

# Database (FastAPI Stack)
alembic upgrade head           # Run migrations
alembic revision --autogenerate -m "Description"  # Create migrations

# Deploy
make deploy ENVIRONMENT=staging
ansible-playbook -i ansible/inventories/prod/hosts.yml ansible/playbooks/deploy.yml
```

---

## Notes for AI Agents

1. **Always check RBAC permissions** when implementing user-facing features
2. **Log important activities** using the audit system
3. **Validate inputs** and sanitize outputs
4. **Follow existing patterns** - check similar implementations in the codebase
5. **Run tests** before committing changes
6. **Use type hints** for all new Python code
7. **Update documentation** when making significant changes
8. **Security-first approach** - consider security implications of all changes
