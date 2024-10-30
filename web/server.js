const express = require('express');
const path = require('path');
const dotenv = require('dotenv');
dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;

// Serve static files from the 'web' directory
app.use(express.static(path.join(__dirname, 'web')));

// Base route to serve index.html
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'web', 'index.html'));
});

// Health check route
app.get('/health', (req, res) => {
    res.status(200).json({ status: 'Server is up and running!' });
});

// Start server
app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
