/**
 * load-sql.js
 *
 * Parses queries.sql and hydrates sql-commands.json at server startup.
 *
 * queries.sql format:
 *   -- @some_key
 *   SELECT ...
 *
 *   -- @another_key
 *   UPDATE ...
 *
 * Usage in server.js:
 *   const SQL_COMMANDS = require('./load-sql')();
 */

const fs   = require('fs');
const path = require('path');

const SQL_FILE  = path.resolve(__dirname, 'queries.sql');
const JSON_FILE = path.resolve(__dirname, 'sql-commands.json');

/** Parse queries.sql → { key: sqlString } */
function parseSqlFile(filepath) {
    const content = fs.readFileSync(filepath, 'utf8');
    const map = {};
    // Split on lines that look like "-- @key"
    const sections = content.split(/^-- @(\S+)\s*$/m);
    // sections[0] = preamble (empty), then alternating: key, body, key, body ...
    for (let i = 1; i < sections.length; i += 2) {
        const key  = sections[i].trim();
        const body = (sections[i + 1] ?? '').trim();
        map[key] = body;
    }
    return map;
}

/** Recursively replace every "@key" string in obj using sqlMap. */
function hydrate(obj, sqlMap) {
    if (typeof obj === 'string') {
        if (obj.startsWith('@')) {
            const key = obj.slice(1);
            if (!(key in sqlMap)) {
                console.warn(`[load-sql] Missing key in queries.sql: "${key}"`);
                return obj;
            }
            return sqlMap[key];
        }
        return obj;
    }
    if (Array.isArray(obj)) return obj.map(item => hydrate(item, sqlMap));
    if (obj !== null && typeof obj === 'object') {
        const out = {};
        for (const [k, v] of Object.entries(obj)) out[k] = hydrate(v, sqlMap);
        return out;
    }
    return obj;
}

module.exports = function loadSqlCommands() {
    const sqlMap = parseSqlFile(SQL_FILE);
    const raw    = JSON.parse(fs.readFileSync(JSON_FILE, 'utf8'));
    return hydrate(raw, sqlMap);
};
