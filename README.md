# Hotel Booking System

A full-stack web application that provides a role-aware SQL interface for managing a hotel booking database. The backend exposes a secure REST API over an MS SQL Server connection; the frontend is a single-page Vue 3 app with dynamic query panels, drill-down navigation, and KPI dashboards.

---

## Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Running the App](#running-the-app)
- [Project Structure](#project-structure)
- [How It Works](#how-it-works)
  - [Authentication & Sessions](#authentication--sessions)
  - [Role-Based Views](#role-based-views)
  - [SQL Command Registry](#sql-command-registry)
  - [Frontend Navigation](#frontend-navigation)
- [API Reference](#api-reference)
- [Security Notes](#security-notes)

---

## Architecture

Browser (Vue 3 SPA)
│  HTTP / JSON
▼
Express.js server  (server.js)
│  mssql
▼
MS SQL Server database

The Express server acts as a proxy: it authenticates users against the database itself (SQL Server logins), holds one `ConnectionPool` per session, and forwards parameterised queries from the UI.

---

## Prerequisites

| Requirement | Version |
|---|---|
| Node.js | ≥ 18 |
| npm | ≥ 9 |
| MS SQL Server | 2016+ (requires `STRING_AGG`, window functions) |

---

## Installation

```bash
git clone <repo-url>
cd project
npm install
```

Dependencies used:

- `express` — HTTP server
- `mssql` — SQL Server client
- `express-session` — session middleware
- `@dotenvx/dotenvx` — environment variable loading

---

## Configuration

Create a `.env` file in the project root:

```env
PORT=3000

# SQL Server connection
DB_SERVER=localhost
DB_DATABASE=HotelBooking
DB_PORT=1433
DB_ENCRYPT=false
DB_TRUST_CERT=true

# Session
SESSION_SECRET=replace-with-a-long-random-string
```

> **Never commit `.env` to source control.**

---

## Running the App

```bash
node server.js
```

Then open `http://localhost:3000` in your browser.

---

## Project Structure

project/
├── server.js               # Express application & API routes
├── sql-commands.json       # All SQL query definitions and UI metadata
├── package.json
├── .env                    # Environment variables (not committed)
└── frontend/
	├── index.html          # Vue 3 SPA shell
	├── style.css           # Design system & component styles
	└── script.js           # Vue 3 application logic
	
---

## How It Works

### Authentication & Sessions

Login is performed by attempting to open a real SQL Server `ConnectionPool` with the supplied credentials. If the connection succeeds, the pool is stored in a server-side map keyed by `req.session.id`. No passwords are stored in the Node process.

Sessions expire after **1 hour** (configurable via `cookie.maxAge`).

### Role-Based Views

After login, the frontend queries the user's database roles:

```sql
SELECT DP1.name AS RoleName
FROM sys.database_role_members AS DRM
INNER JOIN sys.database_principals AS DP1 ON DRM.role_principal_id = DP1.principal_id
INNER JOIN sys.database_principals AS DP2 ON DRM.member_principal_id = DP2.principal_id
WHERE DP2.name = USER_NAME();
```

The role (`system_admin`, `hotel_staff`, or `customer`) drives two things:

1. **Visible categories** — each category in `sql-commands.json` declares a `visibility` array.
2. **View substitution** — every SQL query uses placeholder table names like `[reservation]`. Before execution, the client replaces them with the correct view name (e.g. `view_reservation_customer` or `view_reservation_hotel_staff`) depending on `viewplaceholders` in `sql-commands.json`. This enforces row-level security at the database view layer.

### SQL Command Registry

`sql-commands.json` contains the full definition of every available operation:

| Field | Purpose |
|---|---|
| `type` | `table` renders a result grid; `kpi` renders metric tiles; `void` shows only row-count feedback |
| `params` | List of input fields rendered in the UI |
| `runOnSelect` | If `true`, the query executes automatically when selected |
| `subSql` | Child queries unlocked by clicking a result row (drill-down) |
| `insert` | Optional secondary form for INSERT/EXEC operations shown below the result grid |

### Frontend Navigation

The Vue app maintains a `navStack` array. Clicking a result row pushes the current state (commands list, query, param values) and replaces the sidebar with `subSql` entries. The **Back** button pops the stack and restores the previous state.

---

## API Reference

| Method | Path | Auth required | Description |
|---|---|---|---|
| `POST` | `/api/auth/login` | No | Open a DB connection with supplied credentials |
| `POST` | `/api/auth/logout` | No | Close the DB connection and destroy the session |
| `GET` | `/api/auth/status` | No | Return current session state |
| `POST` | `/api/sql/execute` | Yes | Execute a parameterised SQL query |
| `GET` | `/api/categories` | No | Return the full `sql-commands.json` payload |

**`POST /api/sql/execute` body:**

```json
{
  "query": "SELECT * FROM view_customer_customer WHERE customer_ID LIKE @id",
  "params": { "id": "CUS%" }
}
```

All parameters are bound as `NVARCHAR` to prevent SQL injection. The query string itself is sent from the client-controlled `sql-commands.json`; ensure that file is not user-editable in production.

---

## Security Notes

- **SQL injection** — all user-supplied values are bound as named parameters via `mssql`'s `request.input()`. The query *template* comes from the server-side `sql-commands.json`, not from user input.
- **Row-level security** — enforced through database views; the Node server only selects the correct view name, it does not filter rows itself.
- **Session secret** — must be set in `.env`; do not use the default placeholder in production.
- **`cookie.secure`** — set to `true` when running behind HTTPS in production.
- **Hardened sessions** — `saveUninitialized: false` and `resave: false` reduce session-fixation risk.