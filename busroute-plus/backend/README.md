# BusRoute+ FastAPI backend

This backend powers the BusRoute+ / Chennai Bus Radar frontend using FastAPI and SQLAlchemy. It uses SQLite by default so it runs locally without a database server. The data model is structured so you can migrate to MySQL or Oracle later.

## 1. Create and activate a virtual environment

Windows PowerShell:
```powershell
py -m venv .venv
.venv\Scripts\Activate.ps1
```

If PowerShell blocks activation:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.venv\Scripts\Activate.ps1
```

## 2. Install packages and run

```powershell
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Open:
- API health: http://127.0.0.1:8000/health
- Interactive docs: http://127.0.0.1:8000/docs
- Stops: http://127.0.0.1:8000/api/stops
- Routes: http://127.0.0.1:8000/api/routes
- Insights: http://127.0.0.1:8000/api/insights

A `busroute.db` SQLite database is created automatically and seeded with demo stops, routes, buses, reports, one diversion and fare rules.

## API endpoints

| Method | Endpoint | Use |
|---|---|---|
| GET | `/health` | Check backend |
| GET | `/api/stops` | Tamil/English stops and coordinates |
| GET | `/api/routes` | All routes with stop sequences and buses |
| GET | `/api/routes/search?from=Guindy&to=Tambaram` | Search routes |
| GET | `/api/routes/{route_id}` | Route detail and ordered stops |
| GET | `/api/buses` | Demo bus positions/progress |
| GET | `/api/fares?hops=4&category=student` | Fare calculator |
| POST | `/api/reports` | Save delay/crowd/stop/diversion report |
| POST | `/api/stops/{stop_id}/confirm` | Confirm a stop |
| GET | `/api/insights` | Reliability ranking, anomaly and KPI data |
| GET | `/api/diversions` | Active diversions |
| POST | `/api/users` | Create a demo user profile |
| GET | `/api/users/{user_id}` | Read user trust score |

## Frontend integration

The current `js/app.js` uses a local in-memory `DB` object. This backend will not automatically change that frontend. Replace the API methods in `js/app.js` with `fetch()` calls, or add a separate `js/api.js` client. The response shapes for `/api/stops` and `/api/routes` deliberately resemble the existing JavaScript data objects.

Example:
```js
const response = await fetch("http://127.0.0.1:8000/api/routes");
const routes = await response.json();
```

## Important security note

This is a development backend. `/api/users` creates a profile only; it does **not** authenticate passwords. Do not use it as a production login system. Before public deployment, add password hashing, login/token authentication, request rate limiting, ownership checks, stricter CORS settings and report anti-abuse validation. Demo bus positions are simulated by the frontend, not live GPS.
