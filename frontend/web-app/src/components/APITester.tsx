import React, { useState } from 'react';
import { motion } from 'framer-motion';
import axios from 'axios';

interface TestResult {
  endpoint: string;
  method: string;
  status: number;
  statusText: string;
  responseTime: number;
  data?: any;
  error?: string;
  timestamp: Date;
}

interface EndpointTest {
  name: string;
  method: 'GET' | 'POST' | 'PUT' | 'DELETE';
  endpoint: string;
  headers?: Record<string, string>;
  body?: any;
  expectedStatus?: number;
}

const APITester: React.FC = () => {
  const [customEndpoint, setCustomEndpoint] = useState('');
  const [customMethod, setCustomMethod] = useState<'GET' | 'POST' | 'PUT' | 'DELETE'>('GET');
  const [customHeaders, setCustomHeaders] = useState('{}');
  const [customBody, setCustomBody] = useState('{}');
  const [testResults, setTestResults] = useState<TestResult[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  const predefinedEndpoints: EndpointTest[] = [
    {
      name: 'Health Check',
      method: 'GET',
      endpoint: '/api/v1/health',
      expectedStatus: 200
    },
    {
      name: 'Rate Limit Status',
      method: 'GET',
      endpoint: '/api/v1/rate_limit/status',
      expectedStatus: 200
    },
    {
      name: 'Authentication Test',
      method: 'POST',
      endpoint: '/api/v1/auth/login',
      headers: { 'Content-Type': 'application/json' },
      body: { email: 'test@example.com', password: 'test123' },
      expectedStatus: 401 // Expected to fail without proper credentials
    },
    {
      name: 'Loads List',
      method: 'GET',
      endpoint: '/api/v1/loads',
      expectedStatus: 200
    }
  ];

  const executeTest = async (test: EndpointTest) => {
    setIsLoading(true);
    const startTime = Date.now();

    try {
      const config = {
        method: test.method,
        url: `http://localhost:3001${test.endpoint}`,
        headers: test.headers || {},
        ...(test.body && { data: test.body })
      };

      const response = await axios(config);
      const responseTime = Date.now() - startTime;

      const result: TestResult = {
        endpoint: test.endpoint,
        method: test.method,
        status: response.status,
        statusText: response.statusText,
        responseTime,
        data: response.data,
        timestamp: new Date()
      };

      setTestResults(prev => [result, ...prev.slice(0, 9)]); // Keep last 10 results
    } catch (error: any) {
      const responseTime = Date.now() - startTime;
      const result: TestResult = {
        endpoint: test.endpoint,
        method: test.method,
        status: error.response?.status || 0,
        statusText: error.response?.statusText || 'Network Error',
        responseTime,
        error: error.message,
        data: error.response?.data,
        timestamp: new Date()
      };

      setTestResults(prev => [result, ...prev.slice(0, 9)]);
    }

    setIsLoading(false);
  };

  const executeCustomTest = async () => {
    if (!customEndpoint) return;

    setIsLoading(true);
    const startTime = Date.now();

    try {
      let headers = {};
      let body = undefined;

      try {
        headers = JSON.parse(customHeaders);
      } catch (e) {
        console.warn('Invalid headers JSON, using empty object');
      }

      if (customMethod !== 'GET') {
        try {
          body = JSON.parse(customBody);
        } catch (e) {
          console.warn('Invalid body JSON, using empty object');
          body = {};
        }
      }

      const config = {
        method: customMethod,
        url: customEndpoint.startsWith('http') ? customEndpoint : `http://localhost:3001${customEndpoint}`,
        headers,
        ...(body && { data: body })
      };

      const response = await axios(config);
      const responseTime = Date.now() - startTime;

      const result: TestResult = {
        endpoint: customEndpoint,
        method: customMethod,
        status: response.status,
        statusText: response.statusText,
        responseTime,
        data: response.data,
        timestamp: new Date()
      };

      setTestResults(prev => [result, ...prev.slice(0, 9)]);
    } catch (error: any) {
      const responseTime = Date.now() - startTime;
      const result: TestResult = {
        endpoint: customEndpoint,
        method: customMethod,
        status: error.response?.status || 0,
        statusText: error.response?.statusText || 'Network Error',
        responseTime,
        error: error.message,
        data: error.response?.data,
        timestamp: new Date()
      };

      setTestResults(prev => [result, ...prev.slice(0, 9)]);
    }

    setIsLoading(false);
  };

  const getStatusColor = (status: number) => {
    if (status >= 200 && status < 300) return 'text-green-600 bg-green-50';
    if (status >= 300 && status < 400) return 'text-blue-600 bg-blue-50';
    if (status >= 400 && status < 500) return 'text-yellow-600 bg-yellow-50';
    if (status >= 500) return 'text-red-600 bg-red-50';
    return 'text-gray-600 bg-gray-50';
  };

  const getMethodColor = (method: string) => {
    switch (method) {
      case 'GET': return 'text-green-700 bg-green-100';
      case 'POST': return 'text-blue-700 bg-blue-100';
      case 'PUT': return 'text-orange-700 bg-orange-100';
      case 'DELETE': return 'text-red-700 bg-red-100';
      default: return 'text-gray-700 bg-gray-100';
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="bg-white rounded-2xl p-6 shadow-lg border border-gray-200"
      >
        <h2 className="text-2xl font-bold text-gray-900 mb-2">API Endpoint Tester</h2>
        <p className="text-gray-600">Test API endpoints and monitor their responses in real-time.</p>
      </motion.div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Predefined Tests */}
        <motion.div
          initial={{ opacity: 0, x: -20 }}
          animate={{ opacity: 1, x: 0 }}
          className="bg-white rounded-2xl p-6 shadow-lg border border-gray-200"
        >
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Predefined Tests</h3>
          <div className="space-y-3">
            {predefinedEndpoints.map((endpoint, index) => (
              <motion.button
                key={index}
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                onClick={() => executeTest(endpoint)}
                disabled={isLoading}
                className="w-full p-4 text-left border-2 border-gray-200 rounded-xl hover:border-blue-300 hover:bg-blue-50 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <div className="flex items-center justify-between">
                  <div>
                    <div className="font-medium text-gray-900">{endpoint.name}</div>
                    <div className="text-sm text-gray-500">{endpoint.endpoint}</div>
                  </div>
                  <span className={`px-2 py-1 rounded-md text-xs font-medium ${getMethodColor(endpoint.method)}`}>
                    {endpoint.method}
                  </span>
                </div>
              </motion.button>
            ))}
          </div>
        </motion.div>

        {/* Custom Test */}
        <motion.div
          initial={{ opacity: 0, x: 20 }}
          animate={{ opacity: 1, x: 0 }}
          className="bg-white rounded-2xl p-6 shadow-lg border border-gray-200"
        >
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Custom Test</h3>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Method</label>
              <select
                value={customMethod}
                onChange={(e) => setCustomMethod(e.target.value as any)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="GET">GET</option>
                <option value="POST">POST</option>
                <option value="PUT">PUT</option>
                <option value="DELETE">DELETE</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Endpoint</label>
              <input
                type="text"
                value={customEndpoint}
                onChange={(e) => setCustomEndpoint(e.target.value)}
                placeholder="/api/v1/..."
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Headers (JSON)</label>
              <textarea
                value={customHeaders}
                onChange={(e) => setCustomHeaders(e.target.value)}
                placeholder='{"Content-Type": "application/json"}'
                rows={2}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono text-sm"
              />
            </div>

            {customMethod !== 'GET' && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Body (JSON)</label>
                <textarea
                  value={customBody}
                  onChange={(e) => setCustomBody(e.target.value)}
                  placeholder='{"key": "value"}'
                  rows={3}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono text-sm"
                />
              </div>
            )}

            <motion.button
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              onClick={executeCustomTest}
              disabled={isLoading || !customEndpoint}
              className="w-full bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors duration-200"
            >
              {isLoading ? 'Testing...' : 'Execute Test'}
            </motion.button>
          </div>
        </motion.div>
      </div>

      {/* Test Results */}
      {testResults.length > 0 && (
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-white rounded-2xl p-6 shadow-lg border border-gray-200"
        >
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Test Results</h3>
          <div className="space-y-4">
            {testResults.map((result, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                className="border border-gray-200 rounded-lg p-4"
              >
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center space-x-3">
                    <span className={`px-2 py-1 rounded-md text-xs font-medium ${getMethodColor(result.method)}`}>
                      {result.method}
                    </span>
                    <span className="font-medium text-gray-900">{result.endpoint}</span>
                  </div>
                  <div className="flex items-center space-x-3">
                    <span className={`px-2 py-1 rounded-md text-xs font-medium ${getStatusColor(result.status)}`}>
                      {result.status} {result.statusText}
                    </span>
                    <span className="text-sm text-gray-500">
                      {result.responseTime}ms
                    </span>
                  </div>
                </div>
                
                {result.error && (
                  <div className="mt-2 p-2 bg-red-50 border border-red-200 rounded text-sm text-red-700">
                    <strong>Error:</strong> {result.error}
                  </div>
                )}
                
                {result.data && (
                  <div className="mt-2">
                    <details className="cursor-pointer">
                      <summary className="text-sm font-medium text-gray-700 hover:text-gray-900">
                        Response Data
                      </summary>
                      <pre className="mt-2 p-2 bg-gray-50 border border-gray-200 rounded text-xs overflow-x-auto">
                        {JSON.stringify(result.data, null, 2)}
                      </pre>
                    </details>
                  </div>
                )}
                
                <div className="mt-2 text-xs text-gray-500">
                  {result.timestamp.toLocaleString()}
                </div>
              </motion.div>
            ))}
          </div>
        </motion.div>
      )}
    </div>
  );
};

export default APITester;
