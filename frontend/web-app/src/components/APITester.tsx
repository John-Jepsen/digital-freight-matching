import React, { useState } from 'react';
import axios from 'axios';

const API_BASE = process.env.REACT_APP_API_URL || 'http://localhost:3000';

type Method = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

const defaultEndpoints = [
	{ label: 'Health', method: 'GET' as Method, path: '/api/v1/health' },
	{ label: 'Loads (list)', method: 'GET' as Method, path: '/api/v1/loads' },
	{ label: 'Carriers (list)', method: 'GET' as Method, path: '/api/v1/carriers' },
];

const APITester: React.FC = () => {
	const [method, setMethod] = useState<Method>('GET');
	const [path, setPath] = useState<string>('/api/v1/health');
	const [body, setBody] = useState<string>('');
	const [loading, setLoading] = useState(false);
	const [status, setStatus] = useState<number | null>(null);
	const [response, setResponse] = useState<string>('');

	const send = async () => {
		setLoading(true);
		setStatus(null);
		setResponse('');
		try {
			const url = `${API_BASE}${path}`;
			const config = { headers: { 'Content-Type': 'application/json' } };
			let res;
			switch (method) {
				case 'GET':
					res = await axios.get(url, config);
					break;
				case 'DELETE':
					res = await axios.delete(url, config);
					break;
				case 'POST':
					res = await axios.post(url, body ? JSON.parse(body) : {}, config);
					break;
				case 'PUT':
					res = await axios.put(url, body ? JSON.parse(body) : {}, config);
					break;
				case 'PATCH':
					res = await axios.patch(url, body ? JSON.parse(body) : {}, config);
					break;
			}
			setStatus(res!.status);
			setResponse(JSON.stringify(res!.data, null, 2));
		} catch (e: any) {
			if (e.response) {
				setStatus(e.response.status);
				setResponse(JSON.stringify(e.response.data, null, 2));
			} else {
				setResponse(e.message || 'Request failed');
			}
		} finally {
			setLoading(false);
		}
	};

	return (
		<div className="bg-white rounded-2xl p-6 shadow-lg border border-gray-100 space-y-4">
			<div className="flex flex-wrap items-center gap-2">
				<select
					value={method}
					onChange={(e) => setMethod(e.target.value as Method)}
					className="px-3 py-2 border rounded-md"
				>
					{['GET','POST','PUT','PATCH','DELETE'].map(m => (
						<option key={m} value={m}>{m}</option>
					))}
				</select>
				<input
					value={path}
					onChange={(e) => setPath(e.target.value)}
					placeholder="/api/v1/health"
					className="flex-1 min-w-[220px] px-3 py-2 border rounded-md"
				/>
				<button
					onClick={send}
					disabled={loading}
					className="px-4 py-2 bg-blue-600 text-white rounded-md disabled:opacity-60"
				>
					{loading ? 'Sending...' : 'Send'}
				</button>
			</div>

			<div className="flex flex-wrap gap-2">
				{defaultEndpoints.map(ep => (
					<button
						key={ep.label}
						onClick={() => { setMethod(ep.method); setPath(ep.path); setBody(''); }}
						className="px-3 py-1 text-sm bg-gray-100 rounded-md"
					>
						{ep.label}
					</button>
				))}
			</div>

			{['POST','PUT','PATCH'].includes(method) && (
				<textarea
					value={body}
					onChange={(e) => setBody(e.target.value)}
					placeholder='{"key":"value"}'
					className="w-full h-32 px-3 py-2 border rounded-md font-mono text-sm"
				/>
			)}

			<div className="space-y-2">
				<div className="text-sm text-gray-600">Status: {status ?? '-'}</div>
				<pre className="w-full min-h-[160px] p-3 bg-gray-50 border rounded-md overflow-auto text-sm">
					{response}
				</pre>
			</div>
		</div>
	);
};

export default APITester;

