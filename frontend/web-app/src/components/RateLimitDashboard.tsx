import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell, BarChart, Bar, Legend } from 'recharts';

interface RateLimitData {
    ip_requests: number;
    user_requests: number;
    endpoint_requests: { [key: string]: number };
    blocked_requests: number;
    timestamp: string;
}

interface MetricCardProps {
    title: string;
    value: string | number;
    change: string;
    color: 'blue' | 'green' | 'red' | 'yellow';
    icon: React.ReactNode;
}

const MetricCard: React.FC<MetricCardProps> = ({ title, value, change, color, icon }) => {
    const colorClasses = {
        blue: 'bg-gradient-to-r from-blue-500 to-blue-600 text-white',
        green: 'bg-gradient-to-r from-green-500 to-green-600 text-white',
        red: 'bg-gradient-to-r from-red-500 to-red-600 text-white',
        yellow: 'bg-gradient-to-r from-yellow-500 to-yellow-600 text-white'
    };

    return (
        <motion.div
            whileHover={{ scale: 1.02, y: -4 }}
            className={`${colorClasses[color]} p-6 rounded-2xl shadow-lg backdrop-blur-sm border border-white/10`}
        >
            <div className="flex items-center justify-between">
                <div className="flex-1">
                    <p className="text-white/80 text-sm font-medium">{title}</p>
                    <p className="text-3xl font-bold mt-2">{value}</p>
                    <p className="text-white/70 text-xs mt-1">{change}</p>
                </div>
                <div className="text-white/80 ml-4">
                    {icon}
                </div>
            </div>
        </motion.div>
    );
};

