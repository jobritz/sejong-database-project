# Hotel booking system

An interactive Node.js web application for demonstrating and executing SQL commands about hotel booking against a Microsoft SQL Server.

---

## Features


---

## Quick Start

### 1. Install dependencies

```bash
cd sql-demo-app
npm install
```

### 2. Start the server

```bash
npm start
# or for development with auto-reload:
npm run dev
```

### 3. Open in browser

```
http://localhost:3000
```

### 4. Log in

Enter your MSSQL login credentials:
- **Username**: your SQL Server login (SQL Authentication)
- **Password**: your SQL Server password

> **Note**: Windows Authentication is not supported — SQL Authentication must be enabled on the server.

---

## API Endpoints

| Method | Route | Description |
|--------|-------|-------------|
| `POST` | `/api/auth/login` | Connect to MSSQL with credentials |
| `POST` | `/api/auth/logout` | Close connection and end session |
| `GET`  | `/api/auth/status` | Check current session status |
| `GET`  | `/api/categories` | Get all SQL categories and commands |
| `POST` | `/api/sql/execute` | Execute a SQL query with parameters |

## Adding New Commands


### Parameter substitution rules


