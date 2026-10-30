/* Sample data shaped like the planned MySQL tables.
   In the backend step, js/api.js will fetch these from the server instead. */

const DB = {
  stops: [
    // id, English, Tamil, lat, lng, verified?, confirmations
    { id: 1,  en: "Broadway",              ta: "பிராட்வே",             lat: 13.0900, lng: 80.2860, verified: 1, conf: 9 },
    { id: 2,  en: "Chennai Central",       ta: "சென்னை சென்ட்ரல்",     lat: 13.0827, lng: 80.2755, verified: 1, conf: 12 },
    { id: 3,  en: "Anna Salai",            ta: "அண்ணா சாலை",          lat: 13.0620, lng: 80.2680, verified: 1, conf: 7 },
    { id: 4,  en: "T. Nagar",              ta: "தி. நகர்",             lat: 13.0418, lng: 80.2341, verified: 1, conf: 10 },
    { id: 5,  en: "Guindy",                ta: "கிண்டி",               lat: 13.0067, lng: 80.2206, verified: 1, conf: 11 },
    { id: 6,  en: "Chromepet",             ta: "குரோம்பேட்டை",         lat: 12.9516, lng: 80.1462, verified: 1, conf: 8 },
    { id: 7,  en: "Tambaram",              ta: "தாம்பரம்",             lat: 12.9249, lng: 80.1000, verified: 1, conf: 14 },
    { id: 8,  en: "Perungalathur",         ta: "பெருங்களத்தூர்",       lat: 12.9034, lng: 80.0905, verified: 1, conf: 6 },
    { id: 9,  en: "Vandalur",              ta: "வண்டலூர்",             lat: 12.8918, lng: 80.0810, verified: 1, conf: 7 },
    { id: 10, en: "Guduvanchery",          ta: "கூடுவாஞ்சேரி",         lat: 12.8452, lng: 80.0605, verified: 1, conf: 6 },
    { id: 11, en: "Potheri",               ta: "பொத்தேரி",             lat: 12.8230, lng: 80.0450, verified: 1, conf: 5 },
    { id: 12, en: "SRM University",        ta: "எஸ்.ஆர்.எம். பல்கலை",   lat: 12.8230, lng: 80.0444, verified: 0, conf: 2 },
    { id: 13, en: "Maraimalai Nagar",      ta: "மறைமலை நகர்",          lat: 12.7940, lng: 80.0250, verified: 1, conf: 8 },
    { id: 14, en: "Chengalpattu",          ta: "செங்கல்பட்டு",         lat: 12.6819, lng: 79.9888, verified: 1, conf: 13 },
    { id: 15, en: "Koyambedu (CMBT)",      ta: "கோயம்பேடு (சி.எம்.பி.டி)", lat: 13.0694, lng: 80.1948, verified: 1, conf: 12 },
    { id: 16, en: "Vadapalani",            ta: "வடபழனி",               lat: 13.0500, lng: 80.2121, verified: 1, conf: 6 },
  ],

  // stops[] = [stop_id, minutes from origin], in sequence (RouteStops junction table)
  routes: [
    { id: 1, no: "21G",  color: "#14213d", name: "Broadway – Tambaram",
      stops: [[1,0],[2,8],[3,20],[4,38],[5,52],[6,78],[7,90]], firstDep: "05:00", freq: 15, lastDep: "22:00", diverted: 0 },
    { id: 2, no: "M70",  color: "#2563eb", name: "Tambaram – Chengalpattu (via SRM)",
      stops: [[7,0],[8,12],[9,22],[10,38],[11,50],[12,53],[13,65],[14,85]], firstDep: "04:45", freq: 10, lastDep: "23:00", diverted: 0 },
    { id: 3, no: "119",  color: "#1f9d5b", name: "Koyambedu – Chengalpattu",
      stops: [[15,0],[16,12],[5,28],[7,58],[9,72],[10,86],[11,96],[13,108],[14,125]], firstDep: "05:15", freq: 20, lastDep: "21:30", diverted: 1 },
    { id: 4, no: "51B",  color: "#e08a1e", name: "T. Nagar – Guduvanchery",
      stops: [[4,0],[5,14],[6,40],[7,52],[8,64],[9,74],[10,90]], firstDep: "05:30", freq: 12, lastDep: "21:45", diverted: 0 },
    { id: 5, no: "T51",  color: "#8b5cf6", name: "Guindy – SRM University",
      stops: [[5,0],[6,26],[7,38],[9,58],[10,74],[11,86],[12,89]], firstDep: "06:00", freq: 30, lastDep: "20:30", diverted: 0 },
  ],

  // Each route's fare per stage, per passenger category (fare rules table)
  fareRules: { baseFare: 5, perStage: 2, deluxeExtra: 5, categories: { general: 1, student: 0.5, senior: 0.5, woman: 0 } },

  buses: [
    { id: "TN01-N-2101", routeId: 1, progress: 0.32, crowd: 61 },
    { id: "TN01-N-2102", routeId: 1, progress: 0.78, crowd: 24 },
    { id: "TN21-N-7010", routeId: 2, progress: 0.20, crowd: 88 },
    { id: "TN21-N-7011", routeId: 2, progress: 0.62, crowd: 45 },
    { id: "TN21-N-1190", routeId: 3, progress: 0.45, crowd: 30 },
    { id: "TN01-N-5151", routeId: 4, progress: 0.55, crowd: 72 },
    { id: "TN21-N-0510", routeId: 5, progress: 0.40, crowd: 38 },
  ],

  // Passenger reports (DelayReports / CrowdReports / StopCorrections)
  reports: [
    { routeId: 2, type: "delay", minutes: 8,  userTrust: 80, ago: 6 },
    { routeId: 2, type: "delay", minutes: 12, userTrust: 60, ago: 14 },
    { routeId: 3, type: "delay", minutes: 20, userTrust: 90, ago: 9 },
    { routeId: 3, type: "delay", minutes: 15, userTrust: 55, ago: 22 },
    { routeId: 1, type: "delay", minutes: 4,  userTrust: 70, ago: 11 },
    { routeId: 4, type: "delay", minutes: 6,  userTrust: 50, ago: 30 },
    { routeId: 5, type: "delay", minutes: 2,  userTrust: 65, ago: 18 },
  ],

  diversions: [
    { routeId: 3, note_en: "Diverted via Vadapalani flyover due to road work. Expect +10 min.",
                  note_ta: "சாலைப் பணி காரணமாக வடபழனி மேம்பாலம் வழியாகத் திருப்பப்பட்டுள்ளது. +10 நிமிடம்." },
  ],

  // Stop-correction suggestions awaiting community votes (verified at 3 confirmations)
  pendingCorrections: [
    { stopId: 12, note: "Stop is at SRM Main Gate, not Potheri junction", votes: 2, needed: 3 },
  ],
};