const RateLimitDashboard: React.FC = () => {
    const [data, setData] = useState<RateLimitData[]>([]);
    const [loading, setLoading] = useState(true);
    const [currentMetrics, setCurrentMetrics] = useState({
        totalRequests: 0,
        blockedRequests: 0,
        successRate: 0,
        activeUsers: 0
    });

    const generateMockData = () => {
        const now = new Date();
        const mockData: RateLimitData[] = [];

        for (let i = 23; i >= 0; i--) {
            const timestamp = new Date(now.getTime() - i * 60 * 1000);
            mockData.push({
                ip_requests: Math.floor(Math.random() * 100) + 20,
                user_requests: Math.floor(Math.random() * 80) + 15,
                endpoint_requests: {
                    '/api/loads': Math.floor(Math.random() * 30) + 5,
                    '/api/carriers': Math.floor(Math.random() * 25) + 3,
                    '/api/matches': Math.floor(Math.random() * 20) + 2,
                    '/api/shipments': Math.floor(Math.random() * 15) + 1
                },
                blocked_requests: Math.floor(Math.random() * 5),
                timestamp: timestamp.toISOString()
            });
        }

        return mockData;
    };

    useEffect(() => {
        // Simulate API call
        const fetchData = async () => {
            setLoading(true);
            try {
                // In real app, this would be: await axios.get('/api/admin/rate_limits/status')
                await new Promise(resolve => setTimeout(resolve, 1000));
                const mockData = generateMockData();
                setData(mockData);

                // Calculate current metrics
                const latest = mockData[mockData.length - 1];
                const total = latest.ip_requests + latest.user_requests;
                setCurrentMetrics({
                    totalRequests: total,
                    blockedRequests: latest.blocked_requests,
                    successRate: Math.round(((total - latest.blocked_requests) / total) * 100),
                    activeUsers: Math.floor(Math.random() * 50) + 10
                });
            } catch (error) {
                console.error('Error fetching rate limit data:', error);
            } finally {
                setLoading(false);
            }
        };

        fetchData();
        const interval = setInterval(fetchData, 10000); // Update every 10 seconds
        return () => clearInterval(interval);
    }, []);

    const chartData = data.map(d => ({
        time: new Date(d.timestamp).toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit'
        }),
        requests: d.ip_requests + d.user_requests,
        blocked: d.blocked_requests,
        ip: d.ip_requests,
        user: d.user_requests
    }));

    const endpointData = data.length > 0 ?
        Object.entries(data[data.length - 1].endpoint_requests).map(([name, value]) => ({
            name: name.replace('/api/', ''),
            value,
            color: ['#3B82F6', '#10B981', '#F59E0B', '#EF4444'][Math.floor(Math.random() * 4)]
        })) : [];

    const pieData = [
        { name: 'Successful', value: currentMetrics.totalRequests - currentMetrics.blockedRequests, color: '#10B981' },
        { name: 'Blocked', value: currentMetrics.blockedRequests, color: '#EF4444' }
    ];

    if (loading) {
        return (
            <div className="p-8 flex items-center justify-center min-h-[600px]">
                <motion.div
                    animate={{ rotate: 360 }}
                    transition={{ duration: 2, repeat: Infinity, ease: "linear" }}
                    className="w-16 h-16 border-4 border-blue-500 border-t-transparent rounded-full"
                />
            </div>
        );
    }

    return (
        <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="p-8 space-y-8"
        >
            {/* Metrics Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <MetricCard
                    title="Total Requests"
                    value={currentMetrics.totalRequests.toLocaleString()}
                    change="+12% from last hour"
                    color="blue"
                    icon={
                        <svg className="w-8 h-8" fill="currentColor" viewBox="0 0 24 24">
                            <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
                        </svg>
                    }
                />
                <MetricCard
                    title="Blocked Requests"
                    value={currentMetrics.blockedRequests}
                    change={`${currentMetrics.blockedRequests > 5 ? '+' : ''}${Math.floor(Math.random() * 20 - 10)}% from last hour`}
                    color="red"
                    icon={
                        <svg className="w-8 h-8" fill="currentColor" viewBox="0 0 24 24">
                            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
                        </svg>
                    }
                />
                <MetricCard
                    title="Success Rate"
                    value={`${currentMetrics.successRate}%`}
                    change={`${currentMetrics.successRate > 95 ? 'Excellent' : 'Good'} performance`}
                    color="green"
                    icon={
                        <svg className="w-8 h-8" fill="currentColor" viewBox="0 0 24 24">
                            <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z" />
                        </svg>
                    }
                />
                <MetricCard
                    title="Active Users"
                    value={currentMetrics.activeUsers}
                    change="+5 new users today"
                    color="yellow"
                    icon={
                        <svg className="w-8 h-8" fill="currentColor" viewBox="0 0 24 24">
                            <path d="M16 7c0-2.76-2.24-5-5-5s-5 2.24-5 5 2.24 5 5 5 5-2.24 5-5zM12 14c-3.33 0-10 1.67-10 5v3h20v-3c0-3.33-6.67-5-10-5z" />
                        </svg>
                    }
                />
            </div>

            {/* Charts Row */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
                {/* Request Timeline */}
                <motion.div
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: 0.2 }}
                    className="bg-white rounded-2xl p-6 shadow-lg border border-gray-100"
                >
                    <h3 className="text-xl font-bold text-gray-800 mb-6 flex items-center">
                        <svg className="w-6 h-6 mr-3 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                        </svg>
                        Request Timeline (24h)
                    </h3>
                    <ResponsiveContainer width="100%" height={300}>
                        <LineChart data={chartData}>
                            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                            <XAxis dataKey="time" stroke="#666" fontSize={12} />
                            <YAxis stroke="#666" fontSize={12} />
                            <Tooltip
                                contentStyle={{
                                    backgroundColor: 'white',
                                    border: '1px solid #e0e0e0',
                                    borderRadius: '8px',
                                    boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)'
                                }}
                            />
                            <Legend />
                            <Line
                                type="monotone"
                                dataKey="requests"
                                stroke="#3B82F6"
                                strokeWidth={3}
                                dot={{ fill: '#3B82F6', strokeWidth: 2, r: 4 }}
                                activeDot={{ r: 6, stroke: '#3B82F6', strokeWidth: 2 }}
                                name="Total Requests"
                            />
                            <Line
                                type="monotone"
                                dataKey="blocked"
                                stroke="#EF4444"
                                strokeWidth={2}
                                dot={{ fill: '#EF4444', strokeWidth: 2, r: 3 }}
                                name="Blocked"
                            />
                        </LineChart>
                    </ResponsiveContainer>
                </motion.div>

                {/* Success Rate Pie Chart */}
                <motion.div
                    initial={{ opacity: 0, x: 20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: 0.3 }}
                    className="bg-white rounded-2xl p-6 shadow-lg border border-gray-100"
                >
                    <h3 className="text-xl font-bold text-gray-800 mb-6 flex items-center">
                        <svg className="w-6 h-6 mr-3 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                        Success vs Blocked Requests
                    </h3>
                    <ResponsiveContainer width="100%" height={300}>
                        <PieChart>
                            <Pie
                                data={pieData}
                                cx="50%"
                                cy="50%"
                                innerRadius={60}
                                outerRadius={100}
                                paddingAngle={5}
                                dataKey="value"
                            >
                                {pieData.map((entry, index) => (
                                    <Cell key={`cell-${index}`} fill={entry.color} />
                                ))}
                            </Pie>
                            <Tooltip
                                formatter={(value: number) => [value, 'Requests']}
                                contentStyle={{
                                    backgroundColor: 'white',
                                    border: '1px solid #e0e0e0',
                                    borderRadius: '8px',
                                    boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)'
                                }}
                            />
                            <Legend />
                        </PieChart>
                    </ResponsiveContainer>
                </motion.div>
            </div>

            {/* Endpoint Performance */}
            <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.4 }}
                className="bg-white rounded-2xl p-6 shadow-lg border border-gray-100"
            >
                <h3 className="text-xl font-bold text-gray-800 mb-6 flex items-center">
                    <svg className="w-6 h-6 mr-3 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
                    </svg>
                    Endpoint Performance
                </h3>
                <ResponsiveContainer width="100%" height={300}>
                    <BarChart data={endpointData}>
                        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                        <XAxis dataKey="name" stroke="#666" fontSize={12} />
                        <YAxis stroke="#666" fontSize={12} />
                        <Tooltip
                            formatter={(value: number) => [value, 'Requests']}
                            contentStyle={{
                                backgroundColor: 'white',
                                border: '1px solid #e0e0e0',
                                borderRadius: '8px',
                                boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)'
                            }}
                        />
                        <Bar
                            dataKey="value"
                            fill="#8884d8"
                            radius={[4, 4, 0, 0]}
                        />
                    </BarChart>
                </ResponsiveContainer>
            </motion.div>
        </motion.div>
    );
};

export default RateLimitDashboard;
