import React, { useState, useEffect } from 'react';
import { 
  TrendingUp, Bus, Package, Users, Activity, Plus, 
  ArrowUpRight, ArrowDownRight, Clock, MapPin, 
  ChevronRight, Calendar, ExternalLink, RefreshCw
} from 'lucide-react';
import { motion } from 'framer-motion';
import { useNavigate } from 'react-router-dom';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler,
  ArcElement
} from 'chart.js';
import { Line, Doughnut } from 'react-chartjs-2';

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  ArcElement,
  Title,
  Tooltip,
  Legend,
  Filler
);

import StatCard from '../../components/StatCard';


const Dashboard = () => {
  const [stats, setStats] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    const fetchStats = () => {
      fetch('/api/admin/stats')
        .then(res => res.json())
        .then(data => {
          setStats(data);
          setIsLoading(false);
        })
        .catch(err => {
          console.error('Error fetching stats:', err);
          setIsLoading(false);
        });
    };
    fetchStats();
    const interval = setInterval(fetchStats, 60000); // Refresh every minute
    return () => clearInterval(interval);
  }, []);

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-[80vh]">
        <div className="flex flex-col items-center gap-4">
          <RefreshCw className="animate-spin text-orange-500" size={48} />
          <p className="text-slate-400 font-bold animate-pulse">Đang đồng bộ dữ liệu hệ thống...</p>
        </div>
      </div>
    );
  }

  const revenueChartData = {
    labels: stats?.trends?.labels || [],
    datasets: [
      {
        fill: true,
        label: 'Doanh thu vé',
        data: stats?.trends?.data || [],
        borderColor: '#EF5222',
        backgroundColor: 'rgba(239, 82, 34, 0.05)',
        tension: 0.4,
        borderWidth: 3,
        pointRadius: 4,
        pointBackgroundColor: '#fff',
        pointBorderWidth: 2,
      },
    ],
  };

  const bookingDistData = {
    labels: ['Xác nhận', 'Chờ xử lý', 'Đã hủy'],
    datasets: [
      {
        data: [
          stats?.booking_dist?.CONFIRMED || 0, 
          stats?.booking_dist?.HOLD || 0, 
          stats?.booking_dist?.CANCELLED || 0
        ],
        backgroundColor: ['#22c55e', '#f59e0b', '#ef4444'],
        borderWidth: 0,
        hoverOffset: 10,
      },
    ],
  };

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: false },
      tooltip: {
        backgroundColor: '#1e293b',
        padding: 12,
        titleFont: { size: 14, weight: 'bold' },
        bodyFont: { size: 13 },
        cornerRadius: 12,
        displayColors: false
      }
    },
    scales: {
      y: {
        beginAtZero: true,
        grid: { color: 'rgba(0,0,0,0.03)', drawBorder: false },
        ticks: { color: '#94a3b8', font: { size: 11, weight: 'bold' }, callback: (v) => `${(v/1000).toFixed(0)}k` }
      },
      x: {
        grid: { display: false },
        ticks: { color: '#94a3b8', font: { size: 11, weight: 'bold' } }
      }
    }
  };

  return (
    <div className="space-y-8 pb-12">
      {/* Header & Quick Actions */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <h1 className="text-3xl font-black text-slate-900 tracking-tight flex items-center gap-3">
            HUTECH BUS <span className="text-orange-500 text-sm font-bold bg-orange-50 px-3 py-1 rounded-full border border-orange-100">Live Dashboard</span>
          </h1>
          <p className="text-slate-500 mt-1 font-medium">Xin chào, đây là tổng quan vận hành của bạn hôm nay.</p>
        </div>
        <div className="flex gap-3">
          <button 
            onClick={() => navigate('/admin/trips')}
            className="bg-white text-slate-700 px-5 py-2.5 rounded-2xl font-bold flex items-center gap-2 border border-slate-200 hover:bg-slate-50 transition-all shadow-sm active:scale-95"
          >
            <Calendar size={18} /> Quản lý lịch
          </button>
          <button 
            onClick={() => navigate('/admin/trips')} // Assuming creation is in Trips
            className="bg-[#EF5222] text-white px-5 py-2.5 rounded-2xl font-bold flex items-center gap-2 hover:bg-[#D43D11] transition-all shadow-lg shadow-orange-200 active:scale-95"
          >
            <Plus size={20} /> Tạo chuyến mới
          </button>
        </div>
      </div>

      {/* Main Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
         <StatCard 
            label="Tổng Doanh thu" 
            value={`${(stats?.total_revenue || 0).toLocaleString('vi-VN')}đ`} 
            icon={TrendingUp} 
            color="bg-orange-500" 
            trend="up" 
            trendValue="12.5%" 
         />
         <StatCard 
            label="Chuyến đang chạy" 
            value={stats?.active_trips || 0} 
            icon={Bus} 
            color="bg-blue-600" 
         />
         <StatCard 
            label="Hàng hóa trong kho" 
            value={stats?.cargo_items || 0} 
            icon={Package} 
            color="bg-indigo-600" 
         />
         <StatCard 
            label="Tỷ lệ lấp đầy" 
            value={stats?.occupancy || '0%'} 
            icon={Activity} 
            color="bg-emerald-600" 
         />
      </div>

      {/* Charts Section */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2 glass rounded-[2.5rem] p-8 card-shadow border-none ring-1 ring-slate-100">
          <div className="flex justify-between items-center mb-8">
             <div>
               <h3 className="text-xl font-black text-slate-800">Biểu đồ doanh thu</h3>
               <p className="text-sm text-slate-400 font-medium">Dữ liệu 7 ngày gần nhất</p>
             </div>
             <div className="flex bg-slate-50 p-1 rounded-xl">
                <button className="px-4 py-1.5 rounded-lg text-xs font-bold bg-white text-orange-500 shadow-sm">Ngày</button>
                <button className="px-4 py-1.5 rounded-lg text-xs font-bold text-slate-400">Tháng</button>
             </div>
          </div>
          <div className="h-[300px] w-full">
            <Line data={revenueChartData} options={chartOptions} />
          </div>
        </div>

        <div className="glass rounded-[2.5rem] p-8 card-shadow border-none ring-1 ring-slate-100 flex flex-col">
          <h3 className="text-xl font-black text-slate-800 mb-2">Trạng thái vé</h3>
          <p className="text-sm text-slate-400 font-medium mb-8">Phân bổ trạng thái đặt chỗ</p>
          <div className="h-[200px] w-full flex justify-center relative">
            <Doughnut data={bookingDistData} options={{ 
              maintainAspectRatio: false, 
              plugins: { legend: { display: false } },
              cutout: '75%'
            }} />
            <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
               <span className="text-3xl font-black text-slate-800">
                {Object.values(stats?.booking_dist || {}).reduce((a, b) => a + b, 0)}
               </span>
               <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Tổng vé</span>
            </div>
          </div>
          <div className="mt-8 space-y-3">
             <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                   <div className="w-2.5 h-2.5 rounded-full bg-green-500" />
                   <span className="text-sm font-bold text-slate-600">Xác nhận</span>
                </div>
                <span className="text-sm font-black text-slate-800">{stats?.booking_dist?.CONFIRMED || 0}</span>
             </div>
             <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                   <div className="w-2.5 h-2.5 rounded-full bg-amber-500" />
                   <span className="text-sm font-bold text-slate-600">Chờ xử lý</span>
                </div>
                <span className="text-sm font-black text-slate-800">{stats?.booking_dist?.HOLD || 0}</span>
             </div>
             <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                   <div className="w-2.5 h-2.5 rounded-full bg-red-500" />
                   <span className="text-sm font-bold text-slate-600">Đã hủy</span>
                </div>
                <span className="text-sm font-black text-slate-800">{stats?.booking_dist?.CANCELLED || 0}</span>
             </div>
          </div>
        </div>
      </div>

      {/* Bottom Section: Activity & Top Routes */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        <div className="glass rounded-[2.5rem] p-8 card-shadow border-none ring-1 ring-slate-100">
          <div className="flex justify-between items-center mb-8">
             <h3 className="text-xl font-black text-slate-800">Hoạt động gần đây</h3>
             <button className="text-orange-500 text-xs font-bold hover:underline flex items-center gap-1">Xem tất cả <ExternalLink size={12} /></button>
          </div>
          <div className="space-y-6">
            {stats?.activities?.length > 0 ? stats.activities.map((act, i) => (
              <div key={i} className="flex gap-4 items-start group">
                <div className={`mt-1 p-2 rounded-xl ${act.type === 'booking' ? 'bg-blue-50 text-blue-500' : 'bg-orange-50 text-orange-500'} transition-transform group-hover:scale-110`}>
                  {act.type === 'booking' ? <Users size={16} /> : <Bus size={16} />}
                </div>
                <div className="flex-1">
                  <div className="flex justify-between">
                    <p className="text-sm font-black text-slate-800">{act.title}</p>
                    <p className="text-[10px] font-bold text-slate-400 flex items-center gap-1">
                      <Clock size={10} />
                      {new Date(act.time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                    </p>
                  </div>
                  <p className="text-xs text-slate-500 font-medium mt-0.5">{act.subtitle}</p>
                </div>
              </div>
            )) : (
              <div className="py-12 text-center text-slate-300 font-bold italic">Chưa có hoạt động mới</div>
            )}
          </div>
        </div>

        <div className="glass rounded-[2.5rem] p-8 card-shadow border-none ring-1 ring-slate-100">
          <h3 className="text-xl font-black text-slate-800 mb-8">Tuyến đường phổ biến</h3>
          <div className="space-y-4">
            {stats?.top_routes?.map((route, i) => (
              <div key={i} className="p-4 rounded-3xl bg-slate-50/50 hover:bg-white hover:shadow-md transition-all border border-transparent hover:border-slate-100 flex items-center justify-between group">
                <div className="flex items-center gap-4">
                   <div className="w-10 h-10 rounded-2xl bg-white shadow-sm flex items-center justify-center font-black text-slate-400 text-sm border border-slate-100">
                     0{i+1}
                   </div>
                   <div>
                     <p className="text-sm font-black text-slate-800 uppercase tracking-tight">{route.route}</p>
                     <p className="text-xs text-slate-400 font-medium">Bình quân {Math.round(route.bookings / 7)} vé/ngày</p>
                   </div>
                </div>
                <div className="text-right">
                   <p className="text-sm font-black text-slate-800">{route.bookings} vé</p>
                   <div className="flex items-center gap-1 text-[10px] font-bold text-green-500">
                      <TrendingUp size={10} /> Tăng trưởng
                   </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
