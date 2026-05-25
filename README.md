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
  - [Authentication and Sessions](#authentication-and-sessions)
  - [Role-Based Views](#role-based-views)
  - [SQL Command Registry](#sql-command-registry)
  - [Frontend Navigation](#frontend-navigation)
- [API Reference](#api-reference)
- [Security Notes](#security-notes)

---

## Architecture

```
Browser (Vue 3 SPA)
│  HTTP / JSON
▼
Express.js server  (server.js)
│  mssql
▼
MS SQL Server database
```

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

Web-App installation:

```bash
git clone <repo-url>
cd project
npm install
```

Run the `sql/DB_Setup.sql` in your MSSQL Server. Important: Replace the passwords of the demo logins!

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

---

## Running the App

```bash
node server.js
```

Then open `http://localhost:3000` in your browser.

---

## Project Structure

```
project/
├── server.js               # Express application & API routes
├── load-sql.js             # SQL loader: parses queries.sql and hydrates sql-commands.json
├── sql-commands.json       # UI metadata and query structure (@key references, no raw SQL)
├── migrate-sql.js          # One-time migration tool (see SQL Command Registry)
├── package.json
├── .env                    # Environment variables (not committed)
├── sql/
│   └── queries.sql         # All SQL query definitions, one -- @key section per query
└── frontend/
    ├── index.html          # Vue 3 SPA shell
    ├── style.css           # Design system & component styles
    ├── script.js           # Vue 3 application logic
    └── viewplaceholders.js # Shared view-substitution helper (used by both server and client)
```

---

## How It Works

### Authentication and Sessions

Login is performed by attempting to open a real SQL Server `ConnectionPool` with the supplied credentials. If the connection succeeds, the pool is stored in a server-side map keyed by `req.session.id`. No passwords are stored in the Node process.

Sessions expire after **1 hour** (configurable via `cookie.maxAge`).

### Role-Based Views

After login, the app fetches the user's database role from the dedicated `/api/auth/role` endpoint, which runs the role-detection query server-side.

The role (`system_admin`, `hotel_staff`, or `customer`) drives two things:

1. **Visible categories** — each category in `sql-commands.json` declares a `visibility` array.
2. **View substitution** — every SQL query uses placeholder table names like `[reservation]`. Before execution, the server replaces them with the correct view name (e.g. `view_reservation_customer` or `view_reservation_hotel_staff`) depending on `viewplaceholders` in `sql-commands.json`. The replacement logic lives in `frontend/viewplaceholders.js`, a shared ES module imported by both the server and the browser (the latter uses it for display only).

### SQL Command Registry

SQL queries are stored in `queries.sql` and loaded at server startup by `load-sql.js`. The `sql-commands.json` file holds only UI metadata and structure; every SQL string is replaced with a `@key` reference that the loader resolves back to the full query at boot time.

`queries.sql` uses `-- @key` section headers to delimit individual queries:

```sql
-- @system_management_system_overview_kpi_0
SELECT COUNT(*) AS number_of_customers
FROM view_customer_[customer];

-- @customer_management_get_customers_sql
SELECT cu.customer_ID, cu.firstName ...
FROM view_customer_[customer] cu
...
```

`sql-commands.json` references these with `@key` strings in place of raw SQL:

```json
{
  "id": "get_customers",
  "sql": "@customer_management_get_customers_sql",
  "insert": {
    "sql": "@customer_management_get_customers_insert"
  }
}
```

`load-sql.js` is required in `server.js` instead of the JSON directly:

```js
// server.js
const SQL_COMMANDS = loadSqlCommands();
// SQL_COMMANDS contains { categories, viewplaceholders, sqlMap }
// sqlMap is also sent to the frontend via /api/categories for SQL display purposes
```

The loader handles all four locations where SQL appears: `sql` (string or KPI array of `{title, sql}` objects), `insert.sql`, and `params[].options` for select-type inputs. It warns to the console if a `@key` reference has no matching section in `queries.sql`.

**Adding or editing a query** — edit the relevant `-- @key` section in `queries.sql` and restart the server. The JSON does not need to change unless the query's parameters or UI behaviour change.

**Adding a new command** — add a `-- @new_key` section to `queries.sql`, add the command object to `sql-commands.json` with `"sql": "@new_key"`, then restart.

### Frontend Navigation

The Vue app maintains a `navStack` array. Clicking a result row pushes the current state (commands list, query, param values) and replaces the sidebar with `subSql` entries. The **Back** button pops the stack and restores the previous state.

---

## API Reference

| Method | Path | Auth required | Description |
|---|---|---|---|
| `POST` | `/api/auth/login` | No | Open a DB connection with supplied credentials |
| `POST` | `/api/auth/logout` | No | Close the DB connection and destroy the session |
| `GET` | `/api/auth/status` | No | Return current session state |
| `GET`  | `/api/auth/role`     | Yes | Return the current user's database role 
| `POST` | `/api/sql/execute` | Yes | Execute a parameterised SQL query |
| `GET` | `/api/categories` | No | Return the full hydrated `sql-commands.json` payload |

**`POST /api/sql/execute` body:**

```json
{
  "queryKey": "@customer_management_get_customers_sql",
  "params": { "id": "CUS%" },
  "role": "customer"
}
```

The client sends only a `@key` reference — never raw SQL. The server resolves the key against `sqlMap` (built from `queries.sql` at startup), applies viewplaceholder substitution using `role` and the session username, then executes the parameterised query. All parameter values are bound as `NVARCHAR`. Ensure `queries.sql` is not user-editable in production.

---

## Security Notes

- **SQL injection** — all user-supplied values are bound as named parameters via `mssql`'s `request.input()`. The query *template* comes from `queries.sql`, loaded server-side at startup, not from user input.
- **Row-level security** — enforced through database views; the Node server only selects the correct view name, it does not filter rows itself.
- **Session secret** — must be set in `.env`; do not use the default placeholder in production.
- **`cookie.secure`** — set to `true` when running behind HTTPS in production.
- **Hardened sessions** — `saveUninitialized: false` and `resave: false` reduce session-fixation risk.