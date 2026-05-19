import axios from 'axios';

const API_BASE_URL = 'http://localhost:5000'; // Flask backend address

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add a request interceptor for tokens if needed later
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

export const getTrips = () => api.get('/admin/trips_data'); // I need to create this JSON endpoint
export const getStats = () => api.get('/admin/stats_data'); // I need to create this JSON endpoint
export const login = (email, password) => api.post('/company/login', { email, password });

export default api;
