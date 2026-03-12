////////////
// Config //
////////////

const sql = require('mssql');
const dotenv = require('@dotenvx/dotenvx');

dotenv.config();

const port = process.env.PORT;
const dbConfig = {
	server: process.env.DB_SERVER,
	user: process.env.DB_USER,
	password: process.env.DB_PASSWORD,
	options: {
		encrypt: false, // Set to true if using Azure SQL Database
	    trustServerCertificate: true // Use for self-signed certificates in local dev
	}
}

////////////
// Server //
////////////

//const express = require('express');
//const path = require('path');
//const helmet = require('helmet');

//const app = express();

//app.use(express.json());
//app.use(express.static(path.join(__dirname, 'frontend')));
//app.use(helmet());

//app.listen(port, () => console.log(`App available on http://localhost:${port}`));


async function connectToDatabase() {
    try {
        // Connect to the database
        await sql.connect(dbConfig);
        console.log('Connected to SQL Server successfully!');

        // Example query
        //const result = await sql.query`use database hotel`;
        //console.dir(result.recordset);

    } catch (err) {
        console.error('Database connection error:', err);
    } finally {
        // Close the connection when done
        await sql.close();
    }
}

connectToDatabase();