// UI text, Tamil + English
const I18N = {
  en: {
    tagline: "Community-verified TN bus finder", navFind: "Find Bus", navLive: "Live Map", navReport: "Report",
    navInsights: "Insights", trust: "Trust", from: "From", to: "To", routeNo: "Route no. (e.g. 21G)",
    search: "Search", searchRoutes: "Search routes, stops…", noResult: "No buses found. Try different stops or a route number.",
    startHint: "Enter a source and destination, or a route number, to find buses.",
    stops: "stops", eta: "ETA", fare: "Fare", crowd: "Crowd", delay: "Delay", onTime: "On time",
    low: "Low", medium: "Medium", high: "Crowded", verified: "Verified", unverified: "Needs verification",
    confirm: "Confirm location", back: "← Back to results", diversion: "Diversion", every: "Every", min: "min",
    firstLast: "First / last bus", category: "Passenger", general: "General", student: "Student", senior: "Senior", woman: "Woman",
    stopList: "Stops on this route", activeBuses: "active", full: "full",
    reportTitle: "Submit a passenger report", reportSub: "Your report helps other passengers. Trusted users carry more weight.",
    reportType: "What are you reporting?", rDelay: "Bus delay", rCrowd: "Crowd level", rStop: "Wrong stop info", rDiv: "Route diversion",
    route: "Route", stop: "Stop", minutesLate: "Minutes late", crowdLevel: "Crowd level", details: "Details (optional)",
    submit: "Submit report", thanks: "Report submitted. Thank you!", pickRoute: "Select a route",
    insightsTitle: "Insights", insightsSub: "Aggregated from official data and recent passenger reports.",
    avgDelay: "Avg delay", reports: "Reports", routeRanking: "Route ranking (by reliability)", rank: "Rank",
    weighted: "Trust-weighted delay", anomaly: "Anomaly", normal: "Normal", unusual: "Unusually delayed",
    pending: "Pending stop corrections", votes: "votes", kpiBuses: "Active buses", kpiRoutes: "Routes", kpiStops: "Stops",
    kpiVerified: "Verified stops", kpiReports: "Recent reports",
  },
  ta: {
    tagline: "சமூகம் சரிபார்த்த தமிழக பேருந்து தேடல்", navFind: "பேருந்து தேடு", navLive: "நேரடி வரைபடம்", navReport: "புகார்",
    navInsights: "புள்ளிவிவரம்", trust: "நம்பகத்தன்மை", from: "புறப்படும் இடம்", to: "சேரும் இடம்", routeNo: "வழித்தட எண் (எ.கா. 21G)",
    search: "தேடு", searchRoutes: "வழித்தடம், நிறுத்தம் தேடு…", noResult: "பேருந்துகள் இல்லை. வேறு நிறுத்தம் அல்லது எண்ணை முயற்சிக்கவும்.",
    startHint: "பேருந்துகளைக் கண்டறிய இடங்களை அல்லது வழித்தட எண்ணை உள்ளிடவும்.",
    stops: "நிறுத்தங்கள்", eta: "வரும் நேரம்", fare: "கட்டணம்", crowd: "கூட்டம்", delay: "தாமதம்", onTime: "சரியான நேரம்",
    low: "குறைவு", medium: "மிதம்", high: "அதிகம்", verified: "சரிபார்க்கப்பட்டது", unverified: "சரிபார்க்க வேண்டும்",
    confirm: "இடத்தை உறுதிசெய்", back: "← முடிவுகளுக்குத் திரும்பு", diversion: "வழி மாற்றம்", every: "ஒவ்வொரு", min: "நிமிடம்",
    firstLast: "முதல் / கடைசி பேருந்து", category: "பயணி", general: "பொது", student: "மாணவர்", senior: "மூத்தவர்", woman: "பெண்",
    stopList: "இந்த வழித்தடத்தின் நிறுத்தங்கள்", activeBuses: "இயங்குகின்றன", full: "நிரம்பியது",
    reportTitle: "பயணி புகார் அளிக்கவும்", reportSub: "உங்கள் புகார் மற்ற பயணிகளுக்கு உதவும். நம்பகமான பயனர்களின் புகாருக்கு கூடுதல் மதிப்பு.",
    reportType: "எதைப் பற்றி புகார்?", rDelay: "பேருந்து தாமதம்", rCrowd: "கூட்ட நிலை", rStop: "தவறான நிறுத்தத் தகவல்", rDiv: "வழி மாற்றம்",
    route: "வழித்தடம்", stop: "நிறுத்தம்", minutesLate: "எத்தனை நிமிடம் தாமதம்", crowdLevel: "கூட்ட நிலை", details: "விவரங்கள் (விருப்பம்)",
    submit: "புகாரை சமர்ப்பி", thanks: "புகார் சமர்ப்பிக்கப்பட்டது. நன்றி!", pickRoute: "வழித்தடத்தைத் தேர்ந்தெடுக்கவும்",
    insightsTitle: "புள்ளிவிவரம்", insightsSub: "அதிகாரப்பூர்வ தரவு மற்றும் சமீபத்திய பயணி புகார்களிலிருந்து.",
    avgDelay: "சராசரி தாமதம்", reports: "புகார்கள்", routeRanking: "வழித்தட தரவரிசை (நம்பகத்தன்மை)", rank: "இடம்",
    weighted: "நம்பகத்தன்மை எடை தாமதம்", anomaly: "நிலை", normal: "இயல்பு", unusual: "அசாதாரண தாமதம்",
    pending: "நிலுவையிலுள்ள நிறுத்தத் திருத்தங்கள்", votes: "வாக்குகள்", kpiBuses: "இயங்கும் பேருந்துகள்", kpiRoutes: "வழித்தடங்கள்", kpiStops: "நிறுத்தங்கள்",
    kpiVerified: "சரிபார்த்த நிறுத்தங்கள்", kpiReports: "சமீபத்திய புகார்கள்",
  },
};
