/**
 * server.js
 *
 * Setup and API endpoints of the express.js server
 *
 */

import { config as _config } from '@dotenvx/dotenvx';
_config();

import express, { json, static as _static } from 'express';
import favicon from 'serve-favicon';
import pkg from 'mssql';
const { ConnectionPool, NVarChar } = pkg;
import session from 'express-session';
import { join } from 'path';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
const __dirname = dirname(fileURLToPath(import.meta.url));
import loadSqlCommands from './load-sql.js';
import { replaceViewplaceholders } from './frontend/viewplaceholders.js';

const app = express();

const PORT = process.env.PORT;
const SQL_COMMANDS = loadSqlCommands();

// App setup
app.use(json());
app.use(_static(join(__dirname, 'frontend')));
app.use(favicon(join(__dirname, 'frontend', 'favicon.ico'))); 
app.use(
	session({
		secret: process.env.SESSION_SECRET,
		resave: false,
		saveUninitialized: false,
		cookie: {
			secure: false,
			maxAge: 1000 * 60 * 60
		},
	})
);

// Active Connections
const connections = {};

function getConfig(body) {
	return {
		user: body.username,
		password: body.password,
		server: process.env.DB_SERVER,
		database: process.env.DB_DATABASE,
		port: parseInt(process.env.DB_PORT),
		options: {
			encrypt: JSON.parse(process.env.DB_ENCRYPT),
			trustServerCertificate: JSON.parse(process.env.DB_TRUST_CERT),
			enableArithAbort: true,
		},
		connectionTimeout: 10000,
		requestTimeout: 30000,
	};
}

// Login
app.post('/api/auth/login', async (req, res) => {
	const { username, password } = req.body;
	if (!username || !password) {
		return res.status(400).json({ error: 'Username and password are required.' });
	}
	try {
		const config = getConfig(req.body);
		const pool = new ConnectionPool(config);
		await pool.connect();

		if (connections[req.session.id]) {
			try { await connections[req.session.id].close(); } catch (_) {}
		}
		connections[req.session.id] = pool;
		req.session.user = {
			username: config.user,
			server: config.server,
			database: config.database
		};

		res.json({
			success: true,
			user: {
				username: config.user,
				server: config.server,
				database: config.database
			},
		});
	} catch (err) {
		res.status(401).json({ error: `Connection failed: ${err.message}` });
	}
});

// Get current DB role
app.get('/api/auth/role', requireAuth, async (req, res) => {
    const sql = SQL_COMMANDS.sqlMap['get_current_role'];
    const pool = connections[req.session.id];
    try {
        const result = await pool.request().query(sql);
        res.json({ role: String(Object.values(result.recordset[0])[0]) });
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

// Logout
app.post('/api/auth/logout', async (req, res) => {
	if (connections[req.session.id]) {
		try { await connections[req.session.id].close(); } catch (_) {}
		delete connections[req.session.id];
	}
	req.session.destroy();
	res.json({ success: true });
});

// Authentication status
app.get('/api/auth/status', (req, res) => {
	if (req.session.user && connections[req.session.id]) {
		res.json({ loggedIn: true, user: req.session.user });
	} else {
		res.json({ loggedIn: false });
	}
});

// Authentication guard 
function requireAuth(req, res, next) {
	if (!req.session.user || !connections[req.session.id]) {
		return res.status(401).json({ error: 'Not authenticated. Please log in first.' });
	}
	next();
}

// SQL Execute Endpoint
app.post('/api/sql/execute', requireAuth, async (req, res) => {
	const { queryKey, params = {}, role = '' } = req.body;
	if (!queryKey) return res.status(400).json({ error: 'No queryKey provided.' });
	const key = queryKey.startsWith('@') ? queryKey.slice(1) : queryKey;
	let query = SQL_COMMANDS.sqlMap[key];
	if (!query) return res.status(400).json({ error: `Unknown query key: "${key}"` });
	query = replaceViewplaceholders(query, SQL_COMMANDS.viewplaceholders, role, req.session.user.username);
	
	const pool = connections[req.session.id];
	try {
		const request = pool.request();

		for (const [key, value] of Object.entries(params)) {
			if (value === null || value === undefined) continue;
			request.input(key, NVarChar, String(value));
		}

		const startTime = Date.now();
		const result = await request.query(query);
		const elapsed = Date.now() - startTime;

		res.json({
			success: true,
			recordset: result.recordset || [],
			rowsAffected: result.rowsAffected,
			columns: result.recordset?.length > 0 ? Object.keys(result.recordset[0]) : [],
			elapsed,
		});
	} catch (err) {
		res.status(400).json({ error: err.message, code: err.number });
	}
});

// Load SQL commands
app.get('/api/categories', (req, res) => {
	res.json(SQL_COMMANDS);
});

// Start Server
app.listen(PORT, () => {
	console.log(`Hotel Booking System running at http://localhost:${PORT}\n`);
});