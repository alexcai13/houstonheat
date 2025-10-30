# Weather API Proxy

Simple Express server that proxies Google Weather API requests to keep the API key secure.

## Deploy to Render (Free)

1. Go to [render.com](https://render.com) and sign up
2. Click "New +" → "Web Service"
3. Connect your GitHub repo `alexcai13/houstonheat`
4. Configure:
   - **Name**: `houstonheat-weather-proxy`
   - **Root Directory**: `backend`
   - **Environment**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Plan**: Free
5. Add environment variable:
   - Key: `GOOGLE_WEATHER_API_KEY`
   - Value: Your actual Google Weather API key
6. Click "Create Web Service"

After deployment, Render will give you a URL like:
`https://houstonheat-weather-proxy.onrender.com`

## Update Your HTML Files

Replace the weather API URL in your HTML files:

```javascript
// Old (direct API call)
const url = `https://weather.googleapis.com/v1/currentConditions:lookup?location.latitude=${lat}&location.longitude=${lon}&key=${apiKey}`;

// New (proxy call)
const url = `https://houstonheat-weather-proxy.onrender.com/api/weather?lat=${lat}&lon=${lon}`;
```

## Test Locally

```bash
cd backend
npm install
echo "GOOGLE_WEATHER_API_KEY=your_key_here" > .env
npm start
```

Test: `http://localhost:3000/api/weather?lat=29.7604&lon=-95.3698`

## Alternative Deployment Options

- **Railway**: [railway.app](https://railway.app) - Similar to Render
- **Fly.io**: [fly.io](https://fly.io) - Free tier available
- **Cyclic**: [cyclic.sh](https://cyclic.sh) - Easy GitHub integration
