const { createApp } = Vue;

createApp({
	data() {
		return {
			loggedIn: false,
			currentUser: '',
			currentRole: '',
			loginForm: { username: '', password: '' },
			loginLoading: false,
			loginError: '',
			viewplaceholders: {},
			categories: [],
			currentCat: null,
			currentQuery: null,
			paramValues: {},
			selectValues: {},
			selectLabelDefaults: {},
			navStack: [],
			inSubQuery: false,
			subBase: false,
			autoSelect: false,
			queryResult: null,
			runLoading: false,
			kpiResults: {},
			kpiLoading: false,
		};
	},

	mounted() {
		this.loadQueries();
		this.checkLoginStatus();
	},

	computed: {
		visibleCategories() {
			return this.categories.filter(cat => cat.visibility.includes(this.currentRole));
		},
		mergedParams() {
			const result = {};
			for (const [k, v] of Object.entries(this.paramValues))
				if (!Array.isArray(v)) result[k] = v;
			return { ...result, ...this.selectValues };
		}
	},

	watch: {
		loggedIn(val) {
			if (!val) return;
			
			const sql =`SELECT DP1.name AS RoleName 
				FROM sys.database_role_members AS DRM 
				INNER JOIN sys.database_principals AS DP1 ON DRM.role_principal_id = DP1.principal_id 
				INNER JOIN sys.database_principals AS DP2 ON DRM.member_principal_id = DP2.principal_id 
				WHERE DP2.name = USER_NAME();`
			this.executeSql(sql, {})
				.then(data => {
					this.currentRole = String(Object.values(data.recordset[0])[0]);
					this.selectCategory(this.visibleCategories[0]);
					this.autoSelect = this.currentRole !== 'system_admin';
					this.selectQuery(this.currentCat.commands[0]);
				})
				.catch(e => console.error(e));
		}
	},

	methods: {
		loadQueries() {
			fetch('/api/categories', { headers: { 'Content-Type': 'application/json' } })
				.then(res => res.json())
				.then(data => {
					this.viewplaceholders = data.viewplaceholders ? data.viewplaceholders : {};
					if (Array.isArray(data.categories)) this.categories = data.categories; 
				})
				.catch(e => console.error(e));
		},

		checkLoginStatus() {
			fetch('/api/auth/status', { headers: { 'Content-Type': 'application/json' } })
				.then(res => res.json())
				.then(data => {
					if (data.loggedIn) {
						this.loggedIn = true;
						this.currentUser = data.user.username;
					}
				})
				.catch(e => console.error(e));
		},

		loginUser() {
			this.loginError = '';
			this.loginLoading = true;
			fetch('/api/auth/login', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify(this.loginForm)
			})
				.then(res => res.json())
				.then(data => {
					if (data.error) this.loginError = data.error;
					else if (data.user?.username) {
						this.loggedIn = true;
						this.currentUser = data.user.username;
					}
				})
				.catch(e => (this.loginError = e))
				.finally(() => (this.loginLoading = false));
		},

		logoutUser() {
			fetch('/api/auth/logout', { method: 'POST', headers: { 'Content-Type': 'application/json' } })
				.catch(e => console.error(e))
				.finally(() => {
					this.loggedIn = false;
					this.currentUser = '';
					this.currentRole = '';
					this.currentCat = null;
					this.currentQuery = null;
					this.queryResult = null;
					this.navStack = [];
					this.paramValues = {};
					this.selectValues = {};
					this.selectLabelDefaults = {};
					this.inSubQuery = false;
					this.subBase = false;
					this.autoSelect = false;
					this.kpiResults = {};
				});
		},

		selectCategory(cat) {
			if (this.navStack.length > 0) {
				this.currentCat.commands = this.navStack[0].commands;
			}
			this.currentCat = cat;
			this.currentQuery = null;
			this.queryResult = null;
			this.navStack = [];
			this.paramValues = {};
			this.selectValues = {};
			this.selectLabelDefaults = {};
			this.inSubQuery = false;
			this.subBase = false;
			this.autoSelect = false;
			if(cat.commands?.length > 0) this.selectQuery(this.currentCat.commands[0]);
		},

		selectQuery(query) {
			this.currentQuery = query;
			this.queryResult = null;
			for(const p of query.params) {
				if(!this.inSubQuery || this.paramValues[p.name] === undefined) {
					if(!p.required) {
						this.paramValues[p.name] = '';
					}
					if(!this.inSubQuery) {
						this.selectValues = {};
						this.selectLabelDefaults = {};
					}
				}
			}
			this.loadSelectOptions(query.params);
			if (query.insert) this.loadSelectOptions(query.insert.params);
			if (query.runOnSelect) {
				if (query.type === 'kpi') this.runKpiQueries(query);
				else if (query.type === 'table') this.runQuery(query);
			}
		},

		loadSelectOptions(params) {
			for (const p of params) {
				if (p.type !== 'select') continue;
				delete this.paramValues[p.name];
				this.executeSql(p.options, this.mergedParams)
					.then(data => {
						this.paramValues[p.name] = data.recordset;
						if (this.selectValues[p.name] !== undefined) return;
						const match = data.recordset.find(o =>
							Object.values(this.selectLabelDefaults).includes(String(Object.values(o)[1]))
						);
						this.selectValues[p.name] = match
							? String(Object.values(match)[0])
							: data.recordset.length > 0 ? String(Object.values(data.recordset[0])[0]) : '';
					})
					.catch(e => console.error(e));
			}
		},

		drillDown(subQueries, params) {
			if (!subQueries?.length) return;
			this.navStack.push({
				commands: [...this.currentCat.commands],
				query: this.currentQuery,
				paramValues: { ...this.paramValues },
				selectValues: { ...this.selectValues }
			});
			this.inSubQuery = true;
			this.currentCat.commands = subQueries;
			this.currentQuery = subQueries[0];
			this.selectLabelDefaults = {};

			const allParams = [...this.currentQuery.params, ...(this.currentQuery.insert?.params ?? [])];
			for (const p of allParams)
				if (p.type === 'select') delete this.selectValues[p.name];

			for (let [key, value] of Object.entries(params)) {
				const p = this.currentQuery.params.find(p => p.name === key);
				if (p) {
					if (p.type === 'number') value = parseFloat(String(value).replace(/[^0-9.]/g, ''));
					p.type === 'select' ? (this.selectValues[key] = String(value)) : (this.paramValues[key] = value);
				} else {
					this.selectLabelDefaults[key] = value;
					this.paramValues[key] = value;
				}
			}

			for (const p of this.currentQuery.params) {
				if (p.readonly || p.type === 'select') continue;
				const src = p.name.replace(/^new([A-Z])/, (_, c) => c.toLowerCase());
				if (src !== p.name && params[src] !== undefined) {
					let val = params[src];
					if (p.type === 'number') val = parseFloat(String(val).replace(/[^0-9.]/g, ''));
					this.paramValues[p.name] = val;
				}
			}

			this.selectQuery(this.currentQuery);
		},

		goBack() {
			if (!this.navStack.length) return;
			const prev = this.navStack.pop();
			this.currentCat.commands = prev.commands;
			this.paramValues = { ...prev.paramValues };
			this.selectValues = { ...prev.selectValues };
			this.queryResult = null;
			this.currentQuery = prev.query;
			this.inSubQuery = this.navStack.length > 0 || this.subBase;
			if (prev.query.runOnSelect) this.runQuery(prev.query);
		},

		runQuery(query) {
			this.runLoading = true;
			this.queryResult = null;
			this.executeSql(query.sql, this.mergedParams)
				.then(data => {
					this.queryResult = data;
					if (this.autoSelect) {
						this.autoSelect = false;
						if (this.currentQuery.subSql && data.recordset?.length > 0) {
							this.drillDown(this.currentQuery.subSql, data.recordset[0]);
							this.navStack = [];
							this.subBase = true;
						}
					}
					if (query.insert?.sql === query.sql && this.currentQuery.runOnSelect) {
						for (const p of this.currentQuery.insert.params)
							if (!p.readonly) this.paramValues[p.name] = '';
						this.selectQuery(this.currentQuery);
					}
				})
				.catch(e => console.error(e))
				.finally(() => (this.runLoading = false));
		},
		
		runKpiQueries(queries) {
			this.kpiResults = {};
			for (const q of queries.sql) {
				this.kpiLoading = true;
				this.executeSql(q.sql, this.mergedParams)
					.then(data => (this.kpiResults[q.title] = String(Object.values(data.recordset[0])[0])))
					.catch(e => (this.kpiResults[q.title] = String(e)))
					.finally(() => (this.kpiLoading = false));
			}	
		},
		
		async executeSql(sql, params) {
			sql = this.replaceViewplaceholders(sql);
			return fetch('/api/sql/execute', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ query: sql, params: params })
			}).then(res => res.json());
		},
		
		replaceViewplaceholders(sql) {
			if(Object.keys(this.viewplaceholders).length > 0 && this.currentRole !== '') {		
				for (const v of this.viewplaceholders[this.currentRole]) {
					let regex = new RegExp(String.raw`\[${v.tablename}\]`, 'g');
					if (v.base === 'user') sql = sql.replace(regex, this.currentUser);
					if (v.base === 'role') sql = sql.replace(regex, this.currentRole);
				}
			}
			return sql;
		},

		highlightSql(query) {
			const keywords = ['SELECT','FROM','WHERE','AND','OR','NOT','IN','LIKE','BETWEEN','IS','NULL','ORDER','BY','ASC','DESC','GROUP','HAVING','JOIN','INNER','LEFT','RIGHT','FULL','OUTER','ON','INSERT','INTO','VALUES','UPDATE','SET','DELETE','CREATE','TABLE','DROP','ALTER','ADD','IDENTITY','PRIMARY','KEY','DEFAULT','GETDATE','TOP','DISTINCT','AS','COUNT','SUM','AVG','MIN','MAX','IF','OBJECT_ID','WITH','CASE','WHEN','THEN','ELSE','END','CONCAT','COALESCE','EXCEPT','OVER','DENSE_RANK','ROW_NUMBER','STRING_AGG','YEAR', 'EXEC'];
			let out = String(query.sql).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
			out = out.replace(/(@\w+)/g, '<span class="sql-param">$1</span>');
			out = out.replace(/'([^']*)'/g, "<span class='sql-str'>'$1'</span>");
			out = this.replaceViewplaceholders(out);
			out = out.replace(new RegExp(`\\b(${keywords.join('|')})\\b`, 'g'), '<span class="sql-kw">$1</span>');
			return out;
		}
	}
}).mount('#app');