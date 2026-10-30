
const API_BASE = "http://127.0.0.1:8000";

async function apiGet(path) {
  const response = await fetch(`${API_BASE}${path}`);

  if (!response.ok) {
    throw new Error(`API error ${response.status}: ${path}`);
  }

  return response.json();
}

const BusAPI = {
  health: () => apiGet("/health"),
  getRoutes: () => apiGet("/api/routes"),
  getStops: () => apiGet("/api/stops"),
  getBuses: () => apiGet("/api/buses"),
  getInsights: () => apiGet("/api/insights"),
  getDiversions: () => apiGet("/api/diversions"),
};

window.BusAPI = BusAPI;

// Test the connection when this file loads.
BusAPI.health()
  .then(data => console.log("BusRoute+ backend connected:", data))
  .catch(error => console.error("Backend connection failed:", error));
