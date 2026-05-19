/**
 * load-sql.js
 *
 * Parses queries.sql and hydrates sql-commands.json at server startup.
 *
 */

import { readFileSync } from 'fs';
import { resolve } from 'path';

import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
    
const __dirname = dirname(fileURLToPath(import.meta.url));

const SQL_FILE  = resolve(__dirname, 'sql/queries.sql');
const JSON_FILE = resolve(__dirname, 'sql-commands.json');

// Parse queries.sql
function parseSqlFile(filepath) {
    const content = readFileSync(filepath, 'utf8');
    const map = {};
    // Split on lines that look like '-- @key'
    const sections = content.split(/^-- @(\S+)\s*$/m);
    for (let i = 1; i < sections.length; i += 2) {
        const key  = sections[i].trim();
        const body = (sections[i + 1] ?? '').trim();
        map[key] = body;
    }
    return map;
}

// Recursively replace every '@key' string in obj using sqlMap
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

export default function loadSqlCommands() {
    const sqlMap = parseSqlFile(SQL_FILE);
    const raw = JSON.parse(readFileSync(JSON_FILE, 'utf8'));
    return hydrate(raw, sqlMap);
};
