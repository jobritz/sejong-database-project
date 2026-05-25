export function replaceViewplaceholders(sql, viewplaceholders, currentRole, currentUser) {
    if (!viewplaceholders || Object.keys(viewplaceholders).length === 0 || currentRole === '') return sql;
    for (const v of (viewplaceholders[currentRole] ?? [])) {
        const regex = new RegExp(String.raw`\[${v.tablename}\]`, 'g');
        if (v.base === 'user') sql = sql.replace(regex, currentUser);
        if (v.base === 'role') sql = sql.replace(regex, currentRole);
    }
    return sql;
}