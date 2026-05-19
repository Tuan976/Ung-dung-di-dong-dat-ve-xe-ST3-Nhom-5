import React, { useState, useEffect, useRef } from 'react';
import { MessageSquare, X, Maximize2, Minimize2, Send, Loader2, Bot } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useNavigate } from 'react-router-dom';

const Chatbot = () => {
  const navigate = useNavigate();
  const [isOpen, setIsOpen] = useState(false);
  const [isMaximized, setIsMaximized] = useState(false);
  const [messages, setMessages] = useState([
    { 
      role: 'ai', 
      content: 'Xin chào! 👋 Tôi là trợ lý đặt vé của HUTECH BUS. Bạn có thể nhắn rất ngắn như:\n• 🚍 "sg dl mai 2v"\n• 🗺️ "tphcm đi hà hội"\n• 🎫 "cho tôi xem vé của tôi"' 
    }
  ]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const messagesEndRef = useRef(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const handleSend = async () => {
    if (!input.trim()) return;
    
    const userMsg = input.trim();
    setMessages(prev => [...prev, { role: 'user', content: userMsg }]);
    setInput('');
    setIsLoading(true);

    try {
      const res = await fetch('/api/ai/chatbot', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: userMsg, history: messages.slice(-10) })
      });
      const data = await res.json();
      setMessages(prev => [...prev, { role: 'ai', content: data.response || 'Xin lỗi, tôi chưa xử lý được yêu cầu này.' }]);
      
      if (data.action?.type === 'open_booking' && data.action.trip_id) {
        navigate(`/search?trip_id=${data.action.trip_id}`);
        setIsOpen(false);
      }
    } catch (err) {
      setMessages(prev => [...prev, { role: 'ai', content: 'Lỗi kết nối. Vui lòng thử lại sau!' }]);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="fixed bottom-4 right-4 md:bottom-8 md:right-8 z-[1000]">
      {/* Toggle Button */}
      <button 
        onClick={() => setIsOpen(!isOpen)}
        className="w-14 h-14 bg-[#EF5222] text-white rounded-full shadow-2xl flex items-center justify-center hover:scale-110 transition-transform"
      >
        {isOpen ? <X size={24} /> : <Bot size={28} />}
      </button>

      {/* Chat Window */}
      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0, y: 20, scale: 0.95 }}
            animate={{ 
              opacity: 1, 
              y: 0, 
              scale: 1,
              width: isMaximized ? 'calc(100vw - 40px)' : 'min(380px, calc(100vw - 32px))',
              height: isMaximized ? 'calc(100vh - 40px)' : 'min(540px, calc(100vh - 120px))',
              bottom: isMaximized ? '20px' : '72px',
              right: isMaximized ? '20px' : '0px'
            }}
            exit={{ opacity: 0, y: 20, scale: 0.95 }}
            className="fixed bg-white rounded-[2rem] shadow-2xl border border-slate-100 flex flex-col overflow-hidden z-[1001]"
          >
            {/* Header */}
            <div className="p-5 bg-gradient-to-r from-[#EF5222] to-[#FF8E53] text-white flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-white/20 rounded-full flex items-center justify-center">
                  <MessageSquare size={20} />
                </div>
                <div>
                  <div className="font-black text-sm uppercase tracking-tight">Trợ lý Hutech</div>
                  <div className="text-[10px] font-bold opacity-80 flex items-center gap-1">
                    <span className="w-1.5 h-1.5 bg-green-400 rounded-full"></span> Trực tuyến 24/7
                  </div>
                </div>
              </div>
              <div className="flex items-center gap-1">
                <button 
                  onClick={() => setIsMaximized(!isMaximized)}
                  className="p-2 hover:bg-white/10 rounded-lg transition-colors"
                >
                  {isMaximized ? <Minimize2 size={16} /> : <Maximize2 size={16} />}
                </button>
                <button 
                  onClick={() => setIsOpen(false)}
                  className="p-2 hover:bg-white/10 rounded-lg transition-colors"
                >
                  <X size={18} />
                </button>
              </div>
            </div>

            {/* Messages */}
            <div className="flex-1 overflow-y-auto p-5 space-y-4 bg-slate-50">
              {messages.map((msg, idx) => (
                <div key={idx} className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
                  <div className={`max-w-[85%] p-4 text-sm font-medium leading-relaxed ${
                    msg.role === 'user' 
                      ? 'bg-[#EF5222] text-white rounded-2xl rounded-tr-none shadow-lg shadow-orange-100' 
                      : 'bg-white text-slate-800 rounded-2xl rounded-tl-none card-shadow'
                  }`}>
                    {msg.content}
                  </div>
                </div>
              ))}
              {isLoading && (
                <div className="flex justify-start italic text-xs text-slate-400 gap-2 items-center">
                  <Loader2 size={14} className="animate-spin" /> Hutech đang trả lời...
                </div>
              )}
              <div ref={messagesEndRef} />
            </div>

            {/* Input */}
            <div className="p-4 bg-white border-t border-slate-100 flex gap-2">
              <input 
                type="text" 
                value={input}
                onChange={(e) => setInput(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && handleSend()}
                placeholder="Nhắn tin cho trợ lý..." 
                className="flex-1 bg-slate-100 border-none rounded-2xl px-5 py-3 text-sm focus:ring-2 focus:ring-orange-500/20 outline-none transition-all"
              />
              <button 
                onClick={handleSend}
                disabled={!input.trim() || isLoading}
                className="w-11 h-11 bg-[#EF5222] text-white rounded-full flex items-center justify-center hover:bg-[#D43D11] transition-all disabled:opacity-50 shadow-lg shadow-orange-100"
              >
                <Send size={18} />
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
};

export default Chatbot;
