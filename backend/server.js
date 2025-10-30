const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors({
  origin: ['https://alexcai13.github.io', 'http://localhost:8000'],
  methods: ['GET']
}));

app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.get('/api/weather', async (req, res) => {
  const { lat, lon } = req.query;
  
  if (!lat || !lon) {
    return res.status(400).json({ error: 'Missing lat or lon parameter' });
  }

  const apiKey = process.env.GOOGLE_WEATHER_API_KEY;
  if (!apiKey) {
    console.error('GOOGLE_WEATHER_API_KEY not set');
    return res.status(500).json({ error: 'Server configuration error' });
  }

  const url = `https://weather.googleapis.com/v1/currentConditions:lookup?location.latitude=${lat}&location.longitude=${lon}&key=${apiKey}`;

  try {
    const response = await fetch(url);
    const data = await response.json();
    
    if (!response.ok) {
      console.error('Weather API error:', response.status, data);
      return res.status(response.status).json(data);
    }
    
    res.json(data);
  } catch (error) {
    console.error('Proxy error:', error);
    res.status(500).json({ error: 'Failed to fetch weather data' });
  }
});

app.listen(PORT, () => {
  console.log(`Weather proxy running on port ${PORT}`);
});
