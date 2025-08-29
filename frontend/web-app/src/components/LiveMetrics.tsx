import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, ResponsiveContainer, ReferenceLine } from 'recharts';

interface MetricPoint {
    timestamp: number;
    requests: number;
    blocked: number;
    latency: number;
    errors: number;
}

interface SystemHealth {
    cpu: number;
    memory: number;
    redis: boolean;
    database: boolean;
    uptime: number;
}

interface Alert {
    id: string;
    type: 'warning' | 'error' | 'info';
    message: string;
    timestamp: Date;
}

const LiveMetrics: React.FC = () => {
    const [metrics, setMetrics] = useState<MetricPoint[]>([]);
    const [systemHealth, setSystemHealth] = useState<SystemHealth>({
        cpu: 0,
        memory: 0,
        redis: true,
        database: true,
        uptime: 0
    });
    const [alerts, setAlerts] = useState<Alert[]>([]);
    const [isConnected, setIsConnected] = useState(false);
    const [currentMetrics, setCurrentMetrics] = useState({
        requestsPerSecond: 0,
        avgLatency: 0,
        errorRate: 0,
        activeConnections: 0
    });

    const metricsBuffer = useRef<MetricPoint[]>([]);

    // Simulate WebSocket connection for real-time data
    useEffect(() => {
        // In a real app, this would be: new WebSocket('ws://localhost:3001/cable')
        const simulateWebSocket = () => {
            setIsConnected(true);

            const interval = setInterval(() => {
                const now = Date.now();
                const newMetric: MetricPoint = {
                    timestamp: now,
                    requests: Math.floor(Math.random() * 50) + 20,
                    blocked: Math.floor(Math.random() * 5),
                    latency: Math.floor(Math.random() * 200) + 50,
                    errors: Math.floor(Math.random() * 3)
                };

                // Update metrics buffer
                metricsBuffer.current = [...metricsBuffer.current.slice(-59), newMetric];
                setMetrics([...metricsBuffer.current]);

                // Update current metrics
                const recentMetrics = metricsBuffer.current.slice(-5);
                const avgRequests = recentMetrics.reduce((sum, m) => sum + m.requests, 0) / recentMetrics.length;
                const avgLatency = recentMetrics.reduce((sum, m) => sum + m.latency, 0) / recentMetrics.length;
                const totalErrors = recentMetrics.reduce((sum, m) => sum + m.errors, 0);
                const totalRequests = recentMetrics.reduce((sum, m) => sum + m.requests, 0);

                setCurrentMetrics({
                    requestsPerSecond: Math.round(avgRequests),
                    avgLatency: Math.round(avgLatency),
                    errorRate: totalRequests > 0 ? Math.round((totalErrors / totalRequests) * 100 * 100) / 100 : 0,
                    activeConnections: Math.floor(Math.random() * 100) + 50
                });

                // Update system health
                setSystemHealth(prev => ({
                    ...prev,
                    cpu: Math.min(100, Math.max(0, prev.cpu + (Math.random() - 0.5) * 10)),
                    memory: Math.min(100, Math.max(0, prev.memory + (Math.random() - 0.5) * 5)),
                    uptime: prev.uptime + 1
                }));

                // Generate alerts occasionally
                if (Math.random() < 0.1) { // 10% chance
                    const alertTypes: Array<{ type: Alert['type']; messages: string[] }> = [
                        {
                            type: 'warning',
                            messages: [
                                'High request rate detected on /api/loads endpoint',
                                'CPU usage approaching 80%',
                                'Rate limit threshold reached for user ID 12345'
                            ]
                        },
                        {
                            type: 'error',
                            messages: [
                                'Redis connection timeout',
                                'Database query exceeded 5s timeout',
                                'Critical: Rate limiter service unavailable'
                            ]
                        },
                        {
                            type: 'info',
                            messages: [
                                'New user registered: carrier@example.com',
                                'Rate limit configuration updated',
                                'System performance optimized'
                            ]
                        }
                    ];

                    const alertType = alertTypes[Math.floor(Math.random() * alertTypes.length)];
                    const message = alertType.messages[Math.floor(Math.random() * alertType.messages.length)];

                    const newAlert: Alert = {
                        id: `alert-${Date.now()}`,
                        type: alertType.type,
                        message,
                        timestamp: new Date()
                    };

                    setAlerts(prev => [newAlert, ...prev.slice(0, 9)]); // Keep last 10 alerts
                }
            }, 1000);

            return () => {
                clearInterval(interval);
                setIsConnected(false);
            };
        };

        const cleanup = simulateWebSocket();
        return cleanup;
    }, []);

    const formatUptime = (seconds: number) => {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = seconds % 60;
        return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    };

    const getAlertIcon = (type: Alert['type']) => {
        switch (type) {
            case 'error':
                return (
                    <svg className="w-5 h-5 text-red-500" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
                    </svg>
                );
            case 'warning':
                return (
                    <svg className="w-5 h-5 text-yellow-500" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z" />
                    </svg>
                );
            default:
                return (
                    <svg className="w-5 h-5 text-blue-500" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
                    </svg>
                );
        }
    };

    const getAlertBorderColor = (type: Alert['type']) => {
        switch (type) {
            case 'error': return 'border-l-red-500';
            case 'warning': return 'border-l-yellow-500';
            default: return 'border-l-blue-500';
        }
    };

    const chartData = metrics.map((point, index) => ({
        time: new Date(point.timestamp).toLocaleTimeString('en-US', {
            hour12: false,
            minute: '2-digit',
            second: '2-digit'
        }),
        requests: point.requests,
        blocked: point.blocked,
        latency: point.latency,
        errors: point.errors
    }));

    return (
        <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="p-8 space-y-8"
        >
            {/* Connection Status */}
            <div className="flex items-center justify-between bg-white rounded-2xl p-4 shadow-lg border border-gray-100">
                <div className="flex items-center space-x-3">
                    <motion.div
                        animate={{
                            backgroundColor: isConnected ? '#10B981' : '#EF4444',
                            scale: isConnected ? [1, 1.2, 1] : 1
                        }}
                        transition={{ duration: 0.5, repeat: isConnected ? Infinity : 0, repeatDelay: 1 }}
                        className="w-3 h-3 rounded-full"
                    />
                    <span className="font-medium text-gray-800">
                        {isConnected ? 'Connected to Live Stream' : 'Disconnected'}
                    </span>
                </div>
                <div className="text-sm text-gray-500">
                    Uptime: {formatUptime(systemHealth.uptime)}
                </div>
            </div>

            {/* Real-time Metrics Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <motion.div
                    key={currentMetrics.requestsPerSecond}
                    animate={{ scale: [1, 1.05, 1] }}
                    transition={{ duration: 0.3 }}
                    className="bg-gradient-to-r from-blue-500 to-blue-600 text-white p-6 rounded-2xl shadow-lg"
                >
                    <div className="flex items-center justify-between">
                        <div>
                            <p className="text-white/80 text-sm font-medium">Requests/sec</p>
                            <p className="text-3xl font-bold mt-2">{currentMetrics.requestsPerSecond}</p>
                        </div>
                        <svg className="w-8 h-8 text-white/80" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
                        </svg>
                    </div>
                </motion.div>

                <motion.div
                    key={currentMetrics.avgLatency}
                    animate={{ scale: [1, 1.05, 1] }}
                    transition={{ duration: 0.3, delay: 0.1 }}
                    className="bg-gradient-to-r from-green-500 to-green-600 text-white p-6 rounded-2xl shadow-lg"
                >
                    <div className="flex items-center justify-between">
                        <div>
                            <p className="text-white/80 text-sm font-medium">Avg Latency</p>
                            <p className="text-3xl font-bold mt-2">{currentMetrics.avgLatency}ms</p>
                        </div>
                        <svg className="w-8 h-8 text-white/80" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                    </div>
                </motion.div>

                <motion.div
                    key={currentMetrics.errorRate}
                    animate={{ scale: [1, 1.05, 1] }}
                    transition={{ duration: 0.3, delay: 0.2 }}
                    className="bg-gradient-to-r from-red-500 to-red-600 text-white p-6 rounded-2xl shadow-lg"
                >
                    <div className="flex items-center justify-between">
                        <div>
                            <p className="text-white/80 text-sm font-medium">Error Rate</p>
                            <p className="text-3xl font-bold mt-2">{currentMetrics.errorRate}%</p>
                        </div>
                        <svg className="w-8 h-8 text-white/80" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                        </svg>
                    </div>
                </motion.div>

                <motion.div
                    key={currentMetrics.activeConnections}
                    animate={{ scale: [1, 1.05, 1] }}
                    transition={{ duration: 0.3, delay: 0.3 }}
                    className="bg-gradient-to-r from-purple-500 to-purple-600 text-white p-6 rounded-2xl shadow-lg"
                >
                    <div className="flex items-center justify-between">
                        <div>
                            <p className="text-white/80 text-sm font-medium">Active Connections</p>
                            <p className="text-3xl font-bold mt-2">{currentMetrics.activeConnections}</p>
                        </div>
                        <svg className="w-8 h-8 text-white/80" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                        </svg>
                    </div>
                </motion.div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                {/* Real-time Chart */}
                <motion.div
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: 0.4 }}
                    className="lg:col-span-2 bg-white rounded-2xl p-6 shadow-lg border border-gray-100"
                >
                    <h3 className="text-xl font-bold text-gray-800 mb-6 flex items-center">
                        <svg className="w-6 h-6 mr-3 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                        </svg>
                        Real-time Performance
                    </h3>

                    <ResponsiveContainer width="100%" height={400}>
                        <LineChart data={chartData}>
                            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                            <XAxis
                                dataKey="time"
                                stroke="#666"
                                fontSize={12}
                                interval="preserveStartEnd"
                            />
                            <YAxis stroke="#666" fontSize={12} />
                            <Line
                                type="monotone"
                                dataKey="requests"
                                stroke="#3B82F6"
                                strokeWidth={2}
                                dot={false}
                                name="Requests"
                                isAnimationActive={false}
                            />
                            <Line
                                type="monotone"
                                dataKey="blocked"
                                stroke="#EF4444"
                                strokeWidth={2}
                                dot={false}
                                name="Blocked"
                                isAnimationActive={false}
                            />
                            <Line
                                type="monotone"
                                dataKey="latency"
                                stroke="#10B981"
                                strokeWidth={2}
                                dot={false}
                                name="Latency (ms)"
                                yAxisId="latency"
                                isAnimationActive={false}
                            />
                            {/* Rate limit threshold line */}
                            <ReferenceLine y={100} stroke="#F59E0B" strokeDasharray="5 5" label="Rate Limit" />
                        </LineChart>
                    </ResponsiveContainer>
                </motion.div>

                {/* System Health & Alerts */}
                <motion.div
                    initial={{ opacity: 0, x: 20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: 0.5 }}
                    className="space-y-6"
                >
                    {/* System Health */}
                    <div className="bg-white rounded-2xl p-6 shadow-lg border border-gray-100">
                        <h3 className="text-lg font-bold text-gray-800 mb-4 flex items-center">
                            <svg className="w-5 h-5 mr-2 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                            </svg>
                            System Health
                        </h3>

                        <div className="space-y-4">
                            <div>
                                <div className="flex justify-between items-center mb-1">
                                    <span className="text-sm font-medium text-gray-700">CPU Usage</span>
                                    <span className="text-sm text-gray-600">{systemHealth.cpu.toFixed(1)}%</span>
                                </div>
                                <div className="w-full bg-gray-200 rounded-full h-2">
                                    <motion.div
                                        className={`h-2 rounded-full ${systemHealth.cpu > 80 ? 'bg-red-500' :
                                            systemHealth.cpu > 60 ? 'bg-yellow-500' : 'bg-green-500'
                                            }`}
                                        initial={{ width: 0 }}
                                        animate={{ width: `${systemHealth.cpu}%` }}
                                        transition={{ duration: 0.5 }}
                                    />
                                </div>
                            </div>

                            <div>
                                <div className="flex justify-between items-center mb-1">
                                    <span className="text-sm font-medium text-gray-700">Memory Usage</span>
                                    <span className="text-sm text-gray-600">{systemHealth.memory.toFixed(1)}%</span>
                                </div>
                                <div className="w-full bg-gray-200 rounded-full h-2">
                                    <motion.div
                                        className={`h-2 rounded-full ${systemHealth.memory > 80 ? 'bg-red-500' :
                                            systemHealth.memory > 60 ? 'bg-yellow-500' : 'bg-green-500'
                                            }`}
                                        initial={{ width: 0 }}
                                        animate={{ width: `${systemHealth.memory}%` }}
                                        transition={{ duration: 0.5 }}
                                    />
                                </div>
                            </div>

                            <div className="grid grid-cols-2 gap-4 pt-2">
                                <div className="flex items-center space-x-2">
                                    <div className={`w-2 h-2 rounded-full ${systemHealth.redis ? 'bg-green-500' : 'bg-red-500'}`} />
                                    <span className="text-xs text-gray-600">Redis</span>
                                </div>
                                <div className="flex items-center space-x-2">
                                    <div className={`w-2 h-2 rounded-full ${systemHealth.database ? 'bg-green-500' : 'bg-red-500'}`} />
                                    <span className="text-xs text-gray-600">Database</span>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Recent Alerts */}
                    <div className="bg-white rounded-2xl p-6 shadow-lg border border-gray-100">
                        <h3 className="text-lg font-bold text-gray-800 mb-4 flex items-center">
                            <svg className="w-5 h-5 mr-2 text-yellow-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-5 5v-5zM10.586 4l-6.364 6.364a2 2 0 000 2.828L10.586 19.5l6.364-6.364a2 2 0 000-2.828L10.586 4z" />
                            </svg>
                            Recent Alerts
                        </h3>

                        <div className="space-y-2 max-h-64 overflow-y-auto">
                            <AnimatePresence>
                                {alerts.length === 0 ? (
                                    <div className="text-center text-gray-500 py-6">
                                        <svg className="w-8 h-8 mx-auto mb-2 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                                        </svg>
                                        <p className="text-sm">All systems operational</p>
                                    </div>
                                ) : (
                                    alerts.map((alert) => (
                                        <motion.div
                                            key={alert.id}
                                            initial={{ opacity: 0, x: -20, scale: 0.8 }}
                                            animate={{ opacity: 1, x: 0, scale: 1 }}
                                            exit={{ opacity: 0, x: 20, scale: 0.8 }}
                                            className={`border-l-4 ${getAlertBorderColor(alert.type)} bg-gray-50 p-3 rounded-r-lg`}
                                        >
                                            <div className="flex items-start space-x-2">
                                                {getAlertIcon(alert.type)}
                                                <div className="flex-1 min-w-0">
                                                    <p className="text-sm font-medium text-gray-800 leading-tight">
                                                        {alert.message}
                                                    </p>
                                                    <p className="text-xs text-gray-500 mt-1">
                                                        {alert.timestamp.toLocaleTimeString()}
                                                    </p>
                                                </div>
                                            </div>
                                        </motion.div>
                                    ))
                                )}
                            </AnimatePresence>
                        </div>
                    </div>
                </motion.div>
            </div>
        </motion.div>
    );
};

export default LiveMetrics;
