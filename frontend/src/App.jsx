import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';

// Layouts
import AdminLayout from './layout/AdminLayout';

// Components
import Navbar from './components/Navbar';
import ProtectedRoute from './components/ProtectedRoute';
import Chatbot from './components/Chatbot';

// Pages
import Home from './pages/Home';
import Auth from './pages/Auth';
import SearchResults from './pages/SearchResults';
import CheckTicket from './pages/CheckTicket';
import Policy from './pages/Policy';
import Profile from './pages/Profile';
import Footer from './components/Footer';

// Admin Pages
import AdminDashboard from './pages/admin/Dashboard';
import AdminTrips from './pages/admin/Trips';
import AdminBuses from './pages/admin/Buses';
import AdminRoutes from './pages/admin/Routes';
import AdminCargo from './pages/admin/Cargo';
import AdminOffices from './pages/admin/Offices';
import WarehouseSending from './pages/admin/WarehouseSending';
import AdminStaff from './pages/admin/Staff';
import Manifest from './pages/admin/Manifest';
import DriverTrips from './pages/admin/DriverTrips';

const App = () => {
  return (
    <Router>
      <div className="app-container">
        <Routes>
          <Route path="/" element={<div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh' }}><Navbar /><Home /><Footer /></div>} />
          <Route path="/auth" element={<div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh' }}><Navbar /><Auth /><Footer /></div>} />
          <Route path="/search" element={<div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh' }}><SearchResults /><Footer /></div>} />
          <Route path="/check-ticket" element={<CheckTicket />} />
          <Route path="/profile" element={<div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh' }}><Navbar /><Profile /><Footer /></div>} />
          <Route path="/thong-tin/:slug" element={<div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh' }}><Navbar /><Policy /><Footer /></div>} />
          <Route path="/admin" element={<AdminLayout><ProtectedRoute permission="DASHBOARD"><AdminDashboard /></ProtectedRoute></AdminLayout>} />
          <Route path="/admin/trips" element={<AdminLayout><ProtectedRoute permission="TRIPS"><AdminTrips /></ProtectedRoute></AdminLayout>} />
          <Route path="/admin/buses" element={<AdminLayout><ProtectedRoute permission="TRIPS"><AdminBuses /></ProtectedRoute></AdminLayout>} />
          <Route path="/admin/manifest/:tripId" element={<AdminLayout><ProtectedRoute permission="TRIPS"><Manifest /></ProtectedRoute></AdminLayout>} />
          <Route path="/admin/warehouse/sending" element={<AdminLayout><ProtectedRoute permission="WAREHOUSE"><WarehouseSending /></ProtectedRoute></AdminLayout>} />
          <Route path="/admin/cargo" element={<AdminLayout><ProtectedRoute permission="CARGO"><AdminCargo /></ProtectedRoute></AdminLayout>} />
          <Route path="/admin/offices" element={<AdminLayout><ProtectedRoute permission="OFFICES"><AdminOffices /></ProtectedRoute></AdminLayout>} />
          <Route path="/admin/staff" element={<AdminLayout><ProtectedRoute permission="STAFF"><AdminStaff /></ProtectedRoute></AdminLayout>} />
          <Route path="/admin/settings" element={<AdminLayout><ProtectedRoute permission="SETTINGS"><AdminRoutes /></ProtectedRoute></AdminLayout>} />
          <Route path="/driver" element={<DriverTrips />} />
        </Routes>
        <Chatbot />
      </div>
    </Router>
  );
};

export default App;
