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
    
const DIRNAME = dirname(fileURLToPath(import.meta.url));
const SQL_FILE  = resolve(DIRNAME, 'sql/queries.sql');
const JSON_FILE = resolve(DIRNAME, 'sql-commands.json');

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

export default function loadSqlCommands() {
    const sqlMap = parseSqlFile(SQL_FILE);
    const raw = JSON.parse(readFileSync(JSON_FILE, 'utf8'));
    return { ...raw, sqlMap };
};
