# Houston Heat 

Houston Heat is a civic-minded mobile app designed to help Houston residents navigate the growing dangers of extreme heat through safe, efficient, and informed decision making. Its goal is to empower heat-sensitive individuals such as the elderly, children, residents in under-resourced neighborhoods, and those with health issues to navigate the city safely and comfortably.

## Features

### Heat Map
- Full-resolution heat map overlay showing temperature variations across Houston
- Click anywhere to see localized "feels like" temperature and heat score (0-10)

### Weather Homepage
- Current temperature and "feels like" readings, Hourly and 7-day forecast
- AI-generated weather summary

### Cooling Centers
- Real-time list of open cooling centers in Houston
- Automatically filtered by current time and day of week, sorted by distance 

### AI Chatbot
- Ask questions about weather, heat safety, and local resources
- Context-aware responses using current weather data

### Resources
- Heat safety tips and information
- Links to external resources

## Setup

### Prerequisites
- Flutter SDK (3.0+)
- Dart SDK
- iOS Simulator / Android Emulator / Physical device
- Python 3.8+ 

### Installation

1. Clone the repository:
```bash
git clone https://github.com/alexcai13/houstonheat.git
cd houstonheat
```

2. Install Flutter dependencies:
```bash
flutter pub get
```

3. **Set up environment variables:**
   
   Get your API keys from:
   - **Google Weather API** - [Get API key](https://developers.google.com/maps/documentation/weather)
   - **Groq AI API** - [Get API key](https://console.groq.com/)
   - **Mapbox** - [Get access token](https://account.mapbox.com/)

4. Run the app:
```bash
flutter run
```
---
