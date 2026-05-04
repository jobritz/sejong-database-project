const { createApp } = Vue;

createApp({
	data() {
		return {
			loggedIn: false,
			currentUser: '',
			currentRole: '',
			loginForm: { 
				username: '', 
				password: '' 
			},
			loginLoading: false,
			loginError: '',
			categories: [],
			currentCat: null,
			currentCmd: null,
			previousCmd: null,
			paramValues: {},
			subQueryMode: false,
			subQueryBase: false,
			navStack: [],
			queryResult: null,
			inserted: null,
			runLoading: false,
			selectValues: {},
			selectLabelDefaults: {},
			kpiResults: {},
			kpiLoading: false,
			autoSubSelect: false
		};
	},
	
	mounted() {
		this.checkLoginStatus();
		this.loadQueries();
	},
	
	computed: {
		visibleCategories() {
			return this.categories.filter(cat => cat.visibility.includes(this.currentRole));
		}
	},
	
	watch: {
		loggedIn(newValue) {
			if(newValue) {
				const cmd =	`SELECT DP1.name AS RoleName 
					FROM sys.database_role_members AS DRM 
					INNER JOIN sys.database_principals AS DP1 ON DRM.role_principal_id = DP1.principal_id 
					INNER JOIN sys.database_principals AS DP2 ON DRM.member_principal_id = DP2.principal_id 
					WHERE DP2.name = USER_NAME();`;
					fetch('/api/sql/execute', {
						method: 'POST',
						headers: { 'Content-Type': 'application/json' },
						body: JSON.stringify({ query: cmd, params: {} })
					})
						.then((res) => res.json())
						.then((data) => this.currentRole = String(Object.values(data.recordset[0])[0]))
						.catch((e) => console.error(e))
						.finally(() => {
							this.categories = this.categories.filter(cat => cat.visibility.includes(this.currentRole));
							this.autoSubSelect = true;
							this.selectCat(this.categories[0]);
							this.selectCmd(this.currentCat.commands[0]);
						});
			}
		}
	},
	
	methods: {
		loadQueries() {
			fetch('/api/categories', {
				method: 'GET',
				headers: { 'Content-Type': 'application/json' }
			})
				.then((res) => res.json())
				.then((data) => {
					if (Array.isArray(data)) this.categories = data;
				})
				.catch((e) => console.error(e));
		},
		
		checkLoginStatus() {
			fetch('/api/auth/status', {
				method: 'GET',
				headers: { 'Content-Type': 'application/json' }
			})
				.then((res) => res.json())
				.then((data) => {
					if (data.loggedIn) {
						this.loggedIn = true;
						this.currentUser = data.user.username;
					}
				})
				.catch((e) => console.error(e));
		},
		
		loginUser() {
			this.loginError = '';
			this.loginLoading = true;
			fetch('/api/auth/login', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ username: this.loginForm.username, password: this.loginForm.password })
			})
				.then((res) => res.json())
				.then((data) => {
					if (data.error) {
						this.loginError = data.error;
					} else if (data.user?.username) {
						this.loggedIn = true;
						this.currentUser = data.user.username;
					}
				})
				.catch((e) => (this.loginError = e))
				.finally(() => (this.loginLoading = false));
		},
		
		logoutUser() {
			fetch('/api/auth/logout', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' }
			})
				.catch((e) => console.error(e))
				.finally(() => {
					this.loggedIn = false;
					this.currentUser = '';
					this.currentRole = '';
					this.currentCat = null;
					this.currentCmd = null;
					this.queryResult = null;
					this.navStack = [];
				});
		},
		
		selectCat(cat) {
			this.loadQueries();
			this.subQueryBase = false;
			this.subQueryMode = false;
			this.navStack = [];
			this.currentCat = cat;
			this.currentCmd = null;
			this.queryResult = null;
		},
		
		selectCmd(cmd) {
			this.previousCmd = this.currentCmd;
			this.currentCmd = cmd;
			this.queryResult = null;
			if (!this.subQueryMode) {
				for (const key of Object.keys(this.paramValues)) {
					delete this.paramValues[key];
				}
				for (const key of Object.keys(this.selectValues)) {
					delete this.selectValues[key];
				}
				this.selectLabelDefaults = {};
				for (const p of cmd.params) this.paramValues[p.name] = '';
			}
			this.loadSelectOptions(cmd.params);
			if (cmd.insert) {
				this.loadSelectOptions(cmd.insert.params);
			}
			if (cmd.runOnSelect) {
				if (cmd.type === 'scalar') this.executeKpiQueries(cmd.sql);
				if (cmd.type === 'table') this.executeCommand(cmd.sql);
			}
		},
		
		loadSelectOptions(params) {
			const cleanParams = {};
			for (const [key, value] of Object.entries(this.paramValues)) {
				if (!Array.isArray(value)) cleanParams[key] = value;
			}
			for (const [key, value] of Object.entries(this.selectValues)) {
				cleanParams[key] = value;
			}
			
			for (const p of params) {
				if (p.type === 'select') {
					delete this.paramValues[p.name];
					fetch('/api/sql/execute', {
						method: 'POST',
						headers: { 'Content-Type': 'application/json' },
						body: JSON.stringify({ query: p.options, params: cleanParams })
					})
						.then((res) => res.json())
						.then((data) => {
							this.paramValues[p.name] = data.recordset;
							if (this.selectValues[p.name] !== undefined) return;
							for (const labelVal of Object.values(this.selectLabelDefaults)) {
								const match = data.recordset.find(
									(o) => String(Object.values(o)[1]) === String(labelVal)
								);
								if (match) {
									this.selectValues[p.name] = String(Object.values(match)[0]);
									return;
								}
							}

							if (data.recordset.length > 0) {
								this.selectValues[p.name] = String(Object.values(data.recordset[0])[0]);
							}
						})
						.catch((e) => console.error(e));
				}
			}
		},
		
		selectSubCmd(subSql, params) {
			if (!subSql) return;

			this.navStack.push({
				commands: [...this.currentCat.commands],
				cmd: this.currentCmd,
				paramValues: { ...this.paramValues },
				selectValues: { ...this.selectValues }
			});

			this.subQueryMode = true;
			this.currentCat.commands = subSql;
			this.currentCmd = subSql[0];
			this.selectLabelDefaults = {};
			
			for (const p of this.currentCmd.params) {
				if (p.type === 'select') delete this.selectValues[p.name];
			}
			if (this.currentCmd.insert) {
				for (const p of this.currentCmd.insert.params) {
					if (p.type === 'select') delete this.selectValues[p.name];
				}
			}

			for (let [key, value] of Object.entries(params)) {
				const p = this.currentCmd.params.find(p => p.name === key);
				if (p !== undefined) {
					if (p.type === 'number' && isNaN(value)) value = parseFloat(String(value).replace(/[^0-9.]/g, ''));
					if (p.type === 'select') {
						this.selectValues[key] = String(value);
					} else {
						this.paramValues[key] = value;
					}
				} else {
					this.selectLabelDefaults[key] = value;
					this.paramValues[key] = value;
				}		
			}
			for (const p of this.currentCmd.params) {
				if (!p.readonly && p.type !== 'select') {
					const sourceKey = p.name.replace(/^new([A-Z])/, (_, c) => c.toLowerCase());
					if (sourceKey !== p.name && params[sourceKey] !== undefined) {
						let val = params[sourceKey];
						if (p.type === 'number') val = parseFloat(String(val).replace(/[^0-9.]/g, ''));
						this.paramValues[p.name] = val;
					}
				}
			}
			this.selectCmd(this.currentCmd);
		},

		goBack() {
			if (this.navStack.length === 0) return;
			const prev = this.navStack.pop();
			this.currentCat.commands = prev.commands;
			this.paramValues = { ...prev.paramValues };
			this.selectValues = { ...prev.selectValues };
			this.subQueryMode = this.navStack.length > 0 || this.subQueryBase;
			this.queryResult = null;
			this.currentCmd = null;
			this.currentCmd = prev.cmd;

			if (prev.cmd.runOnSelect) {
				this.executeCommand(prev.cmd.sql);
			}
		},
		
		executeCommand(sql) {
			this.runLoading = true;
			this.queryResult = null;
			const mergedParams = {};
			for (const [key, value] of Object.entries(this.paramValues)) {
				if (!Array.isArray(value)) mergedParams[key] = value;
			}
			for (const [key, value] of Object.entries(this.selectValues)) {
				mergedParams[key] = value;
			}
			fetch('/api/sql/execute', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ query: sql, params: mergedParams })
			})
				.then((res) => res.json())
				.then((data) => {
					this.queryResult = data;
					if(this.autoSubSelect) {
						this.autoSubSelect = false;
						if (this.currentCmd.subSql && data.recordset?.length > 0) {
							this.selectSubCmd(this.currentCmd.subSql, data.recordset[0]);
							this.navStack = [];
							this.subQueryBase = true;
						}
					}
					if (this.currentCmd.insert) {
						if (this.currentCmd.runOnSelect && this.currentCmd.insert.sql === sql) {
							for (const p of this.currentCmd.insert.params) {
								if (!p.readonly) {
									this.paramValues[p.name] = '';
								}
							}
							this.selectCmd(this.currentCmd);
						}
					}
				})
				.catch((e) => console.error(e))
				.finally(() => (this.runLoading = false));
		},
		
		executeKpiQueries(sql) {
		    this.kpiResults = {};
		    const mergedParams = { ...this.paramValues, ...this.selectValues };

			for(const q of sql) {
				this.kpiLoading = true;
				fetch('/api/sql/execute', {
					method: 'POST',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({ query: q.sql, params: mergedParams })
				})
					.then(res => res.json())
					.then((data) => (this.kpiResults[q.title] = String(Object.values(data.recordset[0])[0])))
					.catch((e) => (this.kpiResults[q.title] = e))
					.finally(this.kpiLoading = false);
			}
		},

		highlightSql(sql) {
			const keywords = ['SELECT','FROM','WHERE','AND','OR','NOT','IN','LIKE','BETWEEN','IS','NULL','ORDER','BY','ASC','DESC','GROUP','HAVING','JOIN','INNER','LEFT','RIGHT','FULL','OUTER','ON','INSERT','INTO','VALUES','UPDATE','SET','DELETE','CREATE','TABLE','DROP','ALTER','ADD','IDENTITY','PRIMARY','KEY','DEFAULT','GETDATE','TOP','DISTINCT','AS','COUNT','SUM','AVG','MIN','MAX','IF','OBJECT_ID','WITH','CASE','WHEN','THEN','ELSE','END','CONCAT','COALESCE','EXCEPT','OVER','DENSE_RANK','ROW_NUMBER','STRING_AGG','YEAR'];
			let out = String(sql).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
			out = out.replace(/(@\w+)/g, '<span class="sql-param">$1</span>');
			out = out.replace(/'([^']*)'/g, "<span class='sql-str'>'$1'</span>");
			//out = out.replace(/(\[[\w\s]+\])/g, '<span style="color:#93c5fd">$1</span>');
			const kwRe = new RegExp(`\\b(${keywords.join('|')})\\b`, 'g');
			out = out.replace(kwRe, '<span class="sql-kw">$1</span>');
			return out;
		}
	},
}).mount('#app');